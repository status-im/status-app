import time
from typing import Optional

from selenium.webdriver.common.action_chains import ActionChains

try:
    from appium.webdriver.extensions.android.nativekey import AndroidKey
except Exception:  # pragma: no cover - fallback when import not available
    AndroidKey = None

from ..base_page import BasePage
from locators.wallet.accounts_locators import WalletAccountsLocators
from utils.exceptions import ElementInteractionError


class KeycardAuthenticationModal(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = WalletAccountsLocators()

    def is_displayed(self, timeout: int = 5) -> bool:
        field = self.find_element_safe(self.locators.KEYCARD_PASSWORD_INPUT, timeout=timeout)

        if not field and hasattr(self.locators, "KEYCARD_PASSWORD_INPUT_FALLBACK"):
            field = self.find_element_safe(
                self.locators.KEYCARD_PASSWORD_INPUT_FALLBACK, timeout=1
            )
        if field:
            try:
                loc = field.rect
                self.logger.debug("Keycard modal password field detected at %s", loc)
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

            def locate_field(find_timeout: int = timeout):
                candidate = self.find_element_safe(
                    self.locators.KEYCARD_PASSWORD_INPUT, timeout=find_timeout
                )
                if not candidate and hasattr(self.locators, "KEYCARD_PASSWORD_INPUT_FALLBACK"):
                    candidate = self.find_element_safe(
                        self.locators.KEYCARD_PASSWORD_INPUT_FALLBACK, timeout=2
                    )
                return candidate

            field = locate_field()
            if not field:
                self.logger.error("Password field not found")
                return False

            try:
                field.click()
            except Exception as e:
                self.logger.debug(f"authenticate field click failed, trying gesture: {e}")
                self.gestures.element_tap(field)

            try:
                focused = str(field.get_attribute("focused")).lower() == "true"
            except Exception as e:
                self.logger.debug(f"authenticate focus check failed: {e}")
                focused = False
            if not focused:
                try:
                    field.click()
                except Exception as e:
                    self.logger.debug(f"authenticate retry click failed, trying gesture: {e}")
                    self.gestures.element_tap(field)

            try:
                self.driver.update_settings({"sendKeyStrategy": "oneByOne"})
            except Exception as e:
                self.logger.debug(f"authenticate update_settings failed (continuing): {e}")

            try:
                ActionChains(self.driver).send_keys(password).perform()
                time.sleep(0.3)
                if not self._is_element_enabled(self.locators.KEYCARD_AUTHENTICATE_BUTTON):
                    self.logger.error("Authenticate button not enabled after typing password")
                    return False
                time.sleep(0.3)
                if not self._is_element_enabled(self.locators.KEYCARD_AUTHENTICATE_BUTTON):
                    self.logger.error("Authenticate button toggled off after input")
                    return False
            except Exception as exc:
                self.logger.error("Failed to type password: %s", exc)
                return False

            self.safe_click(self.locators.KEYCARD_AUTHENTICATE_BUTTON, timeout=timeout)
            return self.wait_for_invisibility(self.locators.KEYCARD_POPUP, timeout=timeout)

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
