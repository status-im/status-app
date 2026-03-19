import time
from typing import Optional, Dict, Any

from config.logging_config import get_logger
from core.models import TestUser
from utils.generators import generate_seed_phrase
from utils.onboarding_classes import ProfileCreationFlow, ProfileCreationConfig
from core.environment import ConfigurationError
from utils.exceptions import (
    SessionManagementError,
)


class UserProfileService:

    def __init__(self, driver, performance_monitor=None):
        self.driver = driver
        self.performance = performance_monitor
        self.logger = get_logger("user_profile_service")
        self._current_user: Optional[TestUser] = None

    @property
    def current_user(self) -> Optional[TestUser]:
        return self._current_user

    def create_profile(
        self,
        method: str = "password",
        seed_phrase: Optional[str] = None,
        password: str = "StatusPassword123!",
        display_name: str = "TestUser",
        config: Optional[Dict[str, Any]] = None,
    ) -> TestUser:
        """Create a new user profile using specified method."""
        operation_name = f"create_profile_{method}"

        if self.performance:
            self.performance.start_timer(operation_name)

        try:
            self.logger.info(
                f"🎯 Creating user profile: {display_name} (method: {method})"
            )

            if method == "password":
                user = TestUser(
                    display_name=display_name,
                    password=password,
                    source="created_password",
                )
            elif method == "seed_phrase":
                user = TestUser(
                    display_name=display_name,
                    password=password,
                    seed_phrase=seed_phrase or generate_seed_phrase(),
                    source="created_seed_phrase",
                )
            elif method == "random":
                user = TestUser(
                    display_name=f"{display_name}_{int(time.time())}",
                    password=password,
                    seed_phrase=generate_seed_phrase(),
                    source="created_random",
                )
            else:
                raise ConfigurationError(f"Invalid profile creation method: {method}")

            # Execute profile creation via ProfileCreationFlow
            success = self._execute_profile_creation(user, method, config)
            if not success:
                raise SessionManagementError(
                    f"Failed to create profile for {display_name}"
                )

            self._current_user = user
            self.logger.info(f"✅ User profile created: {user.display_name}")

            if self.performance:
                self.performance.end_timer(operation_name)

            return user

        except Exception:
            if self.performance:
                self.performance.end_timer(operation_name)
            raise

    def login_existing_user(self, password: str = "StatusPassword123!") -> TestUser:
        """Login to existing user profile."""
        if self.performance:
            self.performance.start_timer("login_existing_user")

        try:
            self.logger.info("🔑 Attempting to login with existing user")

            # Import required page objects
            from pages.onboarding import WelcomeBackPage, HomePage

            welcome_back = WelcomeBackPage(self.driver)
            main_app = HomePage(self.driver)

            if welcome_back.is_welcome_back_screen_displayed(timeout=10):
                success = welcome_back.perform_login(password)
                if not success:
                    raise SessionManagementError("Login to existing profile failed")

                if main_app.wait_for_home_load(timeout=30):
                    user = TestUser(
                        display_name="ExistingUser",
                        password=password,
                        source="existing_profile",
                    )

                    self._current_user = user
                    self.logger.info("✅ Successfully logged into existing profile")

                    if self.performance:
                        self.performance.end_timer("login_existing_user")

                    return user

            raise SessionManagementError("Could not complete login to existing profile")

        except Exception:
            if self.performance:
                self.performance.end_timer("login_existing_user")
            raise

    def import_test_account(
        self,
        account: Dict[str, Any],
        simulate_returning: bool = False,
        login_only: bool = False,
        default_display_name: str = "TestUser",
    ) -> bool:
        """Import or log into a predefined test account."""
        display_name = account.get("display_name", default_display_name)
        password = account.get("password", "StatusPassword123!")
        seed_phrase = account.get("seed_phrase")

        if login_only:
            try:
                self._current_user = TestUser(
                    display_name=display_name,
                    password=password,
                    seed_phrase=seed_phrase,
                    source="existing_profile",
                )
                self.login_existing_user(password=password)
                return True
            except Exception as e:
                self.logger.error(f"Login-only path failed: {e}")
                return False

        try:
            if not seed_phrase:
                self.logger.warning(
                    "No seed_phrase provided; falling back to password profile creation"
                )
                self.create_profile(
                    method="password", password=password, display_name=display_name
                )
            else:
                self.create_profile(
                    method="seed_phrase",
                    seed_phrase=seed_phrase,
                    password=password,
                    display_name=display_name,
                )

            if simulate_returning:
                # Would need app restart capability - delegate to calling code
                self.logger.info("Simulate returning user requested - restart needed")

            return True

        except Exception as e:
            self.logger.error(f"import_test_account failed: {e}")
            return False

    def _execute_profile_creation(
        self, user: TestUser, method: str, config: Optional[Dict[str, Any]]
    ) -> bool:
        try:
            # Map to ProfileCreationConfig
            use_seed = method == "seed_phrase"
            flow_config = ProfileCreationConfig(
                use_seed_phrase=use_seed,
                seed_phrase=user.seed_phrase if use_seed else None,
                password=user.password,
                display_name=user.display_name,
                validate_each_step=config.get("validate_steps", True)
                if config
                else True,
                take_screenshots=config.get("take_screenshots", False)
                if config
                else False,
                timeout_seconds=60,
            )

            self.logger.info(
                f"Executing ProfileCreationFlow for user '{user.display_name}' (method={method})"
            )
            flow = ProfileCreationFlow(self.driver, flow_config, self.logger)
            result = flow.execute_complete_flow()

            if not result or not result.get("success"):
                self.logger.error(
                    f"ProfileCreationFlow failed for '{user.display_name}': {result}"
                )
                return False

            # Extract user data from flow result if present
            data = result.get("user_data") or {}
            display_name = data.get("display_name") or user.display_name
            user.display_name = display_name

            return True

        except Exception as e:
            self.logger.error(f"Profile creation error: {e}")
            return False
