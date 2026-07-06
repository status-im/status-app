import os
import time

import pytest

from utils.timeouts import ONBOARDING_SCREEN_TRANSITION_TIMEOUT_SECONDS
from pages.onboarding import (
    WelcomePage,
    CreateProfilePage,
    SeedPhraseInputPage,
    PasswordPage,
    SplashScreen,
)
from pages.onboarding.biometrics_page import BiometricsPage
from pages.onboarding.push_notifications_page import PushNotificationsPage
from locators.base_locators import BaseLocators
from pages.app import App
from pages.base_page import BasePage
from pages.settings.settings_page import SettingsPage
from pages.wallet.wallet_left_panel import WalletLeftPanel
from utils.generators import get_wallet_address_from_mnemonic
from utils.gestures import Gestures
from utils.multi_device_helpers import StepMixin

SEED_ENV_VAR = "WALLET_TEST_USER_SEED"
FUNDED_WALLET_ADDRESS = "0x81e5872aC91b2D8C770d997fF1524A3Cb28fe3A0"
SEND_AMOUNT = "0.001"
TESTNET_NETWORK_NAME = "Hoodi"


def elide_address(address: str) -> str:
    """Mirror StatusQUtils.elideText(address, 6, 4) used by the sign screen."""
    return address[:6] + "…" + address[-4:]


