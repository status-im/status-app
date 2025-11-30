from ..base_page import BasePage
from locators.wallet.accounts_locators import WalletAccountsLocators


class RemoveAccountConfirmationModal(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = WalletAccountsLocators()

    def is_displayed(self, timeout: int = 5) -> bool:
        return self.is_element_visible(self.locators.REMOVE_ACCOUNT_MODAL, timeout=timeout)

    def acknowledge_derivation_path(self) -> bool:
        if self._is_element_checked(self.locators.REMOVE_ACCOUNT_ACK_CHECKBOX):
            return True
        self.safe_click(self.locators.REMOVE_ACCOUNT_ACK_CHECKBOX, timeout=5)
        return self._is_element_checked(self.locators.REMOVE_ACCOUNT_ACK_CHECKBOX)

    def confirm_removal(self, timeout: int = 15) -> bool:
        if not self.is_displayed(timeout=timeout):
            self.logger.error("Remove account confirmation modal not displayed")
            return False

        if not self.acknowledge_derivation_path():
            self.logger.error("Failed to acknowledge derivation path checkbox")
            return False

        if not self.wait_for_element_enabled(self.locators.REMOVE_ACCOUNT_CONFIRM_BUTTON, timeout=timeout):
            self.logger.error("Remove account confirm button did not become enabled")
            return False

        self.safe_click(self.locators.REMOVE_ACCOUNT_CONFIRM_BUTTON, timeout=timeout)
        return True
