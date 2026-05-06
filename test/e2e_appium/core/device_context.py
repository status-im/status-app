from typing import Any
import time

from appium.webdriver.webdriver import WebDriver

from config.logging_config import get_logger
from core.models import TestUser
from fixtures.onboarding_fixture import OnboardingConfig, OnboardingFlow, OnboardingFlowError
from utils.exceptions import SessionManagementError


class DeviceState:
    """Internal state tracking for a device context."""

    def __init__(self):
        self.user: TestUser | None = None
        self._custom_state: dict[str, Any] = {}


class DeviceContext:

    __test__ = False

    def __init__(self, driver: WebDriver, device_id: str, device_config: dict[str, Any] | None = None):
        self.driver = driver
        self.device_id = device_id
        self.device_config = device_config or {}
        self._state = DeviceState()
        self.logger = get_logger(f"device_{device_id}")

    @property
    def user(self) -> TestUser | None:
        return self._state.user

    @user.setter
    def user(self, value: TestUser):
        self._state.user = value
        self.logger.debug("User state updated: %s", value.display_name if value else None)

    async def onboard_user(
        self,
        config: OnboardingConfig | None = None,
        display_name: str | None = None,
        password: str | None = None,
    ) -> TestUser:
        import asyncio

        self.logger.info("Starting user onboarding on device %s", self.device_id)

        if config is None:
            config = OnboardingConfig()

        if display_name:
            config.custom_display_name = display_name

        if password:
            config.custom_password = password

        def _onboard():
            try:
                flow = OnboardingFlow(self.driver, config, self.logger)
                result = flow.execute_complete_flow()

                if not result.get("success", False):
                    raise SessionManagementError(
                        f"Onboarding failed on device {self.device_id}: {result.get('error', 'Unknown error')}"
                    )

                user_data = result.get("user_data", {})
                if not user_data:
                    raise SessionManagementError(
                        f"Onboarding completed but no user data returned on device {self.device_id}"
                    )

                test_user = TestUser.from_onboarding_result(user_data, config)

                self.user = test_user
                self.logger.info(
                    "User onboarded successfully on device %s: %s",
                    self.device_id,
                    test_user.display_name,
                )

                return test_user

            except OnboardingFlowError as e:
                self.logger.error(
                    "OnboardingFlowError on device %s: %s",
                    self.device_id,
                    e,
                )
                raise SessionManagementError(
                    f"Failed to onboard user on device {self.device_id}: {e}"
                ) from e

            except Exception as e:
                self.logger.error(
                    "Unexpected error during onboarding on device %s: %s",
                    self.device_id,
                    e,
                )
                raise SessionManagementError(
                    f"Unexpected error during onboarding on device {self.device_id}: {e}"
                ) from e

        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _onboard)

    def get_state(self, key: str, default: Any = None) -> Any:
        return self._state._custom_state.get(key, default)

    def set_state(self, key: str, value: Any) -> None:
        self._state._custom_state[key] = value
        self.logger.debug("State updated: %s = %s", key, value)

    def clear_state(self) -> None:
        self._state._custom_state.clear()
        self.logger.debug("Custom state cleared")

    def capture_profile_link(self) -> str | None:
        """Capture the user's profile link.

        On Android the "Copy link to profile" action (``userStatusCopyLinkAction``)
        is permanently disabled in QML (``enabled: !SQUtils.Utils.isMobile``), so
        we go directly to the mobile "Invite contacts" path via ShareProfileDialog.

        Returns the captured link if successful, otherwise None.
        """
        from pages.app import App
        self.logger.info("Capturing profile link for device %s", self.device_id)

        main_app = App(self.driver)

        self.logger.info("Using Messages-panel shareProfileButton path for profile link")
        profile_link = self._capture_via_messages_panel(main_app)

        # The overlay cleanup uses driver.back() which can over-navigate
        # on Android — _restore_main_ui foregrounds the app again.
        self._restore_main_ui(main_app)

        # _restore_main_ui's activate_app shake unsticks the drawer's
        # gesture handler, so a second whole-path retry materially helps
        # if outer-5-retries inside the first call exhausted.
        if not profile_link:
            self.logger.warning(
                "First capture_profile_link pass failed — retrying after activate_app()"
            )
            profile_link = self._capture_via_messages_panel(main_app)
            self._restore_main_ui(main_app)

        if not profile_link:
            self.logger.error("All profile-link capture paths failed")
            return None

        self.logger.info("Profile link captured: %s", profile_link)
        self.set_state("profile_link", profile_link)

        if self.user:
            self.user.profile_link = profile_link

        return profile_link

    def _capture_via_messages_panel(self, app) -> str | None:
        """Capture profile link via the Messages section's
        shareProfileButton (ContactsColumnView header).

        The drawer's profile-avatar tap is unusable on BS portrait — the
        avatar exposes as ``android.app.ActionBar.Tab`` with
        ``clickable=false``, so both ``element.click()`` and
        ``mobile: clickGesture`` no-op.
        """
        from locators.app_locators import AppLocators
        from locators.messaging.chat_locators import ChatLocators
        from locators.settings.profile_locators import ProfileSettingsLocators
        from pages.settings.share_profile_dialog import ShareProfileDialog
        from utils.gestures import Gestures

        gestures = Gestures(self.driver)
        app_locators = AppLocators()
        chat_locators = ChatLocators()
        profile_locators = ProfileSettingsLocators()
        overlays_to_dismiss = 0

        try:
            on_messages = False
            max_outer_attempts = 5
            for outer_attempt in range(1, max_outer_attempts + 1):
                self.logger.info(
                    "Messages-nav outer attempt %d/%d", outer_attempt, max_outer_attempts
                )

                app._ensure_main_nav_visible()
                time.sleep(1.5)  # drawer slide-in animation settle

                max_taps = 5
                for tap_attempt in range(1, max_taps + 1):
                    if not app.is_element_visible(
                        app_locators.LEFT_NAV_SETTINGS, timeout=1
                    ):
                        self.logger.info(
                            "Drawer closed after %d tap(s)", tap_attempt - 1
                        )
                        break

                    msg_el = app.find_element_safe(
                        app_locators.LEFT_NAV_MESSAGES, timeout=3
                    )
                    if msg_el is None:
                        self.logger.warning(
                            "LEFT_NAV_MESSAGES not visible at tap attempt %d",
                            tap_attempt,
                        )
                        app._ensure_main_nav_visible()
                        time.sleep(1.0)
                        continue

                    rect = msg_el.rect
                    cx = int(rect["x"] + rect["width"] / 2)
                    cy = int(rect["y"] + rect["height"] / 2)
                    self.logger.info(
                        "Messages-navbar W3C-pointer click attempt %d at (%d,%d) "
                        "rect=[x=%d,y=%d,w=%d,h=%d]",
                        tap_attempt, cx, cy,
                        rect["x"], rect["y"], rect["width"], rect["height"],
                    )
                    if not gestures.tap(cx, cy):
                        self.logger.warning(
                            "W3C-pointer click failed on attempt %d", tap_attempt
                        )
                    # Brief wait so the next drawer-closed check sees
                    # post-tap state; the real patience is in the 30s
                    # SHARE_PROFILE_BUTTON poll below.
                    time.sleep(2.0)

                # Dismiss backup-recovery popup that may overlay
                # Messages section. mobile:clickGesture with elementId
                # — element.click() has the same BS-portrait mis-routing.
                for dismiss_attempt in range(1, 4):
                    skip_el = app.find_element_safe(chat_locators.BACKUP_SKIP_BUTTON, timeout=2)
                    if skip_el is None:
                        break
                    self.logger.info(
                        "Dismissing backup popup via clickGesture (attempt %d)",
                        dismiss_attempt,
                    )
                    try:
                        self.driver.execute_script(
                            "mobile: clickGesture",
                            {"elementId": skip_el.id},
                        )
                    except Exception as exc:
                        self.logger.debug("clickGesture on Skip suppressed: %s", exc)
                    time.sleep(1.0)  # popup dismiss animation

                time.sleep(1.0)  # let any final overlay settle before polling

                # 30s — landmark can take 15-25s on BS portrait (section
                # transition + AT-tree settle). Re-tapping resets it.
                if app.is_element_visible(profile_locators.SHARE_PROFILE_BUTTON, timeout=30):
                    on_messages = True
                    self.logger.info(
                        "Messages section + shareProfileButton confirmed on outer attempt %d",
                        outer_attempt,
                    )
                    break

                self.logger.warning(
                    "Drawer closed but shareProfileButton not visible — retrying (outer attempt %d)",
                    outer_attempt,
                )

            if not on_messages:
                self.logger.error(
                    "Failed to navigate to Messages section after %d outer attempts",
                    max_outer_attempts,
                )
                return None

            if not app.safe_click(profile_locators.SHARE_PROFILE_BUTTON, timeout=5):
                self.logger.error("Failed to click shareProfileButton")
                return None

            dialog = ShareProfileDialog(self.driver)
            if not dialog.is_displayed(timeout=10):
                self.logger.error("ShareProfileDialog did not appear after shareProfileButton tap")
                return None
            overlays_to_dismiss = 1

            link = dialog.get_profile_link()
            if not link:
                self.logger.error("ShareProfileDialog did not contain a profile link")
                return None

            return link
        finally:
            dialog_locator = ("xpath", "//*[contains(@resource-id,'ShareProfileDialog')]")
            if overlays_to_dismiss and app.is_element_visible(dialog_locator, timeout=1):
                try:
                    self.driver.back()
                except Exception:
                    self.logger.debug("driver.back() suppressed during overlay cleanup")

    def _capture_via_settings(self, app) -> str | None:
        """Capture profile link via the mobile 'Invite contacts' flow.

        On Android the profile menu exposes "Invite contacts" instead of
        "Copy link to profile".  Tapping it opens the ShareProfileDialog
        which contains the link.

        This method ensures all overlays it opens (profile popup and
        ShareProfileDialog) are dismissed before returning, so the caller
        gets a clean navigation state.
        """
        from locators.app_locators import AppLocators
        from pages.settings.share_profile_dialog import ShareProfileDialog

        locators = AppLocators()
        overlays_to_dismiss = 0

        INVITE_ACTION = ("xpath", "//*[contains(@resource-id,'userStatusShareProfileAction')]")

        try:
            invite_visible = app.is_element_visible(INVITE_ACTION, timeout=2)
            if invite_visible:
                # Profile popup is already open (e.g. retry after partial failure).
                overlays_to_dismiss = 1
            else:
                try:
                    app._ensure_main_nav_visible()
                    app.safe_click(locators.PROFILE_NAV_BUTTON, timeout=5)
                    overlays_to_dismiss = 1
                except Exception as exc:
                    self.logger.error("Failed to open profile menu for invite path: %s", exc)
                    return None
                invite_visible = app.is_element_visible(INVITE_ACTION, timeout=15)

            if not invite_visible:
                self.logger.error("Invite contacts action not visible in profile menu")
                app.dump_page_source("invite_action_not_visible")
                return None

            try:
                app.safe_click(INVITE_ACTION, timeout=5)
            except Exception as exc:
                self.logger.error("Failed to click Invite contacts: %s", exc)
                return None

            dialog = ShareProfileDialog(self.driver)
            if not dialog.is_displayed(timeout=10):
                self.logger.error("ShareProfileDialog did not appear after invite tap")
                return None

            # ShareProfileDialog sits on top of the profile popup — two layers.
            overlays_to_dismiss = 2

            link = dialog.get_profile_link()
            if not link:
                self.logger.error("ShareProfileDialog did not contain a profile link")
                return None

            return link
        finally:
            # Dismiss overlays cautiously — verify each one is still
            # present before pressing back, to avoid navigating out of
            # the app entirely.
            dialog_locator = ("xpath", "//*[contains(@resource-id,'ShareProfileDialog')]")
            popup_locator = ("xpath", "//*[contains(@resource-id,'userStatusShareProfileAction') "
                             "or contains(@resource-id,'ProfileMenu')]")

            for i, check_locator in enumerate(
                [dialog_locator, popup_locator][:overlays_to_dismiss]
            ):
                if app.is_element_visible(check_locator, timeout=1):
                    try:
                        self.driver.back()
                        self.logger.debug("driver.back() #%d dismissed overlay", i + 1)
                    except Exception:
                        self.logger.debug(
                            "driver.back() #%d suppressed during overlay cleanup", i + 1
                        )
                else:
                    self.logger.debug(
                        "Overlay #%d already gone, skipping back()", i + 1
                    )

    def _restore_main_ui(self, app) -> None:
        """Ensure the Status app is in the foreground with the main nav visible.

        After overlay cleanup the app may have been sent to the background
        by an extra ``driver.back()``.  This method re-activates the app
        and waits for the left navigation bar to become visible.
        """
        from locators.app_locators import AppLocators

        locators = AppLocators()

        app.app_lifecycle.activate_app()

        # Quick check — if the nav bar is already there, we're done.
        if app.is_element_visible(locators.LEFT_NAV_WALLET, timeout=3):
            self.logger.debug("Main UI already visible after activate_app()")
            return

        # The app may need a moment to fully resume.  Try activating once
        # more, then give it a longer wait.
        self.logger.info("Main nav not visible after activate_app(), retrying")
        app.app_lifecycle.activate_app()

        if not app.is_element_visible(locators.LEFT_NAV_WALLET, timeout=10):
            self.logger.warning(
                "Main nav still not visible after second activate_app() — "
                "subsequent steps may fail"
            )
            app.dump_page_source("restore_main_ui_failure")

