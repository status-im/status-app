import time
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, Dict, Any

from pages.onboarding import (
    WelcomePage,
    AnalyticsPage,
    CreateProfilePage,
    SeedPhraseInputPage,
    PasswordPage,
    SplashScreen,
)
from models.user_model import User, UserProfile
from utils.generators import generate_seed_phrase
from utils.exceptions import ProfileCreationFlowError
from core.models import DEFAULT_USER_PASSWORD


@dataclass
class ProfileCreationConfig:
    """Configuration for onboarding flow execution."""

    use_seed_phrase: bool = False
    seed_phrase: Optional[str] = None
    password: str = DEFAULT_USER_PASSWORD
    display_name: str = "AutoTestUser"
    skip_analytics: bool = True
    validate_each_step: bool = True
    take_screenshots: bool = False
    timeout_seconds: int = 60


class ProfileCreationFlow:
    """
    Manages the complete onboarding flow execution.

    This class orchestrates all onboarding steps and provides detailed
    execution results for analysis and debugging.
    """

    def __init__(self, driver, config: ProfileCreationConfig, logger):
        self.driver = driver
        self.config = config
        self.logger = logger
        self.start_time = datetime.now()
        self.current_step = None
        self.step_results = {}
        self.test_user = None

        # Initialize page objects
        self.welcome_page = WelcomePage(driver)
        self.analytics_page = AnalyticsPage(driver)
        self.create_profile_page = CreateProfilePage(driver)
        self.seed_phrase_page = SeedPhraseInputPage(driver)
        self.password_page = PasswordPage(driver)
        self.splash_screen = SplashScreen(driver)

    def execute_complete_flow(self) -> Dict[str, Any]:
        """
        Execute the complete onboarding flow.

        Returns:
            Dict with execution results including success status, user data,
            timing information, and step-by-step results.
        """
        try:
            self.logger.info("🚀 Starting complete onboarding flow execution")

            self._execute_welcome_step()
            self._execute_analytics_step(skip=self.config.skip_analytics)

            if self.config.use_seed_phrase:
                self._execute_seed_phrase_step()
            else:
                self._execute_create_profile_step()

            self._execute_password_step()
            self._execute_loading_step()

            return self._build_success_result()

        except Exception as e:
            self.logger.error(
                f"❌ Onboarding flow failed at step '{self.current_step}': {e}"
            )
            return self._build_error_result(e)

    def _execute_welcome_step(self):
        self.current_step = "welcome_screen"
        start_time = datetime.now()

        # Initial tap to dismiss any overlay and activate the app
        try:
            self.driver.tap([(500, 300)])
            time.sleep(1)
        except Exception:
            self.logger.debug("Initial tap attempt skipped")

        if not self.welcome_page.is_screen_displayed(timeout=30):
            raise ProfileCreationFlowError("Welcome screen should be displayed")

        if not self.welcome_page.click_create_profile():
            raise ProfileCreationFlowError("Failed to click Create Profile button")

        self.step_results[self.current_step] = {
            "success": True,
            "duration_seconds": (datetime.now() - start_time).total_seconds(),
        }
        self.logger.debug("✓ Welcome screen step completed")

    def _execute_analytics_step(self, skip: bool = True):
        self.current_step = "analytics_screen"
        start_time = datetime.now()

        if self.analytics_page.is_screen_displayed(timeout=10):
            self.logger.debug("📊 Analytics screen displayed")

            if skip:
                if not self.analytics_page.skip_analytics_sharing():
                    raise ProfileCreationFlowError("Failed to skip analytics")
                action = "skipped"
            else:
                if not self.analytics_page.enable_analytics_sharing():
                    raise ProfileCreationFlowError("Failed to enable analytics")
                action = "enabled"

            self.step_results[self.current_step] = {
                "success": True,
                "action": action,
                "duration_seconds": (datetime.now() - start_time).total_seconds(),
            }
            self.logger.debug(f"✓ Analytics screen {action}")
        else:
            self.logger.debug("📊 No analytics screen found - continuing")
            self.step_results[self.current_step] = {
                "success": True,
                "action": "not_displayed",
                "duration_seconds": (datetime.now() - start_time).total_seconds(),
            }

    def _execute_create_profile_step(self):
        self.current_step = "create_profile_screen"
        start_time = datetime.now()

        if not self.create_profile_page.is_screen_displayed():
            raise ProfileCreationFlowError("Create profile screen should be displayed")

        # Generate user for this session
        profile = UserProfile(display_name=self.config.display_name)
        self.test_user = User(profile=profile, password=self.config.password)

        # Click "Let's go!" to start new profile creation
        if not self.create_profile_page.click_lets_go():
            raise ProfileCreationFlowError("Failed to click Let's go button")

        self.step_results[self.current_step] = {
            "success": True,
            "display_name": self.test_user.profile.display_name,
            "duration_seconds": (datetime.now() - start_time).total_seconds(),
        }
        self.logger.debug("✓ Create profile step completed")

    def _execute_seed_phrase_step(self):
        """Execute seed phrase input step."""
        self.current_step = "seed_phrase_screen"
        start_time = datetime.now()

        if not self.seed_phrase_page.is_screen_displayed():
            raise ProfileCreationFlowError("Seed phrase screen should be displayed")

        # Use provided seed phrase or generate one
        seed_phrase = self.config.seed_phrase or generate_seed_phrase()

        # Generate user for this session
        profile = UserProfile(display_name=self.config.display_name)
        self.test_user = User(
            profile=profile,
            password=self.config.password,
            recovery_phrase=seed_phrase,
        )

        if not self.seed_phrase_page.import_seed_phrase(seed_phrase):
            raise ProfileCreationFlowError("Failed to import seed phrase")

        self.step_results[self.current_step] = {
            "success": True,
            "seed_phrase_length": len(seed_phrase.split()),
            "duration_seconds": (datetime.now() - start_time).total_seconds(),
        }
        self.logger.debug("✓ Seed phrase step completed")

    def _execute_password_step(self):
        """Execute password creation step."""
        self.current_step = "password_screen"
        start_time = datetime.now()

        if not self.password_page.is_screen_displayed():
            raise ProfileCreationFlowError("Password screen should be displayed")

        if not self.password_page.create_password(self.config.password):
            raise ProfileCreationFlowError("Failed to create password")

        self.step_results[self.current_step] = {
            "success": True,
            "duration_seconds": (datetime.now() - start_time).total_seconds(),
        }
        self.logger.debug("✓ Password creation step completed")

    def _execute_loading_step(self):
        """Execute app loading step."""
        self.current_step = "app_loading"
        start_time = datetime.now()

        if not self.splash_screen.wait_for_loading_completion():
            raise ProfileCreationFlowError("App loading failed or timed out")

        self.step_results[self.current_step] = {
            "success": True,
            "duration_seconds": (datetime.now() - start_time).total_seconds(),
        }
        self.logger.debug("✓ App loading completed")

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
