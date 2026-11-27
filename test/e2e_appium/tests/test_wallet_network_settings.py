import pytest

from pages.app import App
from pages.onboarding.welcome_back_page import WelcomeBackPage
from pages.settings.settings_page import SettingsPage
from pages.settings.wallet_settings_page import WalletSettingsPage
from support.multi_device_helpers import StepMixin
from support.platform import is_android


@pytest.mark.wallet
@pytest.mark.e2e
@pytest.mark.portrait
@pytest.mark.device_count(1)
class TestWalletNetworkSettings(StepMixin):
    def open_wallet_networks(self, app: App) -> WalletSettingsPage:
        assert app.click_settings_button(), "Failed to open Settings"
        settings = SettingsPage(self.driver)
        assert settings.is_loaded(), "Settings did not load"
        wallet = settings.open_wallet_settings()
        assert wallet is not None, "Wallet settings did not load"
        assert wallet.open_networks(), "Networks view did not load"
        assert wallet.select_mainnet_tab(), "Mainnet tab was not selected"
        return wallet

    async def test_network_switches_persist_after_restart(self):
        if not is_android(self.driver):
            pytest.skip("Reads the Android accessibility tree")

        app = App(self.driver)

        async with self.step(self.device, "Read the mainnet switches"):
            wallet = self.open_wallet_networks(app)
            expected = wallet.get_network_states()
            assert len(expected) >= 14, f"Incomplete mainnet list: {list(expected)}"

        async with self.step(self.device, "Enable at least seven mainnets"):
            enabled_count = sum(expected.values())
            target = max(7, enabled_count + 1)
            assert len(expected) >= target, f"Not enough mainnets to enable {target}: {expected}"
            disabled = [name for name, enabled in expected.items() if not enabled]
            to_enable = disabled[: target - enabled_count]
            for name in to_enable:
                assert wallet.set_network_enabled(name, True), f"{name} did not turn on"
                expected[name] = True
            assert wallet.get_network_states() == expected

        name = to_enable[-1]
        async with self.step(self.device, f"Turn off {name} without confirming"):
            turned_off = wallet.set_network_enabled(name, False)
            assert not wallet.is_deactivate_network_confirmation_visible(name), (
                f"A confirmation appeared when disabling {name}"
            )
            assert turned_off, f"{name} did not turn off directly"
            expected[name] = False

        async with self.step(self.device, "Cold-restart Status and unlock the wallet"):
            lifecycle = app.app_lifecycle
            assert lifecycle.terminate_app(), "Failed to stop Status"
            assert lifecycle.wait_for_app_not_running(), "Status was still running before relaunch"
            assert lifecycle.activate_app_with_ui_ready(), "Failed to relaunch Status"
            welcome_back = WelcomeBackPage(self.driver)
            assert welcome_back.perform_login(self.device.user.password), (
                "Failed to log in after restart"
            )

        async with self.step(self.device, "Verify every mainnet kept its switch state"):
            wallet = self.open_wallet_networks(app)
            assert wallet.get_network_states() == expected
