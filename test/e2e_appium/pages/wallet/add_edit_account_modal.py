from typing import Optional

from ..base_page import BasePage
from locators.wallet.accounts_locators import WalletAccountsLocators


class AddEditAccountModal(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = WalletAccountsLocators()

    def is_displayed(self, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(self.locators.ADD_ACCOUNT_MODAL, timeout=timeout)

    def set_name(self, name: str, clear_existing: bool = False) -> bool:
        """Set account name in the modal.

        Args:
            name: The account name to set.
            clear_existing: If True, clears existing text before typing (for edit flow).
                          If False, relies on qt_safe_input's native clear (for add flow).
        """
        if clear_existing:
            if not self._clear_input_field(self.locators.ACCOUNT_NAME_INPUT):
                self.logger.error("Failed to clear existing account name")
                return False
        return self.qt_safe_input(self.locators.ACCOUNT_NAME_INPUT, name, verify=False)

    def save_changes(self) -> bool:
        self.safe_click(self.locators.ADD_ACCOUNT_PRIMARY, timeout=10)
        return True

    def wait_until_hidden(self, timeout: Optional[int] = 10) -> bool:
        return self.wait_for_invisibility(self.locators.ADD_ACCOUNT_MODAL, timeout=timeout)

