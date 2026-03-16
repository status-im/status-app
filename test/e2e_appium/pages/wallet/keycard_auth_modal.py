from locators.wallet.accounts_locators import WalletAccountsLocators
from utils.exceptions import ElementInteractionError

from ..base_page import BasePage


class KeycardAuthenticationModal(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = WalletAccountsLocators()

    def _password_locator(self) -> tuple:
        """Return the best password field locator.

        Prefer resource-id (objectName) over content-desc because the
        content-desc "Password" may match a wrapper element rather than
        the actual EditText on Android.
        """
        if self.find_element_safe(self.locators.KEYCARD_PASSWORD_INPUT_FALLBACK, timeout=3):
            return self.locators.KEYCARD_PASSWORD_INPUT_FALLBACK
        return self.locators.KEYCARD_PASSWORD_INPUT

    def is_displayed(self, timeout: int = 5) -> bool:
        field = self.find_element_safe(
            self.locators.KEYCARD_PASSWORD_INPUT_FALLBACK, timeout=timeout
        )
        if not field:
            field = self.find_element_safe(
                self.locators.KEYCARD_PASSWORD_INPUT, timeout=1
            )
        if field:
            try:
                self.logger.debug("Keycard modal password field detected at %s", field.rect)
            except Exception:
                pass
            return True
        return False

    def authenticate(self, password: str, timeout: int = 15) -> bool:
        if not password:
            return False

        try:
            if not self.is_displayed(timeout=timeout):
                self.logger.error("Auth modal not displayed")
                return False

            locator = self._password_locator()
            self.logger.info("Authenticating with locator: %s", locator)
            if not self.qt_safe_input(locator, password, verify=False):
                self.logger.error("Failed to type password into auth modal")
                self.dump_page_source("auth_password_input_failure")
                return False

            if not self.wait_for_element_enabled(
                self.locators.KEYCARD_AUTHENTICATE_BUTTON, timeout=5
            ):
                self.logger.error("Authenticate button not enabled after typing password")
                self.dump_page_source("auth_button_not_enabled")
                return False

            self.safe_click(self.locators.KEYCARD_AUTHENTICATE_BUTTON, timeout=timeout)
            if not self.wait_for_invisibility(self.locators.KEYCARD_POPUP, timeout=timeout):
                self.logger.error("Auth popup did not close after clicking Authenticate")
                self.dump_page_source("auth_popup_still_visible")
                return False
            return True

        except ElementInteractionError:
            raise
        except Exception as exc:
            self.logger.error("Auth flow failed: %s", exc, exc_info=True)
            return False

    def cancel(self) -> bool:
        if not self.is_displayed(timeout=2):
            return True
        self.safe_click(self.locators.KEYCARD_CANCEL_BUTTON, timeout=5)
        return self.wait_for_invisibility(self.locators.KEYCARD_POPUP, timeout=5)
