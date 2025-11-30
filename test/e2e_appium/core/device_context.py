from typing import Optional, Dict, Any

from appium.webdriver.webdriver import WebDriver

from config.logging_config import get_logger
from core.models import TestUser
from fixtures.onboarding_fixture import OnboardingFlow, OnboardingConfig, OnboardingFlowError
from utils.exceptions import SessionManagementError


class DeviceState:
    """Internal state tracking for a device context."""

    def __init__(self):
        self.user: Optional[TestUser] = None
        self._custom_state: Dict[str, Any] = {}


class DeviceContext:

    __test__ = False

    def __init__(self, driver: WebDriver, device_id: str, device_config: Optional[Dict[str, Any]] = None):
        self.driver = driver
        self.device_id = device_id
        self.device_config = device_config or {}
        self._state = DeviceState()
        self.logger = get_logger(f"device_{device_id}")

    @property
    def user(self) -> Optional[TestUser]:
        return self._state.user

    @user.setter
    def user(self, value: TestUser):
        self._state.user = value
        self.logger.debug("User state updated: %s", value.display_name if value else None)

    async def onboard_user(
        self,
        config: Optional[OnboardingConfig] = None,
        display_name: Optional[str] = None,
        password: Optional[str] = None,
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

    def capture_profile_link(self) -> Optional[str]:
        """
        Navigate to Settings → Profile → Share Profile and capture the profile link.

        Returns the captured link if successful, otherwise None.
        """
        from pages.app import App
        self.logger.info("Capturing profile link for device %s", self.device_id)

        main_app = App(self.driver)
        profile_link = main_app.copy_profile_link_from_menu()
        if not profile_link:
            self.logger.error("Failed to capture profile link from profile menu")
            return None

        self.logger.info("Profile link captured: %s", profile_link)
        self.set_state("profile_link", profile_link)

        if self.user:
            setattr(self.user, "profile_link", profile_link)

        return profile_link

