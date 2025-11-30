import time
from typing import TYPE_CHECKING, Optional

from ..base_page import BasePage
from locators.settings.password_change_locators import ChangePasswordModalLocators
from utils.element_state_checker import ElementStateChecker

if TYPE_CHECKING:
    from core.models import TestUser


class ChangePasswordModal(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ChangePasswordModalLocators()

    def is_displayed(self, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(self.locators.MODAL_CONTAINER, timeout=timeout)

    def wait_for_completion(self, timeout: int = 60) -> bool:
        return self.is_element_visible(
            self.locators.STATUS_MESSAGE,
            timeout=timeout,
        )

    def complete_reencrypt_and_restart(
        self,
        new_password: Optional[str] = None,
        user: Optional["TestUser"] = None,
        timeout: int = 90,
    ) -> bool:
        if not self.safe_click(self.locators.PRIMARY_BUTTON, timeout=15):
            self.logger.error("Primary restart button not clickable on change-password modal")
            return False

        try:
            _ = self.driver.page_source
        except Exception:
            pass

        deadline = time.time() + timeout
        attempt = 1
        restart_confirmed = False

        while time.time() < deadline:
            modal_present = self.find_element_safe(
                self.locators.MODAL_CONTAINER, timeout=1
            )
            if not modal_present:
                restart_confirmed = True
                break

            button = self.find_element_safe(self.locators.PRIMARY_BUTTON, timeout=1)
            if button and ElementStateChecker.is_displayed(button):
                if ElementStateChecker.is_enabled(button):
                    self.logger.debug(
                        "Restart button still visible; tapping attempt %s", attempt + 1
                    )
                    try:
                        self.safe_click(
                            self.locators.PRIMARY_BUTTON, timeout=5, max_attempts=1
                        )
                    except Exception as err:
                        self.logger.debug(
                            "Restart button tap attempt %s failed: %s", attempt + 1, err
                        )
                    attempt += 1
                else:
                    time.sleep(1.0)
            else:
                time.sleep(0.5)

        if not restart_confirmed:
            self.logger.error("Change password modal remained visible after restart attempts")
            return False

        if not self.app_lifecycle.wait_for_app_not_running(timeout=30):
            self.logger.error("App never reached NOT_RUNNING state after tapping restart")
            return False

        if not self.app_lifecycle.activate_app_with_ui_ready():
            self.logger.error("App activation with UI ready failed after password change")
            return False

        if user and new_password:
            user.password = new_password

        return True

    def _wait_for_primary_button_enabled(self, timeout: int = 10) -> bool:
        deadline = time.time() + timeout
        while time.time() < deadline:
            element = self.find_element_safe(self.locators.PRIMARY_BUTTON, timeout=2)
            if not element:
                return False
            try:
                if element.is_displayed() and element.is_enabled():
                    return True
            except Exception:
                pass
            time.sleep(0.3)
        return False
