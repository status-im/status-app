"""
Unified Test Execution Context for Appium-based E2E tests.
"""

from typing import Any, Dict, Optional
from contextlib import contextmanager

from appium.webdriver.webdriver import WebDriver

from core.session_manager import SessionManager
from pages.onboarding import HomePage
from pages.app import App
from utils.exceptions import SessionManagementError
from config import get_config
from config.logging_config import get_logger
from utils.gestures import Gestures
from utils.screenshot import save_screenshot
from utils.performance_monitor import PerformanceMonitor
from services import UserProfileService, AppStateManager, AppInitializationManager


from .models import TestUser, TestConfiguration
from .user_manager import UserManager


class TestContext:
    """Consolidates session, user, app state, and configuration management."""

    __test__ = False

    def __init__(
        self, environment: str = "browserstack", logger_name: str = "test_context"
    ):
        self.environment = environment
        self.logger = get_logger(logger_name)

        # Core components
        self._session_manager: Optional[SessionManager] = None
        self._driver: Optional[WebDriver] = None
        self._gestures: Optional[Gestures] = None
        self._main_app: Optional[HomePage] = None
        self._welcome_back: Optional[Any] = (
            None  # Simplified type for missing WelcomeBackPage
        )
        self._app: Optional[App] = None

        # Services
        self._user_service: Optional[UserProfileService] = None
        self._app_state_manager: Optional[AppStateManager] = None
        self._app_initialization: Optional[AppInitializationManager] = None

        # Context state
        self.config: Optional[TestConfiguration] = None
        self.users = None
        self.performance = PerformanceMonitor("test_context")

        # Lazy initialization flags
        self._initialized = False

    class UserManager(UserManager):
        pass

    @property
    def user_manager(self) -> "TestContext.UserManager":
        if self.users is None:
            self.users = TestContext.UserManager(self)
        return self.users

    def initialize(
        self,
        config: TestConfiguration,
        test_name: Optional[str] = None,
    ) -> "TestContext":
        self.config = config
        self.environment = config.environment

        try:
            # Create session manager
            self._session_manager = SessionManager(
                self.environment,
                device_override=config.device_override,
                device_id=config.device_id,
                device_tags=config.device_tags,
            )
            if test_name:
                self._session_manager.metadata.test_name = test_name

            self._driver = self._session_manager.get_driver()
            self._gestures = Gestures(self._driver)
            self._app = App(self._driver)

            # Initialize services
            self._user_service = UserProfileService(self._driver, self.performance)
            self._app_state_manager = AppStateManager(self._driver)
            self._app_initialization = AppInitializationManager(self._driver)

            activation_timeout = self._resolve_activation_timeout()

            # Initial app activation
            self._app_initialization.perform_initial_activation(
                timeout=activation_timeout
            )

            self._initialized = True
            self.logger.info("TestContext initialized for %s", self.environment)

            return self

        except Exception as e:
            self.logger.error("TestContext initialization failed: %s", e)
            raise SessionManagementError(
                f"Failed to initialize test context: {e}"
            ) from e

    def attach(
        self,
        driver: WebDriver,
        session_manager: Optional[SessionManager] = None,
        config: Optional[TestConfiguration] = None,
        test_name: Optional[str] = None,
    ) -> "TestContext":
        """
        Attach to an existing driver (and optional session manager).

        Use this when a higher-level test base already created the session
        (e.g., BaseTest). Avoids double sessions and improves stability.
        """
        try:
            if config:
                self.config = config
                if config.environment:
                    self.environment = config.environment
            self._driver = driver
            self._session_manager = session_manager
            self._gestures = Gestures(self._driver)
            self._app = App(self._driver)

            # Initialize services
            self._user_service = UserProfileService(self._driver, self.performance)
            self._app_state_manager = AppStateManager(self._driver)
            self._app_initialization = AppInitializationManager(self._driver)

            activation_timeout = self._resolve_activation_timeout()

            if test_name and self._session_manager:
                self._session_manager.metadata.test_name = test_name

            # Perform initial app activation
            self._app_initialization.perform_initial_activation(
                timeout=activation_timeout
            )

            self._initialized = True
            self.logger.info("TestContext attached to existing session")
            return self
        except Exception as e:
            self.logger.error("TestContext attach failed: %s", e)
            raise SessionManagementError(
                f"Failed to attach to existing context: {e}"
            ) from e

    def _resolve_activation_timeout(self) -> float:
        try:
            if self._session_manager and self._session_manager.env_config:
                timeout = self._session_manager.env_config.timeouts.get(
                    "activation", 15
                )
                return float(timeout)
        except Exception:
            pass
        return 15.0

    @property
    def driver(self) -> WebDriver:
        if not self._driver:
            raise SessionManagementError(
                "Driver not initialized - call initialize() first"
            )
        return self._driver

    def take_screenshot(self, name: Optional[str] = None) -> Optional[str]:
        try:
            config = get_config()
            base_dir = config.screenshots_dir or "screenshots"
        except Exception:
            base_dir = "screenshots"
        try:
            return save_screenshot(self.driver, base_dir, name)
        except Exception:
            return None

    @property
    def main_app(self) -> HomePage:
        if not self._main_app:
            self._main_app = HomePage(self.driver)
        return self._main_app

    @property
    def app(self) -> App:
        if not self._app:
            self._app = App(self.driver)
        return self._app

    @property
    def settings(self):
        from pages.settings.settings_page import SettingsPage

        return SettingsPage(self.driver)

    @property
    def welcome_back(self):
        if not self._welcome_back:
            from pages.onboarding import WelcomeBackPage

            self._welcome_back = WelcomeBackPage(self.driver)
        return self._welcome_back

    @property
    def user_service(self) -> UserProfileService:
        if not self._user_service:
            self._user_service = UserProfileService(self.driver, self.performance)
        return self._user_service

    @property
    def app_state_manager(self) -> AppStateManager:
        if not self._app_state_manager:
            self._app_state_manager = AppStateManager(self.driver)
        return self._app_state_manager

    @property
    def user(self) -> Optional[TestUser]:
        return self.user_service.current_user if self._user_service else None

    @property
    def app_state(self):
        return self.app_state_manager.state if self._app_state_manager else None

    def create_user_profile(
        self,
        method: Optional[str] = None,
        seed_phrase: Optional[str] = None,
        password: Optional[str] = None,
        display_name: Optional[str] = None,
    ) -> TestUser:
        if not self._initialized:
            raise SessionManagementError("TestContext not initialized")

        # Delegate to user service
        method = method or self.config.profile_method
        display_name = display_name or self.config.display_name
        password = password or "StatusPassword123!"

        user = self.user_service.create_profile(
            method=method,
            seed_phrase=seed_phrase,
            password=password,
            display_name=display_name,
            config={"validate_steps": getattr(self.config, "validate_steps", True)},
        )

        # Update app state after successful creation
        self.app_state_manager.state.is_home_loaded = True
        self.app_state_manager.state.current_screen = "home"

        return user

    def login_existing_user(self, password: Optional[str] = None) -> TestUser:
        if not self._initialized:
            raise SessionManagementError("TestContext not initialized")

        password = password or "StatusPassword123!"

        if not self.app_state.has_existing_profiles:
            raise SessionManagementError("No existing profiles detected")

        # Delegate to user service
        user = self.user_service.login_existing_user(password)

        # Update app state after successful login
        self.app_state_manager.state.is_home_loaded = True
        self.app_state_manager.state.current_screen = "home"
        self.app_state_manager.state.requires_authentication = False

        return user

    def restart_app_and_login(self) -> bool:
        """Restart app, handle authentication, and return True when back on home."""
        if not self._initialized or not self.user:
            raise SessionManagementError(
                "TestContext not properly initialized with user"
            )

        with self.performance.measure_operation("restart_app_and_login"):
            self.logger.info("Restarting app and handling authentication")

            # Restart app
            if not self.main_app.restart_app():
                self.logger.error("App restart failed")
                return False

            try:
                manager = self._app_initialization or AppInitializationManager(
                    self.driver
                )
                if not self._app_initialization:
                    self._app_initialization = manager
                manager.perform_initial_activation(timeout=3)
            except Exception as activation_err:
                self.logger.debug(
                    "Post-restart activation attempt failed: %s", activation_err
                )

            # Detect new state and handle authentication
            self.app_state_manager.detect_current_state()

            if self.app_state.requires_authentication:
                return self._handle_post_restart_authentication()
            elif self.app_state.is_home_loaded:
                self.logger.info("Auto-login successful")
                return True
            else:
                self.logger.error("Unknown app state after restart")
                return False

    def get_home(self, ensure: bool = True, auto_create: bool = True) -> HomePage:
        if ensure:
            # Refresh app state first
            self.app_state_manager.detect_current_state()

            if not self.app_state.is_home_loaded:
                # Try existing-user login if authentication is required
                if (
                    self.app_state.requires_authentication
                    and self.user_service.current_user
                ):
                    try:
                        self.logger.info(
                            "Auth required - attempting existing user login"
                        )
                        self.login_existing_user()
                    except Exception as e:
                        self.logger.warning(f"Existing user login failed: {e}")
                elif self.app_state.requires_authentication:
                    self.logger.info(
                        "Auth required but no known test user; skipping auto-login"
                    )

                # If still not loaded and allowed, create a user
                if not self.app_state.is_home_loaded and auto_create:
                    self.logger.info("Creating user to obtain home")
                    self.create_user_profile(method=self.config.profile_method)

            # Final assurance: home must be loaded
            if not self.app_state.is_home_loaded:
                raise SessionManagementError(
                    "Home not loaded after get_home() attempts"
                )
        return self.main_app

    def use_test_account(
        self,
        account: Dict[str, Any],
        simulate_returning: bool = False,
        login_only: bool = False,
    ) -> bool:
        """Import or log into a predefined test account."""
        if not self._initialized:
            raise SessionManagementError("TestContext not initialized")

        # Delegate to user service
        success = self.user_service.import_test_account(
            account,
            simulate_returning,
            login_only,
            self.config.display_name if self.config else "TestUser",
        )

        if success:
            # Update app state
            self.app_state_manager.detect_current_state()

        return success

    def cleanup(self):
        try:
            if self._session_manager:
                self.logger.info("Cleaning up test context")
                self._session_manager.cleanup_driver()
                self._session_manager = None
                self._driver = None

            # Reset state and services
            self._initialized = False
            self._user_service = None
            self._app_state_manager = None
            self._app_initialization = None
            self._welcome_back = None

            self.logger.info("TestContext cleanup completed")

        except Exception as e:
            self.logger.warning("TestContext cleanup warning: %s", e)

    # Per-context reporting helper routed through provider abstraction
    def report(
        self,
        status: str,
        error_message: Optional[str] = None,
        test_name: Optional[str] = None,
    ) -> None:
        if not self._session_manager:
            self.logger.warning(
                "Session manager not initialized; skipping session status report"
            )
            return

        if test_name:
            self._session_manager.metadata.test_name = test_name
        self._session_manager.report_result(status, error_message)

    def get_summary(self) -> Dict[str, Any]:
        return {
            "environment": self.environment,
            "initialized": self._initialized,
            "user": self.user.to_dict() if self.user else None,
            "app_state": {
                "is_home_loaded": self.app_state.is_home_loaded,
                "current_screen": self.app_state.current_screen,
                "requires_authentication": self.app_state.requires_authentication,
                "has_existing_profiles": self.app_state.has_existing_profiles,
            },
            "config": {
                "profile_method": self.config.profile_method if self.config else None,
                "display_name": self.config.display_name if self.config else None,
            }
            if self.config
            else None,
            "performance": self.performance.get_summary(),
        }

    def _detect_app_state(self):
        self.app_state_manager.detect_current_state()

    def _handle_post_restart_authentication(self) -> bool:
        if self.welcome_back.is_welcome_back_screen_displayed(timeout=10):
            self.logger.info("Handling welcome back authentication")
            try:
                # Use current user's password
                current_user = self.user_service.current_user
                password = (
                    current_user.password if current_user else "StatusPassword123!"
                )

                success = self.welcome_back.perform_login(password)
                if success and self.main_app.wait_for_home_load(timeout=30):
                    self.app_state_manager.state.is_home_loaded = True
                    self.app_state_manager.state.current_screen = "home"
                    self.app_state_manager.state.requires_authentication = False
                    return True
            except Exception as e:
                self.logger.error(f"Post-restart authentication failed: {e}")

        return False

    def _wait_for_app_ready(
        self, timeout: int = 30, poll_interval: float = 0.5
    ) -> bool:
        return self.app_state_manager.wait_for_app_ready(timeout, poll_interval)


@contextmanager
def test_context(environment: str = "browserstack", config: TestConfiguration = None):
    context = TestContext(environment)
    try:
        if config:
            context.initialize(config)
        yield context
    finally:
        context.cleanup()


def create_test_context_from_marker(request, environment: str = None) -> TestContext:
    config = TestConfiguration.from_pytest_marker(request, "create_profile_config")
    env = environment or config.environment

    context = TestContext(env)
    context.initialize(config)
    return context
