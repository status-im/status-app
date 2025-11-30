import pytest

from constants import AppSections
from locators.onboarding.wallet.wallet_locators import WalletLocators
from pages.app import App
from pages.settings.settings_page import SettingsPage
from pages.onboarding.welcome_back_page import WelcomeBackPage
from utils.generators import generate_secure_password
from utils.multi_device_helpers import StepMixin


class TestSettingsPasswordChange(StepMixin):
    @pytest.mark.critical
    @pytest.mark.smoke
    async def test_change_password_and_login(self):
        async with self.step(self.device, "Navigate to Settings"):
            app = App(self.device.driver)
            assert app.click_settings_left_nav(), "Failed to open Settings"
            settings = SettingsPage(self.device.driver)
            assert settings.is_loaded(), "Settings not detected"

        async with self.step(self.device, "Open password settings"):
            password_settings = settings.open_password_settings()
            assert password_settings, "Password settings not available"

        async with self.step(self.device, "Change password"):
            old_password = self.device.user.password
            while (new_password := generate_secure_password()) == old_password:
                pass

            modal = password_settings.change_password(old_password, new_password)
            assert modal and modal.is_displayed(), "Change password modal did not appear"

            # Update user password for re-login
            self.device.user.password = new_password

            assert modal.complete_reencrypt_and_restart(new_password, self.device.user), (
                "Failed to complete password re-encryption flow"
            )

        async with self.step(self.device, "Login with new password"):
            welcome_back = WelcomeBackPage(self.device.driver)
            assert welcome_back.perform_login(self.device.user.password), (
                "Unable to authenticate after restart with the new password"
            )

        async with self.step(self.device, "Verify wallet visible"):
            locators = WalletLocators()
            assert app.is_element_visible(
                locators.WALLET_FOOTER_SEND_BUTTON, timeout=15
            ), "Wallet landing screen should be visible after login"

            assert app.active_section() == AppSections.WALLET, (
                "Wallet section should be active after navigation"
            )
