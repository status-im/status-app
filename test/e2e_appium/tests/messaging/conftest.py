"""Session-level fixtures for messaging tests.

Provides shared session setup for tests that require established contacts.
The contact establishment flow runs once per pytest session, then all messaging
tests across all messaging-test modules share the same pair of onboarded
devices and established chat. This saves ~7-8 min of redundant setup per
additional messaging module compared to module scope.

State pollution between tests is managed by each test cleaning up its own UI
state (e.g. ``MessageContextMenuPage.dismiss`` uses Android back-button to avoid
mis-tapping the chat header). If session-wide pollution surfaces, an autouse
``_reset_chat_view`` fixture is the next safety net.

Note on pytest-xdist: Session-scoped fixtures are per-worker. With -n=5, each
worker that runs messaging tests creates its own established_chat session. For
2-device tests on Pi local (only 2 phones available), xdist effectively
serialises them so a single fixture is reused across the whole worker.
"""

from __future__ import annotations

import threading

from dataclasses import dataclass, field

import pytest
import pytest_asyncio

from config.logging_config import get_logger
from core.device_context import DeviceContext
from core.multi_device_context import MultiDeviceContext
from core.session_pool import PoolConfig, SessionPool
from core.stash_keys import (
    ESTABLISHED_CHAT_BROKEN_KEY,
    ESTABLISHED_CHAT_FAILURE_COUNT_KEY,
)
from utils.chat_state import ensure_chat_visible
from utils.contact_helpers import establish_contact
from utils.timeouts import CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS
from utils.generators import generate_account_name

logger = get_logger("messaging_conftest")


class _SessionKeepAlive:
    """Polls ``driver.orientation`` every ``interval_s`` from a daemon
    thread to keep idle BS sessions alive across our 300s cross-device
    waits (``appium:newCommandTimeout`` is coerced by BS).

    Selenium WebDriver isn't formally thread-safe; we only fire while the
    main thread is blocked on the OTHER device, so concurrent commands on
    the same driver are structurally avoided.

    TODO(upstream): drop once BS honours ``newCommandTimeout``.
    """

    def __init__(self, driver, label: str = "?", interval_s: int = 120) -> None:
        self.driver = driver
        self.label = label
        self.interval_s = interval_s
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread is not None:
            return
        self._thread = threading.Thread(
            target=self._run, name=f"keepalive-{self.label}", daemon=True
        )
        self._thread.start()
        logger.info("Started keep-alive heartbeat for %s (every %ds)", self.label, self.interval_s)

    def stop(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=5)
        logger.debug("Stopped keep-alive heartbeat for %s", self.label)

    def _run(self) -> None:
        while not self._stop.wait(self.interval_s):
            try:
                _ = self.driver.orientation
            except Exception as exc:
                logger.warning(
                    "Keep-alive ping failed for %s: %s — stopping heartbeat",
                    self.label, exc,
                )
                return


# Track test outcomes at module level for BrowserStack status reporting
_module_test_failures: dict[str, list[str]] = {}
_module_test_skipped: dict[str, list[str]] = {}
_module_test_passed: dict[str, list[str]] = {}


# Module-level storage for cleanup
_module_pools = []

