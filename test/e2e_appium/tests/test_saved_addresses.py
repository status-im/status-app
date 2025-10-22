import pytest

from tests.base_test import BaseAppReadyTest, cloud_reporting
from utils.generators import generate_ethereum_address, generate_account_name
from pages.wallet.add_saved_address_modal import AddSavedAddressModal
from pages.app import App
from locators.app_locators import AppLocators
from locators.wallet.saved_addresses_locators import SavedAddressesLocators
from pages.wallet.saved_addresses_page import SavedAddressesPage


class TestSavedAddresses(BaseAppReadyTest):
    @pytest.mark.wallet
    @pytest.mark.saved_addresses
    @pytest.mark.smoke
    @cloud_reporting
    def test_add_and_remove_saved_address(self):
        assert self.ctx.app.safe_click(AppLocators().LEFT_NAV_WALLET, timeout=6), (
            "Failed to open Wallet"
        )
        loc = SavedAddressesLocators()
        assert self.ctx.app.safe_click(loc.WALLET_SAVED_ADDRESSES_BUTTON), (
            "Failed to open Saved addresses from Wallet"
        )
        saved_addresses = SavedAddressesPage(self.driver)
        assert saved_addresses.is_loaded(timeout=10), "Saved Addresses view not opened"

        assert saved_addresses.open_add_saved_address_modal(), (
            "Add Saved Address modal button not clickable"
        )
        modal = AddSavedAddressModal(self.driver)
        assert modal.is_displayed(timeout=10), "Add Saved Address modal did not appear"

        name = generate_account_name(12)
        address = generate_ethereum_address()
        assert modal.add_saved_address(name, address), "Failed to add saved address"

        app = App(self.driver)
        assert app.is_toast_present(timeout=5), "Expected toast after saving address"
        toast_text = app.get_toast_content_desc(timeout=10) or ""
        assert "successfully added" in toast_text.lower(), (
            f"Unexpected toast: '{toast_text}'"
        )

        assert saved_addresses.is_entry_visible(name, timeout=30), (
            f"Saved address '{name}' not visible in list"
        )

        assert saved_addresses.open_details(name), (
            "Failed to open saved address details"
        )
        assert saved_addresses.delete_saved_address_with_confirmation(name), (
            "Failed to delete saved address via details menu"
        )

        app = App(self.driver)
        _ = app.get_toast_content_desc(timeout=5)
        assert not saved_addresses.is_entry_visible(name, timeout=10), (
            f"Saved address '{name}' still visible after deletion"
        )
