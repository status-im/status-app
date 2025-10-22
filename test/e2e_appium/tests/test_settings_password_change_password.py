import pytest

from constants import AppSections
from locators.onboarding.wallet.wallet_locators import WalletLocators
from tests.base_test import BaseAppReadyTest, cloud_reporting
from utils.generators import generate_secure_password


class TestSettingsPasswordChange(BaseAppReadyTest):
    @pytest.mark.critical
    @pytest.mark.smoke
    @cloud_reporting
    def test_change_password_and_login(self):
        assert self.ctx.app.click_settings_left_nav(), "Failed to open Settings"
        assert self.ctx.settings.is_loaded(), "Settings not detected"

        password_settings = self.ctx.settings.open_password_settings()
        assert password_settings, "Password settings not available"

        current_user = self.ctx.user_service.current_user
        assert current_user, "No active user in context"
        old_password = current_user.password

        while (new_password := generate_secure_password()) == old_password:
            pass

        modal = password_settings.change_password(old_password, new_password)
        assert modal and modal.is_displayed(), "Change password modal did not appear"
        assert modal.complete_reencrypt_and_restart(), (
            "Failed to complete password re-encryption flow"
        )

        current_user.password = new_password

        self.ctx.app_state_manager.detect_current_state()
        assert self.ctx.welcome_back.perform_login(new_password), (
            "Unable to authenticate after restart with the new password"
        )

        locators = WalletLocators()
        assert self.ctx.app.is_element_visible(
            locators.WALLET_FOOTER_SEND_BUTTON, timeout=15
        ), "Wallet landing screen should be visible after login"

        assert self.ctx.app.active_section() == AppSections.WALLET, (
            "Wallet section should be active after navigation"
        )
