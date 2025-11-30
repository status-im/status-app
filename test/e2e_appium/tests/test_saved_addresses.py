import pytest

from utils.generators import generate_ethereum_address, generate_account_name
from utils.multi_device_helpers import StepMixin
from pages.wallet.add_saved_address_modal import AddSavedAddressModal
from pages.app import App
from locators.app_locators import AppLocators
from locators.wallet.saved_addresses_locators import SavedAddressesLocators
from pages.wallet.saved_addresses_page import SavedAddressesPage


class TestSavedAddresses(StepMixin):
    @pytest.mark.wallet
    @pytest.mark.saved_addresses
    @pytest.mark.smoke
    async def test_add_and_remove_saved_address(self):
        async with self.step(self.device, "Navigate to Saved Addresses"):
            app = App(self.device.driver)
            assert app.safe_click(AppLocators().LEFT_NAV_WALLET, timeout=6), (
                "Failed to open Wallet"
            )
            loc = SavedAddressesLocators()
            assert app.safe_click(loc.WALLET_SAVED_ADDRESSES_BUTTON), (
                "Failed to open Saved addresses from Wallet"
            )
            saved_addresses = SavedAddressesPage(self.device.driver)
            assert saved_addresses.is_loaded(timeout=10), "Saved Addresses view not opened"

        async with self.step(self.device, "Add saved address"):
            assert saved_addresses.open_add_saved_address_modal(), (
                "Add Saved Address modal button not clickable"
            )
            modal = AddSavedAddressModal(self.device.driver)

            name = generate_account_name(12)
            address = generate_ethereum_address()
            assert modal.add_saved_address(name, address), "Failed to add saved address"

        async with self.step(self.device, "Verify address added"):
            toast = app.wait_for_toast(
                expected_substring="successfully added",
                timeout=8,
                stability=0.2,
            )
            assert toast, "Expected toast after saving address"
            assert "successfully added" in toast.lower(), (
                f"Unexpected toast: '{toast}'"
            )
            assert saved_addresses.is_entry_visible(name, timeout=30), (
                f"Saved address '{name}' not visible in list"
            )

        async with self.step(self.device, "Delete saved address"):
            assert saved_addresses.delete_saved_address_with_confirmation(name), (
                "Failed to delete saved address via details menu"
            )

        async with self.step(self.device, "Verify address deleted"):
            app.wait_for_toast(
                expected_substring="removed",
                timeout=8,
                stability=0.2,
            )
            assert not saved_addresses.is_entry_visible(name, timeout=10), (
                f"Saved address '{name}' still visible after deletion"
            )
