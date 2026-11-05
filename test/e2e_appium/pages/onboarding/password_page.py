"""
Password Page for Status Desktop E2E Testing

Page object for password creation and confirmation during profile setup.
"""

import time

from ..base_page import BasePage
from locators.onboarding.password_screen_locators import PasswordScreenLocators
from support.element_state_checker import ElementStateChecker


class PasswordPage(BasePage):
    """Page object for the Password Creation screen"""

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = PasswordScreenLocators()
        self.IDENTITY_LOCATOR = self.locators.PASSWORD_SCREEN

    def enter_password(self, password: str) -> bool:
        self.logger.info("Entering password")

        # Use the new Qt-safe input method from base page
        return self.qt_safe_input(self.locators.PASSWORD_INPUT, password)

    def confirm_password(self, password: str) -> bool:
        self.logger.info("Confirming password")

        # Use the new Qt-safe input method from base page
        return self.qt_safe_input(self.locators.PASSWORD_CONFIRM_INPUT, password)

    def click_confirm_password_button(self) -> bool:
        self.logger.info("Clicking confirm password button")
        self.hide_keyboard()

        button = self.find_element_safe(self.locators.CONFIRM_PASSWORD_BUTTON, timeout=10)
        if not button:
            # On iOS the app may auto-advance past the password screen if
            # both fields were filled and validated before we reach this
            # point.  Check whether we've already moved forward.
            if not self.is_element_visible(self.IDENTITY_LOCATOR, timeout=2):
                self.logger.info(
                    "Password screen no longer visible — app appears to have advanced"
                )
                return True
            self.logger.error("Confirm password button not found")
            self.dump_page_source("password_confirm_button_not_found")
            return False

        return self.gestures.element_center_tap(button)

    def set_stay_logged_in(self, enabled: bool) -> bool:
        self.logger.info("Setting 'Stay logged in' to %s", enabled)
        switch = self.find_element_safe(self.locators.STAY_LOGGED_IN_SWITCH, timeout=5)
        if not switch:
            self.logger.error("'Stay logged in' switch not found")
            self.dump_page_source("stay_logged_in_switch_not_found")
            return False

        if ElementStateChecker.is_checked(switch) == enabled:
            return True

        if not self.gestures.element_center_tap(switch):
            self.logger.error("Failed to tap 'Stay logged in' switch")
            return False

        if not self.wait_for_condition(
            lambda: self._is_element_checked(self.locators.STAY_LOGGED_IN_SWITCH)
            == enabled,
            timeout=5,
            poll_interval=0.2,
        ):
            self.logger.error("'Stay logged in' switch did not change to %s", enabled)
            return False
        return True

    def create_password(self, password: str, stay_logged_in: bool = False) -> bool:
        # Off by default: the app turns it on, and then a restart skips the
        # welcome-back screen that most tests log in through.
        self.logger.info("Creating password")

        # Before the fields: iOS can submit the page as soon as both are valid.
        if not self.set_stay_logged_in(stay_logged_in):
            return False

        if not self.enter_password(password):
            self.logger.error("Failed to enter password")
            return False

        if not self.confirm_password(password):
            self.logger.error("Failed to confirm password")
            return False

        time.sleep(1)  # Brief wait for validation

        return self.click_confirm_password_button()
