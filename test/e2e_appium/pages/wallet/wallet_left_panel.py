from typing import List, Optional

from ..base_page import BasePage
from locators.wallet.accounts_locators import WalletAccountsLocators
from .add_edit_account_modal import AddEditAccountModal
from .keycard_auth_modal import KeycardAuthenticationModal
from .remove_account_modal import RemoveAccountConfirmationModal


class WalletLeftPanel(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = WalletAccountsLocators()

    def is_loaded(self, timeout: int = 15) -> bool:
        return self.is_element_visible(
            self.locators.ADD_ACCOUNT_BUTTON,
            timeout=timeout,
        )

    def open_add_account_popup(self) -> Optional[AddEditAccountModal]:
        self.safe_click(self.locators.ADD_ACCOUNT_BUTTON, timeout=5)
        modal = AddEditAccountModal(self.driver)
        return modal if modal.is_displayed(timeout=10) else None

    def add_account(self, name: str, auth_password: Optional[str] = None) -> bool:
        modal = self.open_add_account_popup()
        if not modal:
            self.logger.error("Failed to open add account modal")
            return False
        if not modal.set_name(name):
            self.logger.error(f"Failed to set account name to '{name}'")
            return False
        modal.save_changes()

        auth_modal = KeycardAuthenticationModal(self.driver)
        if not auth_modal.is_displayed(timeout=5):
            if not modal.wait_until_hidden(timeout=5):
                self.logger.error("Add account modal did not close and no authentication prompt appeared")
                return False
            return True

        if not auth_password:
            self.logger.error("Authentication required but no password provided")
            return False
        if not auth_modal.authenticate(auth_password):
            self.logger.error("Failed to authenticate when adding account")
            return False

        return True

    def account_rows(self) -> List:
        try:
            return self.driver.find_elements(*self.locators.ACCOUNT_ROW_ANY)
        except Exception as e:
            self.logger.debug(f"account_rows lookup failed: {e}")
            return []

    def account_names(self) -> List[str]:
        """Extract account names from visible account rows."""
        names: List[str] = []
        for row in self.account_rows():
            try:
                desc = row.get_attribute("content-desc") or row.get_attribute("text") or ""
                if desc:
                    name = desc.split(" [tid:", 1)[0]
                    if name:
                        names.append(name)
            except Exception as e:
                self.logger.debug(f"Failed to extract account name: {e}")
        return names

    def wait_for_account_name(self, name: str, timeout: int = 10) -> bool:
        return self.wait_for_condition(lambda: name in self.account_names(), timeout=timeout)

    def long_press_row(self, index: int = -1, duration_ms: int = 800) -> bool:
        rows = self.account_rows()
        if not rows:
            return False
        element = rows[index if index >= 0 and index < len(rows) else -1]
        try:
            return self.long_press_element(element, duration=duration_ms)
        except Exception as e:
            self.logger.debug(f"long_press_row failed at index {index}: {e}")
            return False

    def open_context_menu_for_row(self, index: int = -1) -> bool:
        if not self.long_press_row(index=index):
            return False
        return self.is_element_visible(self.locators.ACCOUNT_CONTEXT_MENU, timeout=5)

    def _complete_account_deletion(self, auth_password: Optional[str] = None) -> bool:
        """Complete account deletion after context menu is open.

        Clicks Delete, handles confirmation modal and authentication.

        Args:
            auth_password: Password for authentication if required.

        Returns:
            bool: True if deletion completed successfully.
        """
        self.safe_click(self.locators.ACCOUNT_MENU_DELETE, timeout=5)

        confirmation = RemoveAccountConfirmationModal(self.driver)
        if confirmation.is_displayed(timeout=5):
            if not confirmation.confirm_removal():
                self.logger.error("Failed to confirm account removal in confirmation modal")
                return False

        auth_modal = KeycardAuthenticationModal(self.driver)
        if auth_modal.is_displayed(timeout=3):
            if not auth_password:
                self.logger.error("Post-removal authentication required but no password provided")
                return False
            if not auth_modal.authenticate(auth_password):
                self.logger.error("Post-removal authentication failed")
                return False

        return True

    def edit_account_via_menu(self, new_name: str, index: int = -1) -> bool:
        """Edit account name via context menu.

        Args:
            new_name: New name to set for the account.
            index: Index of the account row to edit (-1 for last).

        Returns:
            bool: True if edit succeeded.
        """
        if not self.open_context_menu_for_row(index=index):
            self.logger.error("Failed to open account context menu via long-press")
            return False

        self.safe_click(self.locators.ACCOUNT_MENU_EDIT, timeout=5)

        modal = AddEditAccountModal(self.driver)
        if not modal.is_displayed(timeout=10):
            self.logger.error("Edit account modal did not appear")
            return False

        if not modal.set_name(new_name, clear_existing=True):
            self.logger.error(f"Failed to set account name to '{new_name}'")
            return False

        modal.save_changes()

        if not modal.wait_until_hidden(timeout=10):
            self.logger.error("Edit account modal did not close after saving")
            return False

        return True

    def delete_latest_account_via_menu(self, auth_password: Optional[str] = None) -> bool:
        if not self.open_context_menu_for_row(index=-1):
            self.logger.error("Failed to open account context menu via long-press")
            return False
        return self._complete_account_deletion(auth_password)

    def find_account_element_by_name(self, name: str, timeout: int = 10):
        """Find account row element by its name.

        Args:
            name: Account name to find.
            timeout: Timeout for finding the element.

        Returns:
            WebElement if found, None otherwise.
        """
        # Dynamic XPath for row containing the account name in content-desc
        locator = (
            "xpath",
            f"//*[contains(@resource-id,'walletAccountListItem') and starts-with(@content-desc, '{name}')]"
        )
        return self.find_element_safe(locator, timeout=timeout)

    def delete_account_by_name(self, name: str, auth_password: Optional[str] = None) -> bool:
        """Delete account by name via context menu.

        Args:
            name: Name of the account to delete.
            auth_password: Password for authentication if required.

        Returns:
            bool: True if deletion succeeded.
        """
        account_element = self.find_account_element_by_name(name, timeout=10)
        if not account_element:
            self.logger.error(f"Account '{name}' not found in account list")
            return False

        if not self.long_press_element(account_element, duration=800):
            self.logger.error(f"Failed to long-press account '{name}'")
            return False

        if not self.is_element_visible(self.locators.ACCOUNT_CONTEXT_MENU, timeout=5):
            self.logger.error("Context menu did not appear after long-press")
            return False

        return self._complete_account_deletion(auth_password)
