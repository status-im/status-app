from typing import Any

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

        On Android mobile the "Copy link to profile" action
        (``userStatusCopyLinkAction``) is permanently disabled in QML
        (``enabled: !SQUtils.Utils.isMobile``).  We still attempt it
        briefly (1 attempt, 2s timeout) because the profile popup needs
        those Appium driver interactions to render in the accessibility
        tree.  Then we fall back to the mobile "Invite contacts" path.

        Returns the captured link if successful, otherwise None.
        """
        from pages.app import App
        from utils.exceptions import ElementInteractionError
        self.logger.info("Capturing profile link for device %s", self.device_id)

        main_app = App(self.driver)

        # Try the quick clipboard copy — this also opens the profile
        # popup.  On mobile the copy action is disabled, so this fails
        # fast.  The important side effect is that the popup renders
        # during the brief interaction attempt.
        profile_link = None
        try:
            profile_link = main_app.copy_profile_link_from_menu(timeout=2)
        except (ElementInteractionError, Exception) as exc:
            self.logger.debug("Profile menu copy not available (expected on mobile): %s", exc)

        if profile_link:
            self.logger.info("Profile link captured via clipboard: %s", profile_link)
            self.set_state("profile_link", profile_link)
            if self.user:
                self.user.profile_link = profile_link
            return profile_link

        # The profile popup should still be open from the copy attempt.
        # Use the mobile-only "Invite contacts" path.
        self.logger.info("Using Invite contacts path for profile link")
        profile_link = self._capture_via_settings(main_app)

        # Re-activate app after overlay dismissal
        main_app.app_lifecycle.activate_app()

        if not profile_link:
            self.logger.error("All profile-link capture paths failed")
            return None

        self.logger.info("Profile link captured: %s", profile_link)
        self.set_state("profile_link", profile_link)

        if self.user:
            self.user.profile_link = profile_link

        return profile_link

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
                # Profile popup already open from a previous attempt.
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
            for i in range(overlays_to_dismiss):
                try:
                    self.driver.back()
                except Exception:
                    self.logger.debug(
                        "driver.back() #%d suppressed during overlay cleanup", i + 1
                    )

