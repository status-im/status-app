import time

import pytest

from pages.onboarding import (
    WelcomePage,
    CreateProfilePage,
    SeedPhraseInputPage,
    PasswordPage,
    SplashScreen,
)
from pages.base_page import BasePage
from pages.app import App
from pages.onboarding.push_notifications_page import PushNotificationsPage
from pages.wallet.wallet_left_panel import WalletLeftPanel
from locators.app_locators import AppLocators
from locators.onboarding.wallet.wallet_locators import WalletLocators
from locators.onboarding.returning_login_locators import ReturningLoginLocators
from utils.generators import generate_seed_phrase, get_wallet_address_from_mnemonic
from utils.multi_device_helpers import StepMixin


class TestOnboardingImportSeed(StepMixin):
    @pytest.mark.gate
    @pytest.mark.smoke
    @pytest.mark.onboarding
    @pytest.mark.raw_devices
    async def test_import_and_reimport_seed(self):
        driver = self.device.driver
        seed_phrase = generate_seed_phrase()
        password = "TestPassword123!"

        async with self.step(self.device, "Complete welcome screen"):
            # Initial tap to dismiss any overlay
            try:
                driver.tap([(500, 300)])
                time.sleep(1)
            except Exception:
                pass

            welcome = WelcomePage(driver)
            assert welcome.is_screen_displayed(timeout=30), (
                "Welcome screen should be visible"
            )
            assert welcome.click_create_profile(), "Failed to click Create profile"

        async with self.step(self.device, "Select recovery phrase import"):
            create = CreateProfilePage(driver)
            assert create.is_screen_displayed(), "Create profile screen should be visible"
            assert create.click_use_recovery_phrase(), (
                "Failed to click Use a recovery phrase"
            )

        async with self.step(self.device, "Import seed phrase"):
            seed_page = SeedPhraseInputPage(driver, flow_type="create")
            assert seed_page.is_screen_displayed(), (
                "Seed phrase input (create) should be visible"
            )
            assert seed_page.import_seed_phrase(seed_phrase), "Failed to import seed phrase"

        async with self.step(self.device, "Create password"):
            password_page = PasswordPage(driver)
            assert password_page.is_screen_displayed(), "Password screen should be visible"
            assert password_page.create_password(password), "Failed to create password"

        async with self.step(self.device, "Wait for app loading"):
            splash = SplashScreen(driver)
            assert splash.wait_for_loading_completion(timeout=60), (
                "App did not finish loading"
            )

        async with self.step(self.device, "Dismiss push notifications if present"):
            PushNotificationsPage(driver).dismiss_if_present(timeout=5)

        async with self.step(self.device, "Verify wallet address"):
            app = App(driver)
            app_locators = AppLocators()
            base = BasePage(driver)

            base.safe_click(app_locators.LEFT_NAV_WALLET, timeout=5)

            # The QML account row has clickable=false in the Android a11y
            # tree, so selecting an individual account is unreliable.
            # Instead, copy the address via context menu (proven reliable)
            # and compare against the expected address from the seed phrase.
            panel = WalletLeftPanel(driver)
            assert panel.is_loaded(timeout=10), "Wallet panel not loaded"

            copied_addr = panel.copy_account_address_via_context_menu(index=0)
            assert copied_addr is not None, "Failed to copy wallet address via context menu"

            full_addr = get_wallet_address_from_mnemonic(seed_phrase)
            assert copied_addr.lower() == full_addr.lower(), (
                f"Wallet address mismatch. Expected '{full_addr}', got '{copied_addr}'"
            )

        async with self.step(self.device, "Restart app"):
            assert base.restart_app(), "Failed to restart app before re-importing seed"

        async with self.step(self.device, "Open user selector"):
            rel = ReturningLoginLocators()

            def nudge_user_selector() -> bool:
                try:
                    driver.tap([(500, 300)])
                    return True
                except Exception:
                    return False

            opened = False
            selector_locators = [rel.LOGIN_USER_SELECTOR_FULL_ID, rel.LOGIN_USER_SELECTOR]

            for _ in range(5):
                nudge_user_selector()
                for locator in selector_locators:
                    el = base.find_element_safe(locator, timeout=3)
                    if el and base.gestures.element_tap(el):
                        opened = True
                        break
                if opened:
                    break
            assert opened, "Returning login user selector did not open"

        async with self.step(self.device, "Select Create profile from dropdown"):
            try:
                base.safe_click(
                    rel.CREATE_PROFILE_DROPDOWN_ITEM, timeout=10, max_attempts=2
                )
            except Exception:
                el = base.find_element_safe(rel.CREATE_PROFILE_DROPDOWN_ITEM, timeout=3)
                assert el is not None, "Create profile item not found in dropdown"
                assert base.gestures.element_tap(el), (
                    "Failed to tap Create profile dropdown item"
                )

        async with self.step(self.device, "Select recovery phrase (re-import)"):
            create = CreateProfilePage(driver)
            assert create.is_screen_displayed(), (
                "Create profile screen should be visible (re-import path)"
            )
            assert create.click_use_recovery_phrase(), (
                "Failed to click Use a recovery phrase (re-import path)"
            )

        async with self.step(self.device, "Verify duplicate seed phrase rejected"):
            seed_login = SeedPhraseInputPage(driver, flow_type="create")
            assert seed_login.is_screen_displayed(), (
                "Seed phrase screen should be visible (re-import path)"
            )
            assert seed_login.paste_seed_phrase_via_clipboard(seed_phrase), (
                "Failed to paste seed phrase (re-import path)"
            )
            assert not seed_login.is_continue_button_enabled(), (
                "Continue should be disabled for already added seed phrase"
            )
