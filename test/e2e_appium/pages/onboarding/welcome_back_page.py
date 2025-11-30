import time

from ..base_page import BasePage
from locators.onboarding.welcome_back_screen_locators import WelcomeBackScreenLocators
from services.app_initialization_manager import AppInitializationManager
from utils.element_state_checker import ElementStateChecker


class WelcomeBackPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = WelcomeBackScreenLocators()

    def is_welcome_back_screen_displayed(self, timeout: int = 5) -> bool:
        checks = [
            self.locators.LOGIN_SCREEN,
            self.locators.PASSWORD_INPUT,
            self.locators.LOGIN_BUTTON,
        ]

        for locator in checks:
            if not locator:
                continue
            element = self.find_element_safe(locator, timeout=timeout)
            if element and ElementStateChecker.is_displayed(element):
                return True

        return False

    def perform_login(self, password: str, timeout: int = 60) -> bool:
        self._activate_screen_if_needed()

        max_attempts = 2
        for attempt in range(1, max_attempts + 1):
            if not self._focus_password_field():
                self.logger.error("Failed to focus password field on attempt %s", attempt)
                return False

            if not self.qt_safe_input(
                self.locators.PASSWORD_INPUT, password, verify=False
            ):
                self.logger.error("Password input failed on attempt %s", attempt)
                return False

            try:
                self.hide_keyboard()
            except Exception:
                pass

            if not self.wait_for_element_enabled(self.locators.LOGIN_BUTTON, timeout=10):
                self.logger.error("Login button never enabled on attempt %s", attempt)
                return False

            if not self.safe_click(self.locators.LOGIN_BUTTON, timeout=10):
                self.logger.error("Login button click failed on attempt %s", attempt)
                return False

            if self._wait_for_login_transition(timeout=10):
                return True

            if attempt < max_attempts:
                self.logger.warning(
                    "Login attempt %s did not dismiss welcome back screen; retrying",
                    attempt,
                )
                time.sleep(1.0)

        self.logger.error("Welcome back screen persisted after login retries")
        return False

    def _activate_screen_if_needed(self) -> None:
        try:
            manager = AppInitializationManager(self.driver)
            manager.perform_initial_activation(timeout=3)
        except Exception:
            try:
                size = self.driver.get_window_size()
                self.gestures.tap(size["width"] // 2, size["height"] // 2)
            except Exception:
                pass

    def _focus_password_field(self, retries: int = 5, wait_between: float = 2.0) -> bool:
        for attempt in range(retries):
            overlay = self.find_element_safe(
                self.locators.PASSWORD_INPUT_OVERLAY, timeout=2
            )
            if overlay and ElementStateChecker.is_displayed(overlay):
                try:
                    rect = overlay.rect
                    tap_x = int(rect.get("x", 0) + rect.get("width", 0) * 0.25)
                    tap_y = int(rect.get("y", 0) + rect.get("height", 0) * 0.25)
                    if not self.gestures.tap(tap_x, tap_y):
                        self.gestures.double_tap(tap_x, tap_y)
                except Exception:
                    self.logger.debug(
                        "Overlay tap failed on attempt %s", attempt + 1
                    )
                time.sleep(wait_between)

            field = self.find_element_safe(self.locators.PASSWORD_INPUT, timeout=3)
            if not field:
                time.sleep(wait_between)
                continue

            if not ElementStateChecker.is_displayed(field):
                time.sleep(wait_between)
                continue

            if ElementStateChecker.is_focused(field):
                return True

            try:
                rect = field.rect
                tap_x = int(rect.get("x", 0) + rect.get("width", 0) * 0.25)
                tap_y = int(rect.get("y", 0) + rect.get("height", 0) * 0.25)
                if not self.gestures.tap(tap_x, tap_y):
                    self.gestures.double_tap(tap_x, tap_y)
            except Exception:
                self.logger.debug("Password field tap failed on attempt %s", attempt + 1)

            time.sleep(wait_between)

            refreshed = self.find_element_safe(self.locators.PASSWORD_INPUT, timeout=1)
            if refreshed and ElementStateChecker.is_focused(refreshed):
                return True

            time.sleep(wait_between)

        self.logger.warning("Unable to focus password input on welcome back screen")
        return False

    def _wait_for_login_transition(self, timeout: int = 10) -> bool:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if not self.is_welcome_back_screen_displayed(timeout=1):
                return True
            time.sleep(0.5)
        return False