@pytest.mark.flaky(reruns=1, reruns_delay=5)
class TestWalletSendSmoke(StepMixin):
    async def _onboard_with_seed(
        self, driver, seed_phrase: str, password: str,
    ) -> None:
        """Onboard via seed-phrase import (same flow as the import-seed test)."""
        async with self.step(self.device, "Complete welcome screen"):
            try:
                Gestures(driver).activation_tap()
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
            assert create.is_screen_displayed(
                timeout=ONBOARDING_SCREEN_TRANSITION_TIMEOUT_SECONDS,
            ), "Create profile screen should be visible"
            assert create.click_use_recovery_phrase(), (
                "Failed to click Use a recovery phrase"
            )

        async with self.step(self.device, "Import seed phrase"):
            seed_page = SeedPhraseInputPage(driver, flow_type="create")
            assert seed_page.is_screen_displayed(
                timeout=ONBOARDING_SCREEN_TRANSITION_TIMEOUT_SECONDS,
            ), "Seed phrase input (create) should be visible"
            assert seed_page.import_seed_phrase(seed_phrase), "Failed to import seed phrase"

        async with self.step(self.device, "Create password"):
            password_page = PasswordPage(driver)
            assert password_page.is_screen_displayed(
                timeout=ONBOARDING_SCREEN_TRANSITION_TIMEOUT_SECONDS,
            ), "Password screen should be visible"
            assert password_page.create_password(password), "Failed to create password"

        async with self.step(self.device, "Dismiss biometrics prompt if present"):
            biometrics = BiometricsPage(driver)
            if biometrics.is_screen_displayed(timeout=10):
                assert biometrics.select_maybe_later(), "Failed to dismiss biometrics"

        async with self.step(self.device, "Wait for app loading"):
            splash = SplashScreen(driver)
            assert splash.wait_for_loading_completion(), (
                "App did not finish loading"
            )

        async with self.step(self.device, "Dismiss post-onboarding overlays"):
            PushNotificationsPage(driver).dismiss_if_present(timeout=15)
            nav_edu = ("xpath",
                "//*[contains(@resource-id,'NavigationEducationDialog')]"
                "//*[contains(@resource-id,'headerActionsCloseButton')]")
            base_for_edu = BasePage(driver)
            if base_for_edu.is_element_visible(nav_edu, timeout=5):
                base_for_edu.safe_click(nav_edu, timeout=5)
            PushNotificationsPage(driver).dismiss_if_present(timeout=5)

    @pytest.mark.smoke
    @pytest.mark.wallet
    @pytest.mark.raw_devices
    @pytest.mark.timeout(900)
    async def test_send_eth_review_matches_input(self):
        """Send-flow smoke: reviewed amount/recipient/network match the input.

        Onboards the funded test profile, enables testnet mode, builds a
        0.001 ETH send to the profile's own address, and asserts the sign
        screen shows the entered amount, network and recipient. Stops at the
        sign screen — nothing is signed or broadcast.
        """
        seed_phrase = os.getenv(SEED_ENV_VAR, "").strip()
        if not seed_phrase:
            pytest.skip(
                f"{SEED_ENV_VAR} not set — requires the seed phrase of the "
                f"funded test profile ({FUNDED_WALLET_ADDRESS})"
            )

        derived_address = get_wallet_address_from_mnemonic(seed_phrase)
        assert derived_address.lower() == FUNDED_WALLET_ADDRESS.lower(), (
            f"{SEED_ENV_VAR} derives '{derived_address}', expected the funded "
            f"test address '{FUNDED_WALLET_ADDRESS}'"
        )

        driver = self.device.driver
        await self._onboard_with_seed(driver, seed_phrase, "TestPassword123!")

        app = App(driver)

        async with self.step(self.device, "Enable testnet mode"):
            assert app.click_settings_button(), "Failed to navigate to Settings"
            settings = SettingsPage(driver)
            assert settings.is_loaded(timeout=10), "Settings page not loaded"
            wallet_settings = settings.open_wallet_settings()
            assert wallet_settings is not None, "Failed to open Settings → Wallet"
            assert wallet_settings.open_networks(), (
                "Failed to open Networks in wallet settings"
            )
            assert wallet_settings.enable_testnet_mode(), (
                "Failed to enable testnet mode"
            )

        async with self.step(self.device, "Leave settings"):
            # Unwind Networks → Wallet → Settings root before opening the
            # drawer: click_wallet_button can early-exit on a stale tree
            # read straight out of a settings sub-view.
            base = BasePage(driver)
            back_button = BaseLocators.tid("toolBarBackButton")
            for _ in range(4):
                if not base.is_element_visible(back_button, timeout=2):
                    break
                try:
                    base.safe_click(back_button, timeout=3, max_attempts=1)
                except Exception:
                    break
                time.sleep(0.3)

        async with self.step(self.device, "Navigate to wallet account"):
            assert app.click_wallet_button(), "Failed to navigate to Wallet"
            panel = WalletLeftPanel(driver)
            assert panel.is_loaded(timeout=20), "Wallet left panel not visible"
            assert panel.wait_for_painted(
                panel.locators.ADD_ACCOUNT_BUTTON, timeout=15
            ) is not None, (
                "Wallet panel landmark present but never painted (zero bounds) "
                "— navigation likely landed on another section"
            )
            assert panel.click_account_row(0), (
                "First account row not clickable (missing or unpainted)"
            )

        async with self.step(self.device, "Open send modal"):
            PushNotificationsPage(driver).dismiss_if_present(timeout=3)
            send_modal = panel.open_send_modal()
            assert send_modal is not None, "Send modal did not open from wallet footer"

        async with self.step(self.device, "Enter recipient address"):
            assert send_modal.enter_recipient(FUNDED_WALLET_ADDRESS), (
                "Failed to enter recipient address"
            )

        async with self.step(self.device, "Select ETH"):
            assert send_modal.ensure_eth_selected(), (
                "Failed to select ETH in token picker"
            )

        async with self.step(self.device, "Enter amount"):
            assert send_modal.enter_amount(SEND_AMOUNT), "Failed to enter send amount"

        async with self.step(self.device, "Wait for route and review"):
            assert send_modal.wait_for_route_ready(timeout=60), (
                "Review Send did not become enabled — no route/fee estimate"
            )
            sign_modal = send_modal.click_review_send()
            assert sign_modal is not None, "Sign modal did not appear after Review Send"

        async with self.step(self.device, "Verify reviewed values match input"):
            asset_value = sign_modal.asset_value()
            assert asset_value and f"{SEND_AMOUNT} ETH" in asset_value, (
                f"Sign screen asset should show '{SEND_AMOUNT} ETH', got: '{asset_value}'"
            )

            network_value = sign_modal.network_value()
            assert network_value and TESTNET_NETWORK_NAME in network_value, (
                f"Sign screen network should show '{TESTNET_NETWORK_NAME}', "
                f"got: '{network_value}'"
            )

            recipient_value = sign_modal.recipient_value()
            expected_elided = elide_address(FUNDED_WALLET_ADDRESS)
            normalized = (recipient_value or "").replace("×", "x").lower()
            assert expected_elided.lower() in normalized, (
                f"Sign screen recipient should show '{expected_elided}', "
                f"got: '{recipient_value}'"
            )

        async with self.step(self.device, "Close sign modal without signing"):
            assert sign_modal.close_without_signing(), "Failed to close sign modal"
