"""Module-level fixtures for messaging tests.

Provides shared session setup for tests that require established contacts.
This avoids re-running the contact establishment flow for each test function.

Note on pytest-xdist: Module-scoped fixtures are per-worker-per-module, not global.
With -n=5, each worker that runs tests from this module will create its own
established_chat session. This is expected behavior for module scope.
"""

from __future__ import annotations

from dataclasses import dataclass

import pytest
import pytest_asyncio

from config.logging_config import get_logger
from core.device_context import DeviceContext
from core.multi_device_context import MultiDeviceContext
from core.session_pool import PoolConfig, SessionPool
from utils.contact_helpers import establish_contact
from utils.generators import generate_account_name

logger = get_logger("messaging_conftest")

# Track test outcomes at module level for BrowserStack status reporting
_module_test_failures: dict[str, list[str]] = {}
_module_test_skipped: dict[str, list[str]] = {}
_module_test_passed: dict[str, list[str]] = {}


# Module-level storage for cleanup
_module_pools = []


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Track test outcomes for BrowserStack status reporting.
    
    This hook runs after each test phase (setup, call, teardown) and records
    outcomes to module-level tracking dicts.
    
    Note: Page dump capture on failure is handled by the main conftest.py hook.
    """
    outcome = yield
    rep = outcome.get_result()
    
    # Only track test outcomes from the call phase (actual test execution)
    if rep.when != "call":
        return
    
    module_name = item.module.__name__ if hasattr(item, "module") else "unknown"
    
    if rep.failed:
        if module_name not in _module_test_failures:
            _module_test_failures[module_name] = []
        _module_test_failures[module_name].append(item.nodeid)
    elif rep.skipped:
        if module_name not in _module_test_skipped:
            _module_test_skipped[module_name] = []
        _module_test_skipped[module_name].append(item.nodeid)
    elif rep.passed:
        if module_name not in _module_test_passed:
            _module_test_passed[module_name] = []
        _module_test_passed[module_name].append(item.nodeid)


@dataclass
class EstablishedChatContext:
    """Context for tests that require an established chat between two users.
    
    Attributes:
        primary: The device that sent the contact request.
        secondary: The device that accepted the contact request.
        primary_suffix: Last 6 chars of primary's chat key (for display/matching).
        secondary_suffix: Last 6 chars of secondary's chat key.
        multi_ctx: The underlying MultiDeviceContext.
    """
    primary: DeviceContext
    secondary: DeviceContext
    primary_suffix: str
    secondary_suffix: str
    multi_ctx: MultiDeviceContext
    
    @property
    def primary_driver(self):
        return self.primary.driver
    
    @property 
    def secondary_driver(self):
        return self.secondary.driver


async def _establish_contact(
    primary: DeviceContext,
    secondary: DeviceContext,
    timeout: int = 180,
) -> tuple[str, str]:
    """Establish contact between two devices.

    Delegates to the shared ``establish_contact()`` utility.

    Returns:
        Tuple of (primary_suffix, secondary_suffix).
    """
    sender_suffix, receiver_suffix, _, _ = await establish_contact(
        primary, secondary, timeout=timeout,
    )
    return sender_suffix, receiver_suffix


def _report_browserstack_status(pool: SessionPool, status: str, reason: str | None = None) -> None:
    """Report session status to BrowserStack for all sessions in the pool.
    
    This is needed for module-scoped fixtures because they bypass the standard
    conftest.py pytest_runtest_makereport hook that normally reports status.
    """
    if not pool or pool.session_count == 0:
        return
    
    for device_name in pool.device_names:
        session_manager = pool.get_session_manager(device_name)
        driver = pool.get_driver(device_name)
        
        if not session_manager or not driver:
            continue
        
        session_id = getattr(driver, "session_id", None)
        
        # Try to report via driver first (executor command)
        try:
            session_manager.provider.report_session_status(driver, status, reason)
            logger.debug("Reported status '%s' for %s via executor", status, device_name)
            continue
        except Exception as e:
            logger.debug("Executor status report failed for %s: %s", device_name, e)
        
        # Fall back to REST API
        if session_id:
            try:
                session_manager.provider.report_session_status_via_api(
                    session_id, status, reason
                )
                logger.debug("Reported status '%s' for %s via API", status, device_name)
            except Exception as e:
                logger.warning("Failed to report status for %s: %s", device_name, e)



async def _setup_established_chat(
    pool: SessionPool,
    test_nodeid: str,
) -> EstablishedChatContext:
    """Create sessions, onboard users, and establish a contact pair.

    The caller owns *pool* and is responsible for cleanup on failure.
    """
    drivers = await pool.create_sessions(
        count=2,
        test_nodeid=f"{test_nodeid}::module_setup",
    )

    contexts = {
        name: DeviceContext(driver=driver, device_id=name)
        for name, driver in drivers.items()
    }
    multi_ctx = MultiDeviceContext(contexts)

    display_names = [generate_account_name(12) for _ in range(2)]
    await multi_ctx.onboard_users_parallel(
        display_names=display_names,
        require_all=True,
    )

    device_names = list(contexts.keys())
    primary = contexts[device_names[0]]
    secondary = contexts[device_names[1]]

    primary_suffix, secondary_suffix = await _establish_contact(
        primary, secondary, timeout=240
    )

    return EstablishedChatContext(
        primary=primary,
        secondary=secondary,
        primary_suffix=primary_suffix,
        secondary_suffix=secondary_suffix,
        multi_ctx=multi_ctx,
    )


@pytest_asyncio.fixture(scope="module")
async def established_chat(request, test_environment) -> EstablishedChatContext:
    """Module-scoped fixture providing two devices with an established chat.
    
    This runs the contact establishment flow once per module, then all tests
    in the module share the same session with contacts already connected.

    If the setup fails (e.g. BrowserStack connection drop, biometrics prompt
    timing, device allocation, accessibility tree blocking), it cleans up and
    retries once with fresh sessions.
    
    Usage:
        class TestMessageContextMenu:
            @pytest.fixture(autouse=True)
            def setup(self, established_chat):
                self.ctx = established_chat
                self.primary = established_chat.primary
                self.driver = self.primary.driver
            
            async def test_context_menu(self):
                chat_page = ChatPage(self.driver)
                ...
    """
    global _module_pools

    logger.info("Setting up module-scoped established_chat fixture")

    pool = None
    ctx = None
    setup_failed = False
    max_attempts = 1
    last_error: BaseException | None = None
    
    for attempt in range(1, max_attempts + 1):
        try:
            pool_config = PoolConfig.from_environment(
                test_environment, parallel=True,
            )
            pool = SessionPool(config=pool_config)

            ctx = await _setup_established_chat(
                pool, request.node.nodeid,
            )
            _module_pools.append(pool)
            break  # success

        except Exception as e:
            last_error = e
            logger.error(
                "Fixture setup failed (attempt %d/%d): %s",
                attempt, max_attempts, e,
            )
            # Clean up the failed pool before retrying
            if pool:
                try:
                    _report_browserstack_status(
                        pool, "failed", f"Setup failed (attempt {attempt}): {e}"
                    )
                except Exception:
                    pass
                try:
                    await pool.cleanup()
                except Exception as cleanup_err:
                    logger.warning("Cleanup after failed attempt: %s", cleanup_err)
                pool = None

            if attempt < max_attempts:
                logger.info(
                    "Retrying fixture setup with fresh sessions "
                    "(attempt %d failed: %s)", attempt, e,
                )
                continue

            setup_failed = True
            raise
    else:
        setup_failed = True
        raise last_error  # type: ignore[misc]

    try:
        yield ctx
        
    except Exception:
        setup_failed = True
        raise
        
    finally:
        # Report status to BrowserStack before cleanup
        if pool:
            if setup_failed:
                _report_browserstack_status(pool, "failed", "Module fixture setup failed")
            else:
                module_name = request.node.module.__name__ if hasattr(request.node, "module") else ""
                failed_tests = _module_test_failures.get(module_name, [])
                skipped_tests = _module_test_skipped.get(module_name, [])
                passed_tests = _module_test_passed.get(module_name, [])
                
                if failed_tests:
                    failure_count = len(failed_tests)
                    reason = f"{failure_count} test(s) failed"
                    _report_browserstack_status(pool, "failed", reason)
                    logger.info("Reported 'failed' to BrowserStack: %s", reason)
                elif skipped_tests and not passed_tests:
                    skip_count = len(skipped_tests)
                    reason = f"All {skip_count} test(s) skipped"
                    _report_browserstack_status(pool, "skipped", reason)
                    logger.info("Reported 'skipped' to BrowserStack: %s", reason)
                else:
                    passed_count = len(passed_tests)
                    skipped_count = len(skipped_tests)
                    if skipped_count > 0:
                        reason = f"{passed_count} passed, {skipped_count} skipped"
                    else:
                        reason = f"All {passed_count} test(s) passed"
                    _report_browserstack_status(pool, "passed", reason)
                    logger.info("Reported 'passed' to BrowserStack: %s", reason)
                
                for tracking_dict in (_module_test_failures, _module_test_skipped, _module_test_passed):
                    if module_name in tracking_dict:
                        del tracking_dict[module_name]
            
            logger.info("Cleaning up module-scoped sessions")
            try:
                await pool.cleanup()
            except Exception as e:
                logger.warning("Cleanup error (non-fatal): %s", e)
            
            if pool in _module_pools:
                _module_pools.remove(pool)
