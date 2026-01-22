from typing import Optional

from ..base_page import BasePage
from locators.wallet.saved_addresses_locators import SavedAddressesLocators


class AddSavedAddressModal(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = SavedAddressesLocators()

    def is_displayed(self, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(self.locators.NAME_INPUT, timeout=timeout)

    def set_name(self, name: str) -> bool:
        return self.qt_safe_input(
            self.locators.NAME_INPUT,
            name,
            max_retries=1,
            verify=False,
        )

    def set_address(self, address: str) -> bool:
        return self.qt_safe_input(
            self.locators.ADDRESS_INPUT,
            address,
            max_retries=1,
            verify=False,
        )

    def save(self) -> bool:
        self.hide_keyboard()
        if not self.wait_for_element_enabled(self.locators.SAVE_BUTTON, timeout=8):
            self.logger.error("Add address button did not become enabled")
            return False
        return self.safe_click(self.locators.SAVE_BUTTON)

    def add_saved_address(self, name: str, address: str) -> bool:
        if not self.is_displayed(timeout=8):
            self.logger.error("Add saved address modal not visible")
            self.dump_page_source("add_saved_address_modal_missing")
            return False
        if not self.set_name(name):
            return False
        if not self.set_address(address):
            return False
        return self.save()


