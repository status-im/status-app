"""Module-level fixtures for messaging tests.

Provides shared session setup for tests that require established contacts.
This avoids re-running the contact establishment flow for each test function.

Note on pytest-xdist: Module-scoped fixtures are per-worker-per-module, not global.
With -n=5, each worker that runs tests from this module will create its own
established_chat session. This is expected behavior for module scope.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass

import pytest
import pytest_asyncio

from config.logging_config import get_logger
from core.device_context import DeviceContext
from core.multi_device_context import MultiDeviceContext
from core.session_pool import PoolConfig, SessionPool
from pages.app import App
from pages.messaging.chat_page import ChatPage
from pages.settings.settings_page import SettingsPage
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


def _extract_chat_suffix(link: str, length: int = 6) -> str:
    """Extract last N characters of chat key for display."""
    chat_key = link.rsplit("#", 1)[-1] if "#" in link else link
    return chat_key[-length:]


def _extract_chat_key(link: str) -> str:
    """Extract full chat key from profile link (part after #)."""
    return link.rsplit("#", 1)[-1] if "#" in link else link


async def _establish_contact(
    primary: DeviceContext,
    secondary: DeviceContext,
    timeout: int = 120,
) -> tuple[str, str]:
    """Establish contact between two devices.
    
    Returns:
        Tuple of (primary_suffix, secondary_suffix).
    """
    # Capture profile links
    primary_link = await asyncio.to_thread(primary.capture_profile_link)
    secondary_link = await asyncio.to_thread(secondary.capture_profile_link)
    
    assert primary_link, "Primary device did not return profile link"
    assert secondary_link, "Secondary device did not return profile link"
    
    primary_suffix = _extract_chat_suffix(primary_link)
    secondary_suffix = _extract_chat_suffix(secondary_link)
    
    logger.info(f"Establishing contact: {primary_suffix} -> {secondary_suffix}")
    
    # Primary sends contact request
    main_app = App(primary.driver)
    settings_page = SettingsPage(primary.driver)
    
    assert main_app.click_settings_button(), "Failed to open settings"
    assert settings_page.is_loaded(timeout=12), "Settings page did not load"
    
    messaging_page = settings_page.open_messaging_settings()
    assert messaging_page is not None, "Failed to open messaging settings"
    
    contacts_page = messaging_page.open_contacts()
    assert contacts_page is not None, "Failed to open contacts"
    
    modal = contacts_page.open_send_contact_request_modal()
    assert modal is not None, "Failed to open send contact request modal"
    
    chat_key = _extract_chat_key(secondary_link)
    request_message = f"Module setup: {primary_suffix} connecting with {secondary_suffix}"
    
    assert modal.enter_chat_key(chat_key), "Failed to enter chat key"
    assert modal.enter_message(request_message), "Failed to enter message"
    assert modal.send(), "Failed to send contact request"
    
    # Navigate primary back to messages
    assert main_app.click_messages_button(), "Failed to navigate to messages"
    primary_chat = ChatPage(primary.driver)
    primary_chat.dismiss_backup_prompt(timeout=4)
    
    # Secondary accepts contact request
    secondary_app = App(secondary.driver)
    secondary_settings = SettingsPage(secondary.driver)
    
    assert secondary_app.click_settings_button(), "Failed to open settings on secondary"
    assert secondary_settings.is_loaded(timeout=12), "Settings did not load on secondary"
    
    secondary_messaging = secondary_settings.open_messaging_settings()
    assert secondary_messaging is not None, "Failed to open messaging settings on secondary"
    
    secondary_contacts = secondary_messaging.open_contacts()
    assert secondary_contacts is not None, "Failed to open contacts on secondary"
    
    assert secondary_contacts.wait_for_pending_requests_focusable(timeout=timeout), (
        f"Pending requests not available after {timeout}s"
    )
    assert secondary_contacts.open_pending_requests_tab(timeout=12), (
        "Failed to open pending requests tab"
    )
    assert secondary_contacts.pending_request_row_exists(primary_suffix, timeout=12), (
        f"Pending request from '{primary_suffix}' not visible"
    )
    assert secondary_contacts.accept_contact_request(primary_suffix), (
        "Failed to accept contact request"
    )
    
    # Navigate secondary to messages
    assert secondary_app.click_messages_button(), "Failed to navigate secondary to messages"
    secondary_chat = ChatPage(secondary.driver)
    secondary_chat.dismiss_backup_prompt(timeout=4)
    
    # Wait for chat to appear on secondary
    assert secondary_chat.wait_for_new_chat_to_arrive(
        primary_suffix,
        display_name=primary.user.display_name if primary.user else None,
        timeout=timeout,
    ), "Chat did not arrive on secondary"
    
    # Open the chat on secondary (wait_for_new_chat_to_arrive only confirms it's in the list)
    assert secondary_chat.open_chat_by_suffix(
        primary_suffix,
        display_name=primary.user.display_name if primary.user else None,
    ), "Failed to open chat on secondary"
    
    # Secondary sends a message to primary - this triggers the chat to appear on primary's side
    logger.info("Secondary sending message to primary")
    assert secondary_chat.wait_for_message_input(timeout=15), (
        "Message input not ready on secondary"
    )
    assert secondary_chat.send_message(
        f"Setup message from {secondary_suffix}",
        timeout=15,
    ), "Secondary failed to send setup message"
    
    # Now wait for the chat to appear on primary's side
    primary_chat = ChatPage(primary.driver)
    primary_chat.dismiss_backup_prompt(timeout=4)
    
    logger.info("Primary waiting for DM from secondary")
    assert primary_chat.wait_for_new_chat_to_arrive(
        secondary_suffix,
        display_name=secondary.user.display_name if secondary.user else None,
        timeout=timeout,
    ), "Chat did not arrive on primary"
    
    # Open the chat on primary
    assert primary_chat.open_chat_by_suffix(
        secondary_suffix,
        display_name=secondary.user.display_name if secondary.user else None,
    ), "Failed to open chat on primary"
    
    assert primary_chat.wait_for_message_input(timeout=15), (
        "Message input not ready on primary"
    )
    
    logger.info(f"Contact established: {primary_suffix} <-> {secondary_suffix}")
    return primary_suffix, secondary_suffix


def _report_browserstack_status(pool: SessionPool, status: str, reason: str | None = None) -> None:
    """Report session status to BrowserStack for all sessions in the pool.
    
    This is needed for module-scoped fixtures because they bypass the standard
    conftest.py pytest_runtest_makereport hook that normally reports status.
    """
    if not pool or not pool._sessions:
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
            logger.debug(f"Reported status '{status}' for {device_name} via executor")
            continue
        except Exception as e:
            logger.debug(f"Executor status report failed for {device_name}: {e}")
        
        # Fall back to REST API
        if session_id:
            try:
                session_manager.provider.report_session_status_via_api(
                    session_id, status, reason
                )
                logger.debug(f"Reported status '{status}' for {device_name} via API")
            except Exception as e:
                logger.warning(f"Failed to report status for {device_name}: {e}")


@pytest_asyncio.fixture(scope="module")
async def established_chat(request, test_environment) -> EstablishedChatContext:
    """Module-scoped fixture providing two devices with an established chat.
    
    This runs the contact establishment flow once per module, then all tests
    in the module share the same session with contacts already connected.
    
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
    multi_ctx = None
    setup_failed = False
    
    try:
        # Create session pool for 2 devices
        pool_config = PoolConfig.from_environment(
            test_environment,
            parallel=True,
        )
        pool = SessionPool(config=pool_config)
        _module_pools.append(pool)  # Track for cleanup
        
        # Create sessions
        drivers = await pool.create_sessions(
            count=2,
            test_nodeid=f"{request.node.nodeid}::module_setup",
        )
        
        # Create device contexts
        contexts = {
            name: DeviceContext(driver=driver, device_id=name)
            for name, driver in drivers.items()
        }
        multi_ctx = MultiDeviceContext(contexts)
        
        # Onboard users
        display_names = [generate_account_name(12) for _ in range(2)]
        users = await multi_ctx.onboard_users_parallel(
            display_names=display_names,
            require_all=True,
        )
        
        # Get device references
        device_names = list(contexts.keys())
        primary = contexts[device_names[0]]
        secondary = contexts[device_names[1]]
        
        # Establish contact
        primary_suffix, secondary_suffix = await _establish_contact(
            primary, secondary, timeout=120
        )
        
        yield EstablishedChatContext(
            primary=primary,
            secondary=secondary,
            primary_suffix=primary_suffix,
            secondary_suffix=secondary_suffix,
            multi_ctx=multi_ctx,
        )
        
    except Exception as e:
        setup_failed = True
        logger.error(f"Fixture setup failed: {e}")
        raise
        
    finally:
        # Report status to BrowserStack before cleanup
        if pool:
            # Determine final status based on test outcomes
            if setup_failed:
                _report_browserstack_status(pool, "failed", "Module fixture setup failed")
            else:
                # Check for test outcomes tracked by pytest hook
                module_name = request.node.module.__name__ if hasattr(request.node, "module") else ""
                failed_tests = _module_test_failures.get(module_name, [])
                skipped_tests = _module_test_skipped.get(module_name, [])
                passed_tests = _module_test_passed.get(module_name, [])
                
                # Determine appropriate status:
                # - Any failures → "failed"
                # - All skipped (no passed, no failed) → "skipped"
                # - Otherwise → "passed"
                if failed_tests:
                    failure_count = len(failed_tests)
                    reason = f"{failure_count} test(s) failed"
                    _report_browserstack_status(pool, "failed", reason)
                    logger.info(f"Reported 'failed' to BrowserStack: {reason}")
                elif skipped_tests and not passed_tests:
                    skip_count = len(skipped_tests)
                    reason = f"All {skip_count} test(s) skipped"
                    _report_browserstack_status(pool, "skipped", reason)
                    logger.info(f"Reported 'skipped' to BrowserStack: {reason}")
                else:
                    passed_count = len(passed_tests)
                    skipped_count = len(skipped_tests)
                    if skipped_count > 0:
                        reason = f"{passed_count} passed, {skipped_count} skipped"
                    else:
                        reason = f"All {passed_count} test(s) passed"
                    _report_browserstack_status(pool, "passed", reason)
                    logger.info(f"Reported 'passed' to BrowserStack: {reason}")
                
                # Clean up tracking for this module
                for tracking_dict in (_module_test_failures, _module_test_skipped, _module_test_passed):
                    if module_name in tracking_dict:
                        del tracking_dict[module_name]
            
            logger.info("Cleaning up module-scoped sessions")
            try:
                await pool.cleanup()
            except Exception as e:
                logger.warning(f"Cleanup error (non-fatal): {e}")
            
            # Remove from tracking
            if pool in _module_pools:
                _module_pools.remove(pool)
