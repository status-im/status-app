import re
from typing import Optional

from ..base_page import BasePage
from locators.wallet.account_details_locators import AccountDetailsLocators
from .remove_account_modal import RemoveAccountConfirmationModal
from .keycard_auth_modal import KeycardAuthenticationModal


class AccountDetailsPage(BasePage):
    """Page object for Account Details view (Settings → Wallet → Account)."""

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = AccountDetailsLocators()

    def is_loaded(self, timeout: Optional[int] = 10) -> bool:
        """Verify account details view is displayed.
        
        Checks multiple indicators to determine if the view is loaded.
        Uses multiple locator strategies for robustness.
        """
        # Primary check: Edit account button by content-desc (most reliable)
        if self.is_element_visible(self.locators.EDIT_BUTTON_ALT, timeout=timeout):
            return True
        # Alternative: Edit button by resource-id
        if self.is_element_visible(self.locators.EDIT_BUTTON, timeout=3):
            return True
        # Fallback: delete/remove button (visible for non-default accounts)
        if self.is_element_visible(self.locators.DELETE_BUTTON, timeout=3):
            return True
        # Alternative: "Account details" label
        if self.is_element_visible(self.locators.ACCOUNT_DETAILS_LABEL, timeout=3):
            return True
        # Final fallback: account name element
        return self.is_element_visible(self.locators.ACCOUNT_NAME, timeout=3)

    def get_account_name(self, timeout: int = 10) -> Optional[str]:
        """Get the displayed account name.

        
        Returns:
            Account name string or None if not found.
        """
        element = self.find_element_safe(self.locators.ACCOUNT_NAME, timeout=timeout)
        if element:
            name = (
                element.get_attribute("content-desc")
                or element.get_attribute("text")
                or element.text
            )
            if name and name.strip():
                return name.strip()
        return None

    def _get_row_subtitle(self, row_locator: tuple, timeout: int = 10) -> Optional[str]:
        """Extract the subtitle/value text from a details row.
        
        Account detail rows use StatusListItem with Accessible.name format:
        "Title: Subtitle" (e.g., "Address: 0x1234...")
        """
        row = self.find_element_safe(row_locator, timeout=timeout)
        if not row:
            return None
        
        # Primary strategy: Parse content-desc with format "Title: Value"
        content_desc = row.get_attribute("content-desc")
        if content_desc:
            content_desc = content_desc.strip()
            # Check for "Title: Value" format
            if ": " in content_desc:
                # Split on first ": " to get value part
                parts = content_desc.split(": ", 1)
                if len(parts) == 2:
                    value = parts[1].strip()
                    if value and "[tid:" not in value:
                        return value
        
        # Fallback: Find text elements within the row
        try:
            text_elements = row.find_elements("xpath", ".//android.widget.TextView")
            if len(text_elements) >= 2:
                # Second element should be subtitle
                subtitle = text_elements[1]
                text = subtitle.text or subtitle.get_attribute("content-desc")
                if text and text.strip():
                    return text.strip()
        except Exception as e:
            self.logger.debug(f"Text element extraction failed: {e}")
        
        # Last resort: Get row text directly
        if row.text:
            return row.text.strip()
        
        return None

    def get_account_address(self, timeout: int = 10) -> Optional[str]:
        """Get the wallet address from the Address row.
        
        Returns:
            Wallet address (0x...) or None if not found.
        """
        value = self._get_row_subtitle(self.locators.ADDRESS_ROW, timeout=timeout)
        # Extract address if it's combined with other text
        if value and "0x" in value:
            # Find the address portion (starts with 0x)
            for part in value.split():
                if part.startswith("0x"):
                    return part
            # If no space separation, try to extract 0x... pattern
            idx = value.find("0x")
            if idx >= 0:
                # Take from 0x to next space or end
                end_idx = value.find(" ", idx)
                return value[idx:] if end_idx < 0 else value[idx:end_idx]
        return value

    def get_origin_value(self, timeout: int = 10) -> Optional[str]:
        """Get the origin/source text from the Origin row.
        
        Expected values:
        - "Derived from your default Status key pair" (generated accounts)
        - "Imported from recovery phrase" (seed import)
        - "Imported from private key" (private key import)
        - "Watched address" (watch-only)
        
        Returns:
            Origin text or None if not found.
        """
        return self._get_row_subtitle(self.locators.ORIGIN_ROW, timeout=timeout)

    def get_derivation_path(self, timeout: int = 10) -> Optional[str]:
        """Get the derivation path from the Derivation Path row.
        
        Expected format: m/44'/60'/0'/0/N where N is the account index.
        
        Returns:
            Derivation path string or None if not found/visible.
        """
        if not self.is_element_visible(self.locators.DERIVATION_PATH_ROW, timeout=2):
            # Derivation path not shown for private key imports or watch-only
            return None
        return self._get_row_subtitle(self.locators.DERIVATION_PATH_ROW, timeout=timeout)

    def get_storage_value(self, timeout: int = 10) -> Optional[str]:
        """Get the storage location from the Stored row.
        
        Expected values:
        - "On device" (stored locally)
        - Keycard-related values if migrated
        
        The row content-desc format may be:
        - "Stored: On device" (simple)
        - "Stored: zQ3…7zDSDb<font size='3'>  &#x2022; </font>On device" (with keypair)
        
        Returns:
            Storage text or None if not found/visible.
        """
        if not self.is_element_visible(self.locators.STORED_ROW, timeout=2):
            return None
        
        value = self._get_row_subtitle(self.locators.STORED_ROW, timeout=timeout)
        if not value:
            return None
        
        # Handle HTML bullet separator format: "keypair<font...>&#x2022;</font>storage"
        # Extract the part after the HTML bullet point
        html_bullet_pattern = r'<font[^>]*>\s*&#x2022;\s*</font>'
        if re.search(html_bullet_pattern, value):
            parts = re.split(html_bullet_pattern, value)
            if len(parts) >= 2:
                storage = parts[-1].strip()
                self.logger.debug(f"Extracted storage '{storage}' from compound value")
                return storage
        
        # Fallback: check for known storage values at the end
        known_values = ["On device", "On this device", "On Keycard"]
        for known in known_values:
            if value.endswith(known):
                return known
        
        return value

    def get_balance(self, timeout: int = 10) -> Optional[str]:
        """Get the account balance from the Balance row.
        
        Returns:
            Balance string (e.g., "$0.00") or None if not found.
        """
        return self._get_row_subtitle(self.locators.BALANCE_ROW, timeout=timeout)

    def click_delete_button(self, timeout: int = 10) -> bool:
        """Click the delete/remove account button.
        
        Returns:
            bool: True if click succeeded.
        """
        return self.safe_click(self.locators.DELETE_BUTTON, timeout=timeout)

    def open_delete_confirmation(
        self, timeout: int = 10
    ) -> Optional[RemoveAccountConfirmationModal]:
        """Click delete and return the confirmation modal.
        
        Returns:
            RemoveAccountConfirmationModal if opened successfully, None otherwise.
        """
        if not self.click_delete_button(timeout=timeout):
            self.logger.error("Failed to click delete button")
            return None

        modal = RemoveAccountConfirmationModal(self.driver)
        if modal.is_displayed(timeout=timeout):
            return modal
        self.logger.error("Remove account confirmation modal did not appear")
        return None

    def delete_account(
        self, auth_password: Optional[str] = None, timeout: int = 10
    ) -> bool:
        """Delete the account from this details view.
        
        Handles the full deletion flow including confirmation and authentication.
        
        Args:
            auth_password: Password for authentication (required for non-watch accounts).
            timeout: Maximum wait time for each operation.
            
        Returns:
            bool: True if account was deleted successfully.
        """
        confirmation = self.open_delete_confirmation(timeout=timeout)
        if not confirmation:
            return False

        if not confirmation.confirm_removal(timeout=timeout):
            self.logger.error("Failed to confirm account removal")
            return False

        # Handle authentication if required (not needed for watch-only)
        auth_modal = KeycardAuthenticationModal(self.driver)
        if auth_modal.is_displayed(timeout=5):
            if not auth_password:
                self.logger.error("Authentication required but no password provided")
                return False
            if not auth_modal.authenticate(auth_password):
                self.logger.error("Authentication failed during deletion")
                return False

        return True

    def click_edit_button(self, timeout: int = 10) -> bool:
        """Click the edit account button.
        
        Returns:
            bool: True if click succeeded.
        """
        return self.safe_click(self.locators.EDIT_BUTTON, timeout=timeout)
