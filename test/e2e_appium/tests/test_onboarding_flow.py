"""
Status Desktop E2E Onboarding Flow Tests

This module contains tests for the complete onboarding flow, including both
fixture-based tests and component validation tests.
"""

import pytest
from tests.base_test import BaseTest, cloud_reporting


class TestOnboardingFlow(BaseTest):
    """Test class for onboarding flow functionality"""

    @pytest.mark.smoke
    @pytest.mark.onboarding
    @pytest.mark.e2e
    @cloud_reporting
    @pytest.mark.onboarding_config(
        custom_display_name="E2E_TestUser",
        skip_analytics=True,
        validate_each_step=True,
        take_screenshots=False,
    )
    def test_onboarding_new_password_skip_analytics(self, onboarded_user):
        """
        Test the onboarding flow using the onboarding fixture.

        """

        result = onboarded_user

        # Validate results
        assert result["success"], "Onboarding flow should complete successfully"
        assert "user_data" in result, "Result should contain user data"
        assert result["user_data"]["display_name"] == "E2E_TestUser", (
            "Should use custom display name"
        )

        # Validate all expected steps were completed
        expected_steps = [
            "welcome_screen",
            "analytics_screen",
            "password_screen",
            "loading_screen",
            "wallet_verification",
        ]
        completed_steps = result["steps_completed"]

        for step in expected_steps:
            assert step in completed_steps, f"Step '{step}' should be completed"
        # Validate analytics action matches config
        assert result["step_results"]["analytics_screen"]["action"] == "skipped"

        self.logger.info("Complete onboarding flow test with fixture passed!")

    @pytest.mark.onboarding
    @cloud_reporting
    @pytest.mark.onboarding_config(custom_display_name="E2E_TestUser")
    def test_onboarding_lands_on_main_app(self, onboarded_app):
        app = onboarded_app
        assert app.is_main_app_loaded()
        assert app.user_data["display_name"] == "E2E_TestUser"
