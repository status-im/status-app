
from locators.wallet.accounts_locators import WalletAccountsLocators

from ..base_page import BasePage


class AddEditAccountModal(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = WalletAccountsLocators()

    def is_displayed(self, timeout: int | None = 10) -> bool:
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

    def set_origin_watched_address(self, address: str) -> bool:
        """Select 'Watch-only address' origin and enter the address.

        Opens the origin selector, picks watched address, and types the
        Ethereum address into the input field.
        """
        if not self.safe_click(self.locators.ORIGIN_SELECTOR, timeout=5):
            self.logger.error("Failed to open origin selector")
            return False

        if not self.safe_click(self.locators.ORIGIN_WATCHED_ADDRESS, timeout=5):
            self.logger.error("Failed to select watched address origin")
            return False

        if not self.qt_safe_input(
            self.locators.WATCHED_ADDRESS_INPUT, address, verify=False
        ):
            self.logger.error("Failed to enter watched address")
            return False

        try:
            self.hide_keyboard()
        except Exception:
            pass

        return True

    def save_changes(self) -> bool:
        self.safe_click(self.locators.ADD_ACCOUNT_PRIMARY, timeout=10)
        return True

    def wait_until_hidden(self, timeout: int | None = 10) -> bool:
        return self.wait_for_invisibility(self.locators.ADD_ACCOUNT_MODAL, timeout=timeout)

    def close(self) -> bool:
        """Dismiss the add/edit account popup by pressing back."""
        try:
            self.driver.press_keycode(4)  # Android BACK key
            return self.wait_until_hidden(timeout=5)
        except Exception as e:
            self.logger.error(f"Failed to close add/edit account popup: {e}")
            return False

