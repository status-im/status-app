"""
Onboarding Flow Fixture for E2E Tests

This module provides reusable fixtures for onboarding functionality that can be
used across multiple test suites. It follows the Page Object Model pattern and
provides flexible configuration options.
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional, Dict, Any
import pytest
import time
from datetime import datetime

from pages.onboarding import (
    WelcomePage,
    AnalyticsPage,
    CreateProfilePage,
    SeedPhraseInputPage,
    PasswordPage,
    SplashScreen,
    BiometricsPage,
)
from pages.app import App
from utils.generators import generate_seed_phrase
from models.user_model import User, UserProfile
from config import get_config
from config.logging_config import get_logger
from core.models import DEFAULT_USER_PASSWORD
from locators.wallet.accounts_locators import WalletAccountsLocators
from services.app_initialization_manager import AppInitializationManager


@dataclass
class OnboardingConfig:
    """Configuration options for onboarding flow execution"""

    skip_analytics: bool = True
    skip_profile_creation: bool = False
    custom_user_data: Optional[Dict[str, Any]] = None
    timeout_per_step: int = 30
    take_screenshots: bool = False
    screenshot_path: Optional[str] = None
    validate_each_step: bool = True

    # Advanced options
    custom_password: Optional[str] = None
    custom_display_name: Optional[str] = None
    wait_for_complete_loading: bool = True
    verify_main_app: bool = True

    # Seed phrase import options
    use_seed_phrase: bool = False
    seed_phrase: Optional[str] = None
    seed_phrase_autocomplete: bool = False

    # Test context
    test_environment: str = "e2e_test"
    test_metadata: Dict[str, Any] = field(default_factory=dict)


class OnboardingFlow:
    """
    Encapsulates the complete onboarding flow with reusable methods.

    This class provides a clean interface for executing onboarding steps
    and can be configured for different test scenarios.
    """

    def __init__(self, driver, config: OnboardingConfig = None, logger=None):
        self.driver = driver
        self.config = config or OnboardingConfig()
        self.logger = logger or get_logger("onboarding_flow")

        if self.config.take_screenshots and not self.config.screenshot_path:
            try:
                resolved_dir = get_config().screenshots_dir
                if resolved_dir:
                    Path(resolved_dir).mkdir(parents=True, exist_ok=True)
                    self.config.screenshot_path = resolved_dir
            except Exception as exc:
                self.logger.debug("Screenshot config unavailable: %s", exc)

        # Initialize page objects
        self.welcome_page = WelcomePage(self.driver)
        self.analytics_page = AnalyticsPage(self.driver)
        self.create_profile_page = CreateProfilePage(self.driver)
        self.seed_phrase_page = SeedPhraseInputPage(self.driver)
        self.password_page = PasswordPage(self.driver)
        self.biometrics_page = BiometricsPage(self.driver)
        self.loading_page = SplashScreen(self.driver)
        self.app = App(self.driver)

        # Track execution state
        self.current_step = "initialization"
        self.start_time = datetime.now()
        self.step_results = {}

        # Generate test user if not provided
        self.test_user = self._create_test_user()

    def _create_test_user(self) -> User:
        """Create a test user with appropriate data for the environment"""

        if self.config.custom_user_data:
            return User.from_test_data(self.config.custom_user_data)

        # Create user with custom overrides
        display_name = (
            self.config.custom_display_name
            or f"E2E_User_{datetime.now().strftime('%H%M%S')}"
        )

        password = self.config.custom_password or DEFAULT_USER_PASSWORD

        profile = UserProfile(
            display_name=display_name,
            bio=f"Created during E2E test at {datetime.now().isoformat()}",
        )

        return User(
            profile=profile,
            password=password,
            environment=self.config.test_environment,
            test_context=self.config.test_metadata,
        )

    def execute_complete_flow(self) -> Dict[str, Any]:
        """
        Execute the complete onboarding flow.

        Returns:
            Dict containing execution results and metadata
        """
        flow_type = (
            "seed phrase import"
            if self.config.use_seed_phrase
            else "new profile creation"
        )
        self.logger.info(
            f"🚀 Starting complete onboarding flow execution ({flow_type})"
        )

        try:
            # Step 1: Welcome Screen
            self._execute_welcome_step()

            # Step 2: Analytics Screen (conditionally skip)
            if not self.config.skip_analytics:
                self._execute_analytics_step()
            else:
                self._execute_analytics_skip_step()

            if self.config.use_seed_phrase:
                self._execute_seed_phrase_import_step()
            else:
                if not self.config.skip_profile_creation:
                    self._execute_create_profile_step()

            self._execute_password_step()

            self._execute_biometrics_step()

            self._execute_loading_step()

            if self.config.verify_main_app:
                self._execute_main_app_verification()

            execution_result = self._build_success_result()
            self.logger.info(
                f"✅ Complete onboarding flow executed successfully ({flow_type})"
            )
            return execution_result

        except Exception as e:
            error_result = self._build_error_result(e)
            self.logger.error(
                f"❌ Onboarding flow failed at step '{self.current_step}': {str(e)}"
            )
            raise OnboardingFlowError(
                f"Onboarding failed at step '{self.current_step}': {str(e)}",
                step=self.current_step,
                results=error_result,
            )

    def _execute_welcome_step(self):
        """Execute welcome screen interaction"""
        self.current_step = "welcome_screen"
        self.logger.info("Step 1: Welcome Screen")

        # Wait for session to be ready before checking for UI
        try:
            init_manager = AppInitializationManager(self.driver)
            init_manager._wait_for_session_ready(timeout=5.0)
        except Exception as exc:
            self.logger.debug("Session readiness check skipped: %s", exc)

        max_wait = 10
        for attempt in range(max_wait):
            try:
                elements = self.app.driver.find_elements("xpath", "//*")
                if len(elements) > 5:
                    break
                time.sleep(1)
            except Exception:
                time.sleep(1)
        
        try:
            self.app.driver.tap([(500, 300)])  
            time.sleep(1)
        except Exception:
            self.logger.debug("Initial tap attempt skipped", exc_info=True)

        if self.config.validate_each_step:
            welcome_visible = False
            for attempt in range(3):
                if self.welcome_page.is_screen_displayed(timeout=10):
                    welcome_visible = True
                    break
                if attempt < 2:
                    self.logger.debug(
                        f"Welcome screen not visible yet (attempt {attempt + 1}/3), waiting..."
                    )
                    time.sleep(2)
            
            assert welcome_visible, (
                "Welcome screen should be displayed"
            )

        self.welcome_page.click_create_profile()

        self.step_results["welcome_screen"] = {
            "success": True,
            "timestamp": datetime.now(),
        }

        if self.config.take_screenshots:
            self._take_screenshot("welcome_completed")

    def _execute_seed_phrase_import_step(self):
        self.current_step = "seed_phrase_import"
        self.logger.info("Step 3: Seed Phrase Import")

        if self.config.validate_each_step:
            assert self.create_profile_page.is_screen_displayed(), (
                "Create profile screen should be displayed before seed phrase import"
            )

        self.create_profile_page.click_use_recovery_phrase()

        seed_phrase = self.config.seed_phrase or generate_seed_phrase()
        self.config.seed_phrase = seed_phrase

        seed_page = SeedPhraseInputPage(self.driver, flow_type="create")
        if self.config.validate_each_step:
            assert seed_page.is_screen_displayed(), (
                "Seed phrase input screen should be displayed"
            )

        success = seed_page.import_seed_phrase(seed_phrase)
        assert success, "Should successfully import seed phrase via clipboard"

        self.step_results["seed_phrase_import"] = {
            "success": True,
            "word_count": len(seed_phrase.split()),
            "timestamp": datetime.now(),
        }

        if self.config.take_screenshots:
            self._take_screenshot("seed_phrase_import_completed")

    def _execute_analytics_step(self):
        self.current_step = "analytics_screen"
        self.logger.info("Step 2: Analytics Screen (interacting)")

        if self.config.validate_each_step:
            assert self.analytics_page.is_screen_displayed(), (
                "Analytics screen should be displayed"
            )

        self.analytics_page.accept_analytics_sharing()

        self.step_results["analytics_screen"] = {
            "success": True,
            "action": "shared",
            "timestamp": datetime.now(),
        }

    def _execute_analytics_skip_step(self):
        self.current_step = "analytics_screen_skip"
        self.logger.info("Step 2: Analytics Screen (skipping)")

        if self.config.validate_each_step:
            assert self.analytics_page.is_screen_displayed(), (
                "Analytics screen should be displayed"
            )

        self.analytics_page.skip_analytics_sharing()

        self.step_results["analytics_screen"] = {
            "success": True,
            "action": "skipped",
            "timestamp": datetime.now(),
        }

        if self.config.take_screenshots:
            self._take_screenshot("analytics_skipped")

    def _execute_create_profile_step(self):
        self.current_step = "create_profile_screen"
        self.logger.info("Step 3: Create Profile Screen")

        if self.config.validate_each_step:
            assert self.create_profile_page.is_screen_displayed(), (
                "Create profile screen should be displayed"
            )

        self.create_profile_page.click_lets_go()

        self.step_results["create_profile_screen"] = {
            "success": True,
            "timestamp": datetime.now(),
        }

        if self.config.take_screenshots:
            self._take_screenshot("profile_created")

    def _execute_password_step(self):
        self.current_step = "password_screen"
        self.logger.info("Step 4: Password Screen")

        if self.config.validate_each_step:
            assert self.password_page.is_screen_displayed(), (
                "Password screen should be displayed"
            )

        success = self.password_page.create_password(self.test_user.password)
        assert success, "Should successfully create password"

        self.step_results["password_screen"] = {
            "success": True,
            "password_length": len(self.test_user.password),
            "timestamp": datetime.now(),
        }

        if self.config.take_screenshots:
            self._take_screenshot("password_created")

    def _execute_biometrics_step(self):
        """Dismiss biometrics prompt if it appears after password confirmation."""
        self.current_step = "biometrics_screen"
        self.logger.info("Step 5: Biometrics Screen (dismiss if present)")

        if self.biometrics_page.is_screen_displayed(timeout=3):
            self.logger.info("Biometrics prompt detected, selecting 'Maybe later'")
            dismissed = self.biometrics_page.select_maybe_later()
            if not dismissed:
                self.logger.error("Failed to dismiss biometrics prompt")
            self.step_results["biometrics_screen"] = {
                "success": dismissed,
                "action": "dismissed" if dismissed else "dismiss_failed",
                "timestamp": datetime.now(),
            }
        else:
            self.logger.info("Biometrics prompt not displayed, skipping")
            self.step_results["biometrics_screen"] = {
                "success": True,
                "action": "not_displayed",
                "timestamp": datetime.now(),
            }

        if self.config.take_screenshots:
            self._take_screenshot("biometrics_handled")

    def _execute_loading_step(self):
        """Execute loading screen wait"""
        self.current_step = "loading_screen"
        self.logger.info("Step 6: Loading Screen")

        if self.config.wait_for_complete_loading:
            success = self.loading_page.wait_for_loading_completion()
            assert success, "Should successfully complete loading"

        self.step_results["loading_screen"] = {
            "success": True,
            "timestamp": datetime.now(),
        }

    def _execute_main_app_verification(self):
        """Execute main app verification"""
        self.current_step = "wallet_verification"
        self.logger.info("Step 7: Wallet Landing Verification")

        assert self.app.is_element_visible(
            WalletAccountsLocators.ADD_ACCOUNT_BUTTON
        ), "Wallet landing screen should be visible after onboarding"

        self.step_results["wallet_verification"] = {
            "success": True,
            "timestamp": datetime.now(),
        }

        if self.config.take_screenshots:
            self._take_screenshot("onboarding_completed")

    def _take_screenshot(self, name: str):
        """Take screenshot during flow execution"""
        try:
            base_dir = self.config.screenshot_path
            if not base_dir:
                base_dir = get_config().screenshots_dir
        except Exception as exc:
            self.logger.debug("Screenshot dir config failed: %s", exc)
            base_dir = None

        if base_dir:
            try:
                Path(base_dir).mkdir(parents=True, exist_ok=True)
                timestamp = datetime.now().strftime("%H%M%S")
                screenshot_name = f"{name}_{timestamp}.png"
                screenshot_path = Path(base_dir) / screenshot_name
                self.driver.save_screenshot(str(screenshot_path))
                self.logger.debug(f"📷 Screenshot saved: {screenshot_path}")
            except Exception as e:
                self.logger.warning(f"⚠️ Failed to take screenshot '{name}': {e}")

    def _build_success_result(self) -> Dict[str, Any]:
        """Build success result dictionary"""
        end_time = datetime.now()
        duration = (end_time - self.start_time).total_seconds()

        return {
            "success": True,
            "user_data": self.test_user.to_test_data(),
            "execution_time_seconds": duration,
            "steps_completed": list(self.step_results.keys()),
            "step_results": self.step_results,
            "config": self.config,
            "start_time": self.start_time.isoformat(),
            "end_time": end_time.isoformat(),
        }

    def _build_error_result(self, error: Exception) -> Dict[str, Any]:
        """Build error result dictionary"""
        end_time = datetime.now()
        duration = (end_time - self.start_time).total_seconds()

        return {
            "success": False,
            "error": str(error),
            "failed_step": self.current_step,
            "execution_time_seconds": duration,
            "steps_completed": list(self.step_results.keys()),
            "step_results": self.step_results,
            "config": self.config,
            "start_time": self.start_time.isoformat(),
            "end_time": end_time.isoformat(),
        }




class OnboardingFlowError(Exception):
    """Custom exception for onboarding flow failures"""

    def __init__(self, message: str, step: str = None, results: Dict[str, Any] = None):
        super().__init__(message)
        self.step = step
        self.results = results


# Pytest Fixtures


@pytest.fixture(scope="function")
def onboarding_config():
    """Default onboarding configuration fixture"""
    return OnboardingConfig()


@pytest.fixture(scope="function")
def custom_onboarding_config():
    """Factory fixture for creating custom onboarding configurations"""

    def _create_config(**kwargs) -> OnboardingConfig:
        return OnboardingConfig(**kwargs)

    return _create_config


@pytest.fixture(scope="function")
def onboarding_flow_factory(test_environment):
    """
    Factory fixture for creating OnboardingFlow instances with custom configuration.

    This fixture provides more control for tests that need to customize the onboarding process.

    Usage:
        def test_custom_onboarding(onboarding_flow_factory):
            config = OnboardingConfig(skip_analytics=False, custom_display_name="CustomUser")
            flow = onboarding_flow_factory(config)
            result = flow.execute_complete_flow()
    """

    def _create_flow(config: OnboardingConfig, driver=None) -> OnboardingFlow:
        if driver is None:
            from core import SessionManager

            session_manager = SessionManager(test_environment)
            driver = session_manager.get_driver()

        logger = get_logger("onboarding_flow_factory")
        return OnboardingFlow(driver, config, logger)

    return _create_flow


# Additional fixtures for better integration with existing patterns


@pytest.fixture(scope="function")
def user_account():
    """
    User account fixture similar to e2e pattern for consistency.

    Creates user account data compatible with existing framework patterns.
    """
    from models.user_model import User, UserProfile
    from datetime import datetime

    # Create consistent user account similar to e2e pattern
    profile = UserProfile(
        display_name=f"E2EUser_{datetime.now().strftime('%H%M%S')}",
        bio="E2E test user created by fixture",
    )

    return User(profile=profile, password=DEFAULT_USER_PASSWORD, environment="e2e_test")


# Seed Phrase Generation Fixtures


@pytest.fixture(scope="function")
def generated_seed_phrase():
    """Generate a random seed phrase for testing.

    Returns:
        A valid BIP39 seed phrase (12, 18, or 24 words).
    """
    return generate_seed_phrase()


@pytest.fixture(scope="function")
def generated_12_word_seed_phrase():
    """Generate a 12-word seed phrase for testing.

    Returns:
        A valid 12-word BIP39 seed phrase.
    """
    return generate_seed_phrase(12)


@pytest.fixture(scope="function")
def generated_24_word_seed_phrase():
    """Generate a 24-word seed phrase for testing.

    Returns:
        A valid 24-word BIP39 seed phrase.
    """
    return generate_seed_phrase(24)


@pytest.fixture(scope="function")
def onboarding_config_with_seed_phrase(generated_seed_phrase):
    """Create onboarding config that uses a generated seed phrase.

    Args:
        generated_seed_phrase: Automatically injected seed phrase fixture.

    Returns:
        OnboardingConfig configured for seed phrase import.
    """
    return OnboardingConfig(
        use_seed_phrase=True,
        seed_phrase=generated_seed_phrase,
        seed_phrase_autocomplete=False,
        validate_each_step=True,
        take_screenshots=False,
    )
