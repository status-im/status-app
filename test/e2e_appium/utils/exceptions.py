"""
Custom exceptions for the e2e_appium framework.

Centralized exception definitions to avoid circular imports and provide
clear error handling throughout the test automation framework.
"""

from typing import Dict, Any, Optional


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