# Sentinel fires once pytest-rerunfailures' single ``reruns=1`` retry has been
# exhausted. Setting it on the first failure would cause the rerun to re-raise
# the sentinel before getting a fresh setup attempt.
_FIXTURE_FAILURES_BEFORE_SENTINEL = 2



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
        _keepalives: Fixture-internal heartbeat threads. Tests should not
            touch these — they're carried back from ``_setup_established_chat``
            so the outer fixture's cleanup block can ``stop()`` them.
    """
    primary: DeviceContext
    secondary: DeviceContext
    primary_suffix: str
    secondary_suffix: str
    multi_ctx: MultiDeviceContext
    _keepalives: list["_SessionKeepAlive"] = field(default_factory=list)

    @property
    def primary_driver(self):
        return self.primary.driver

    @property
    def secondary_driver(self):
        return self.secondary.driver


async def _establish_contact(
    primary: DeviceContext,
    secondary: DeviceContext,
    timeout: int = CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS,
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

    Needed because the session-scoped ``established_chat`` fixture bypasses
    the standard ``conftest.py:pytest_runtest_makereport`` hook that normally
    reports per-test status.
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

    # Start keep-alive heartbeats immediately after session creation so the
    # receiver doesn't BS-idle-timeout (default 90s, max 300s configurable)
    # during the sequential phases of fixture setup — sender's
    # capture_profile_link takes ~2 min while receiver is fully idle, and the
    # delivery-gate poll waits up to CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS for
    # waku to propagate, again with one side idle.
    keepalives: list[_SessionKeepAlive] = []
    for name, driver in drivers.items():
        ka = _SessionKeepAlive(driver, label=name)
        ka.start()
        keepalives.append(ka)

    try:
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
            primary, secondary,
        )

        return EstablishedChatContext(
            primary=primary,
            secondary=secondary,
            primary_suffix=primary_suffix,
            secondary_suffix=secondary_suffix,
            multi_ctx=multi_ctx,
            _keepalives=keepalives,
        )
    except BaseException:
        # Stop heartbeats before the caller's pool.cleanup() racing with them.
        # Threads self-terminate on the next failed ping when the driver dies,
        # but explicit stop avoids the window where they ping a dying session.
        for ka in keepalives:
            try:
                ka.stop()
            except Exception:
                pass
        raise


@pytest_asyncio.fixture(scope="session")
async def established_chat(request, test_environment) -> EstablishedChatContext:
    """Session-scoped fixture providing two devices with an established chat.

    This runs the contact establishment flow once per pytest session, then all
    messaging tests across modules share the same session with contacts already
    connected. Saves ~7-8 min per additional messaging module vs module scope.

    State isolation between tests is the responsibility of each test (clean up
    overlays, dismiss context menus). If session-wide pollution surfaces, the
    next defence is an autouse ``_reset_chat_view`` fixture.

    Setup runs once; retry on failure is delegated to ``@pytest.mark.flaky``
    on the test classes. After both attempts fail, a session-wide sentinel
    causes subsequent messaging tests to fast-fail rather than each re-paying
    the full setup cost.

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
    cached_exc = request.session.stash.get(ESTABLISHED_CHAT_BROKEN_KEY, None)
    if cached_exc is not None:
        logger.info(
            "established_chat broken earlier in this session "
            "(%s); re-raising cached exception without re-attempting setup",
            type(cached_exc).__name__,
        )
        raise cached_exc

    logger.info("Setting up session-scoped established_chat fixture")

    pool = None
    ctx = None
    setup_failed = False

    # Single attempt; pytest-rerunfailures owns retry via the test classes'
    # ``@pytest.mark.flaky(reruns=1)``. A second retry layer here compounds
    # with ``@pytest.mark.timeout(1200)`` and starves the per-test budget.
    try:
        # For local environments, assign each session to a different device
        # from the YAML matrix (set via local.local.yaml overlay).
        device_overrides = None
        if test_environment == "local":
            try:
                from core.config_manager import ConfigurationManager
                cfg_mgr = ConfigurationManager()
                env_cfg = cfg_mgr.load_environment("local")
                matrix_devices = list(env_cfg.devices.values())
                if len(matrix_devices) >= 2:
                    defaults = env_cfg.device_defaults.get("capabilities", {})
                    device_overrides = []
                    for i in range(2):
                        device = matrix_devices[i]
                        override = {"capabilities": device.merged_capabilities(defaults)}
                        if device.provider_overrides:
                            override.update(device.provider_overrides)
                        device_overrides.append(override)
                    for idx, ov in enumerate(device_overrides):
                        caps = ov.get("capabilities", {})
                        logger.info(
                            "Local device override %d: udid=%s server_url=%s",
                            idx,
                            caps.get("appium:udid", "?"),
                            ov.get("server_url", "default"),
                        )
            except Exception as exc:
                logger.warning("Failed to build local device overrides: %s", exc)

        pool_config = PoolConfig.from_environment(
            test_environment, parallel=True,
            device_overrides=device_overrides,
        )
        pool = SessionPool(config=pool_config)

        ctx = await _setup_established_chat(pool, request.node.nodeid)
        _module_pools.append(pool)

    except Exception as e:
        stash = request.session.stash
        failure_count = stash.get(ESTABLISHED_CHAT_FAILURE_COUNT_KEY, 0) + 1
        stash[ESTABLISHED_CHAT_FAILURE_COUNT_KEY] = failure_count
        logger.error(
            "Fixture setup failed (attempt %d/%d before sentinel fires): %s",
            failure_count, _FIXTURE_FAILURES_BEFORE_SENTINEL, e,
        )
        if pool:
            try:
                _report_browserstack_status(pool, "failed", f"Setup failed: {e}")
            except Exception:
                pass
            try:
                await pool.cleanup()
            except Exception as cleanup_err:
                logger.warning("Cleanup after failed setup: %s", cleanup_err)
            pool = None
        setup_failed = True
        if failure_count >= _FIXTURE_FAILURES_BEFORE_SENTINEL:
            stash[ESTABLISHED_CHAT_BROKEN_KEY] = e
        raise

    # Keep-alives were started inside _setup_established_chat so they cover
    # the entire fixture-setup window (not just post-setup). Inherit the list
    # for cleanup; if setup failed we have an empty list which is fine.
    keepalives: list[_SessionKeepAlive] = ctx._keepalives if ctx is not None else []

    try:
        yield ctx

    except Exception:
        setup_failed = True
        raise

    finally:
        # Stop heartbeats first so they don't race with cleanup
        for ka in keepalives:
            try:
                ka.stop()
            except Exception:
                pass
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

            logger.info("Cleaning up session-scoped fixture sessions")
            try:
                await pool.cleanup()
            except Exception as e:
                logger.warning("Cleanup error (non-fatal): %s", e)

            if pool in _module_pools:
                _module_pools.remove(pool)


@pytest.fixture
def chat_ready(established_chat) -> EstablishedChatContext:
    """Function-scoped state guarantee on top of session-scoped infrastructure.

    Ensures both devices have the chat with their peer open and message input
    visible before the test runs. Recovers from any state the previous test
    left (chat closed on either side, scrolled off, etc.) so tests don't
    need to know what came before them — and so xdist dispatch order doesn't
    matter.

    Recovery is via ``utils.chat_state.ensure_chat_visible``; see there for
    the strategy ladder.

    Sync rather than async-with-``asyncio.to_thread``: pytest-asyncio's
    function-scoped event loops shut down the default executor on teardown,
    which can hang for minutes if a thread-pool worker is mid-Selenium-call.
    Calling ``ensure_chat_visible`` synchronously sequentially keeps execution
    on the main thread; recovery on both devices runs ~30s slower in the
    worst case but doesn't leave executor threads to track.
    """
    ctx = established_chat
    primary_display = ctx.primary.user.display_name if ctx.primary.user else None
    secondary_display = ctx.secondary.user.display_name if ctx.secondary.user else None

    ensure_chat_visible(ctx.primary, ctx.secondary_suffix, secondary_display)
    ensure_chat_visible(ctx.secondary, ctx.primary_suffix, primary_display)
    return ctx
