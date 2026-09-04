"""
Custom exceptions for the e2e_appium framework.

Centralized exception definitions to avoid circular imports and provide
clear error handling throughout the test automation framework.
"""

from typing import Dict, Any, Optional


from selenium.common.exceptions import InvalidSessionIdException
from urllib3.exceptions import MaxRetryError, NewConnectionError

# Session-fatal driver errors: the session or its server is gone and no
# recovery, swallow, or retry at any layer is meaningful — these must always
# propagate. A crashed UIA2 instrumentation serializes as a bare
# WebDriverException whose message carries one of the marker texts (taken
# from appium-uiautomator2-server core and appium jwproxy), so fatality is
# decided by is_session_fatal(), never by an isinstance check alone.
SESSION_FATAL = (InvalidSessionIdException, MaxRetryError, NewConnectionError)

_SESSION_FATAL_MARKERS = (
    "instrumentation process is not running",
    "instrumentation process has been unexpectedly terminated",
    "cannot be proxied to uiautomator2 server",
    "could not proxy command to the remote server",
    "socket hang up",
)


def is_session_fatal(exc: BaseException) -> bool:
    if isinstance(exc, SESSION_FATAL):
        return True
    msg = str(exc).lower()
    return any(marker in msg for marker in _SESSION_FATAL_MARKERS)

class ProfileCreationFlowError(Exception):
    """
    Custom exception for profile creation and onboarding flow failures.

    Provides structured error information including step context and execution results.
    """

    def __init__(
        self,
        message: str,
        step: Optional[str] = None,
        results: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(message)
        self.step = step
        self.results = results or {}


class SessionManagementError(Exception):
    """Exception for Appium session management failures."""

    pass


class BrowserStackQueueError(SessionManagementError):
    """Exception for BrowserStack queue exhaustion errors."""

    pass


class ElementInteractionError(Exception):
    """Exception for element interaction failures (clicks, input, etc.)."""

    def __init__(self, message: str, locator: str = None, action: str = None):
        super().__init__(message)
        self.locator = locator
        self.action = action


class PageLoadError(Exception):
    """Exception for page/screen loading failures."""

    def __init__(self, message: str, page_name: str = None, timeout: int = None):
        super().__init__(message)
        self.page_name = page_name
        self.timeout = timeout


class TestContextError(Exception):
    """Exception for TestContext state management issues."""

    pass
