from typing import Optional

from ..base_page import BasePage
from locators.wallet.saved_addresses_locators import SavedAddressesLocators


class SavedAddressesPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = SavedAddressesLocators()

    def is_loaded(self, timeout: Optional[int] = 10) -> bool:
        return bool(
            self.is_element_visible(
                self.locators.ADD_NEW_SAVED_ADDRESS_BUTTON_WALLET, timeout=timeout
            )
            or self.is_element_visible(
                self.locators.ADD_NEW_SAVED_ADDRESS_BUTTON_SETTINGS, timeout=timeout
            )
        )

    def open_add_saved_address_modal(self) -> bool:
        if self.safe_click(
            self.locators.ADD_NEW_SAVED_ADDRESS_BUTTON_WALLET, timeout=4
        ):
            return True
        return self.safe_click(self.locators.ADD_NEW_SAVED_ADDRESS_BUTTON_SETTINGS)

    def is_entry_visible(self, name: str, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(self.locators.row_by_name(name), timeout=timeout)

    def open_details(self, name: str) -> bool:
        try:
            row = self.find_element(self.locators.row_by_name(name), timeout=6)
            row.click()
            return self.is_element_visible(
                self.locators.SAVED_ADDRESS_DETAILS_POPUP, timeout=6
            )
        except Exception:
            return False

    def open_row_menu(self, name: str) -> bool:
        # If details popup is already visible, do NOT click the row again (it can close the popup).
        if self.is_element_visible(
            self.locators.SAVED_ADDRESS_DETAILS_POPUP, timeout=2
        ):
            self.logger.debug(
                "Details popup already visible. Dumping XML (pre-kebab-click)..."
            )
            self.dump_page_source(f"details_popup_open_{name}")
        else:
            # Open details popup by clicking the row once
            try:
                delegate = self.find_element(self.locators.row_by_name(name), timeout=4)
                delegate.click()
            except Exception:
                return False
            if not self.is_element_visible(
                self.locators.SAVED_ADDRESS_DETAILS_POPUP, timeout=5
            ):
                return False
            self.logger.debug(
                "SavedAddress details popup is visible. Dumping XML (pre-kebab-click)..."
            )
            self.dump_page_source(f"details_popup_open_{name}")

        try:
            if self.safe_click(
                self.locators.popup_menu_by_name(name), timeout=4, max_attempts=1
            ):
                self.logger.debug(
                    "Clicked popup kebab via name-specific locator. Dumping XML..."
                )
                self.dump_page_source(f"kebab_clicked_name_{name}")
                return True
        except Exception:
            return False

        return False

    def delete_saved_address_with_confirmation(self, name: str) -> bool:
        if not self.open_row_menu(name):
            return False
        if not self.is_element_visible(
            self.locators.DELETE_SAVED_ADDRESS_ACTION, timeout=4
        ):
            return False
        if not self.safe_click(self.locators.DELETE_SAVED_ADDRESS_ACTION):
            return False
        if not self.safe_click(self.locators.CONFIRM_DELETE_BUTTON):
            return False
        self.wait_for_invisibility(self.locators.CONFIRM_DELETE_BUTTON, timeout=6)
        self.wait_for_invisibility(self.locators.SAVED_ADDRESS_DETAILS_POPUP, timeout=8)
        return True
