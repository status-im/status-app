import time
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
        except Exception as e:
            self.logger.debug(f"open_details failed for '{name}': {e}")
            return False

    def open_row_menu(self, name: str) -> bool:
        try:
            if self.safe_click(
                self.locators.row_menu_by_name(name), timeout=5, max_attempts=3
            ):
                return True
        except Exception:
            self.logger.debug("Direct kebab tap failed for '%s'; falling back", name)

        delegate = self.find_element_safe(self.locators.row_by_name(name), timeout=4)
        if not delegate:
            return False

        try:
            delegate.click()
        except Exception as e:
            self.logger.debug(f"open_row_menu delegate click failed for '{name}': {e}")
            return False

        if not self.is_element_visible(
            self.locators.SAVED_ADDRESS_DETAILS_POPUP, timeout=4
        ):
            return False

        header = self.find_element_safe(
            self.locators.popup_header_by_name(name), timeout=3
        )
        if header:
            try:
                header.click()
                time.sleep(0.2)
            except Exception:
                self.logger.debug("Popup header tap failed for '%s'", name)

        for locator in (
            self.locators.row_menu_by_name(name),
            self.locators.POPUP_MENU_BUTTON_GENERIC,
        ):
            try:
                if self.safe_click(locator, timeout=4, max_attempts=2):
                    return True
            except Exception:
                self.logger.debug("Popup kebab tap failed for '%s' using %s", name, locator)
                continue

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
