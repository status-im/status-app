"""Test wallet account management through Settings → Wallet → Account Details.

This test ports the desktop test that manages wallet accounts through the Settings
path rather than the wallet left panel context menu.

Reference: test/e2e/tests/crtitical_tests_prs/test_add_delete_account_from_settings.py
"""

import pytest

from pages.app import App
from pages.settings.settings_page import SettingsPage
from pages.wallet.account_details_page import AccountDetailsPage
from pages.wallet.wallet_left_panel import WalletLeftPanel
from utils.generators import generate_account_name
from utils.multi_device_helpers import StepMixin


# Expected values matching desktop test constants (test/e2e/constants/wallet.py)
EXPECTED_ORIGIN = "Derived from your default Status key pair"
EXPECTED_DERIVATION_PATH = "m / 44' / 60' / 0' / 0 / 1"
EXPECTED_STORAGE = "On device"


class TestWalletAccountFromSettings(StepMixin):
    """Test wallet account management via Settings → Wallet flow."""

    UI_TIMEOUT = 12

    @pytest.mark.wallet
    @pytest.mark.critical
    @pytest.mark.smoke
    async def test_add_view_delete_account_from_settings(self):
        """Add account via settings, verify details, then delete.
        
        Test flow:
        1. Navigate to Settings → Wallet
        2. Add new account with generated name
        3. Authenticate with password
        4. Open account details view
        5. Verify account info (name, address, origin, derivation path, storage)
        6. Delete account from details view
        7. Authenticate deletion
        8. Verify toast message
        9. Verify account removed from wallet
        """
        app = App(self.device.driver)
        user_password = self.device.user.password
        account_name = generate_account_name(15)

        async with self.step(self.device, "Navigate to Settings"):
            assert app.click_settings_button(), "Failed to open settings"
            settings_page = SettingsPage(self.device.driver)
            assert settings_page.is_loaded(timeout=self.UI_TIMEOUT), (
                "Settings page did not load"
            )

        async with self.step(self.device, "Open Wallet settings"):
            wallet_settings = settings_page.open_wallet_settings(timeout=self.UI_TIMEOUT)
            assert wallet_settings is not None, "Failed to open wallet settings"
            assert wallet_settings.is_loaded(timeout=self.UI_TIMEOUT), (
                "Wallet settings view did not load"
            )

        async with self.step(self.device, "Add new account from wallet settings"):
            assert wallet_settings.add_account(
                name=account_name,
                auth_password=user_password,
                timeout=self.UI_TIMEOUT,
            ), f"Failed to add account '{account_name}'"

        async with self.step(self.device, "Verify account added toast"):
            toast = app.wait_for_toast(
                expected_substring="successfully added",
                timeout=10,
                stability=0.2,
            )
            if toast:
                assert "successfully added" in toast.lower(), (
                    f"Expected success toast. Got: '{toast}'"
                )
            else:
                self.device.logger.warning(
                    "No toast detected after adding account '%s'", account_name
                )

        async with self.step(self.device, "Verify account appears in settings list"):
            # The account list may need scrolling to find newly added accounts
            assert wallet_settings.account_exists(account_name, timeout=15), (
                f"Account '{account_name}' not found in wallet settings after creation"
            )

        async with self.step(self.device, "Open account details view"):
            assert wallet_settings.select_account_by_name(
                account_name, timeout=self.UI_TIMEOUT
            ), f"Failed to select account '{account_name}'"

            account_details = AccountDetailsPage(self.device.driver)
            assert account_details.is_loaded(timeout=self.UI_TIMEOUT), (
                "Account details view did not load"
            )

        async with self.step(self.device, "Verify account name in details"):
            displayed_name = account_details.get_account_name(timeout=self.UI_TIMEOUT)
            assert displayed_name is not None, "Account name not found in details view"
            assert displayed_name == account_name, (
                f"Account name mismatch. Expected '{account_name}', got '{displayed_name}'"
            )
            self.device.logger.info(f"Account name verified: {displayed_name}")

        async with self.step(self.device, "Verify account address exists"):
            address = account_details.get_account_address(timeout=self.UI_TIMEOUT)
            assert address is not None, "Account address not found in details view"
            assert address.startswith("0x"), (
                f"Account address should start with '0x', got: {address}"
            )
            self.device.logger.info(f"Account address: {address}")

        async with self.step(self.device, "Verify account origin"):
            origin = account_details.get_origin_value(timeout=self.UI_TIMEOUT)
            assert origin is not None, "Account origin not found in details view"
            assert origin == EXPECTED_ORIGIN, (
                f"Account origin mismatch. Expected '{EXPECTED_ORIGIN}', got: '{origin}'"
            )
            self.device.logger.info(f"Account origin verified: {origin}")

        async with self.step(self.device, "Verify derivation path"):
            derivation_path = account_details.get_derivation_path(timeout=self.UI_TIMEOUT)
            assert derivation_path is not None, (
                "Derivation path not found in details view"
            )
            assert derivation_path == EXPECTED_DERIVATION_PATH, (
                f"Derivation path mismatch. Expected '{EXPECTED_DERIVATION_PATH}', "
                f"got: '{derivation_path}'"
            )
            self.device.logger.info(f"Derivation path verified: {derivation_path}")

        async with self.step(self.device, "Verify storage location"):
            storage = account_details.get_storage_value(timeout=self.UI_TIMEOUT)
            assert storage is not None, "Storage value not found in details view"
            assert storage == EXPECTED_STORAGE, (
                f"Storage value mismatch. Expected '{EXPECTED_STORAGE}', got: '{storage}'"
            )
            self.device.logger.info(f"Storage location verified: {storage}")

        async with self.step(self.device, "Delete account from details view"):
            assert account_details.delete_account(
                auth_password=user_password, timeout=self.UI_TIMEOUT
            ), f"Failed to delete account '{account_name}'"

        async with self.step(self.device, "Verify deletion toast"):
            # Desktop test expects: f'"{account_name}" successfully removed'
            expected_toast = f'"{account_name}" successfully removed'
            toast = app.wait_for_toast(
                expected_substring="successfully removed",
                timeout=10,
                stability=0.2,
            )
            assert toast is not None, "Expected toast after removing account"
            assert expected_toast in toast, (
                f"Toast message mismatch. Expected '{expected_toast}' in toast. "
                f"Got: '{toast}'"
            )

        async with self.step(self.device, "Verify account removed from wallet"):
            # Navigate to wallet to verify account is gone
            assert app.click_wallet_button(), "Failed to navigate to wallet"
            wallet_panel = WalletLeftPanel(self.device.driver)
            assert wallet_panel.is_loaded(timeout=self.UI_TIMEOUT), (
                "Wallet panel did not load"
            )

            # Verify account no longer exists
            account_element = wallet_panel.find_account_element_by_name(
                account_name, timeout=5
            )
            assert account_element is None, (
                f"Account '{account_name}' still visible in wallet after deletion"
            )
            self.device.logger.info(
                f"Verified account '{account_name}' removed from wallet"
            )
