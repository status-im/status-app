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

        # The in-app restart leaves the process RUNNING_IN_BACKGROUND on
        # Samsung/Moto and Appium can't force NOT_RUNNING; it isn't required
        # anyway — the caller cold-restarts next. Terminate best-effort.
        if not self.app_lifecycle.wait_for_app_not_running(timeout=10):
            self.logger.info("App still running after restart; best-effort terminate")
            try:
                self.app_lifecycle.terminate_app()
            except Exception as err:
                self.logger.debug("best-effort terminate failed: %s", err)
            self.app_lifecycle.wait_for_app_not_running(timeout=10)

        # 60s — re-encrypt + restart can take up to that on Pi devices.
        if not self.app_lifecycle.activate_app_with_ui_ready(activation_timeout=60.0):
            self.logger.warning(
                "Post-restart activation/UI-ready not confirmed; caller cold-restarts next"
            )

        # Push-notifications popup re-appears post-restart and overlays
        # the WelcomeBack login screen — dismiss it so perform_login can
        # focus the password input.
        try:
            from pages.onboarding.push_notifications_page import PushNotificationsPage
            push = PushNotificationsPage(self.driver)
            if push.is_screen_displayed(timeout=15):
                self.logger.info("Push-notifications popup detected post-restart, dismissing")
                push.select_maybe_later()
        except Exception as exc:
            self.logger.debug("Post-restart push-notifications dismiss suppressed: %s", exc)

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
