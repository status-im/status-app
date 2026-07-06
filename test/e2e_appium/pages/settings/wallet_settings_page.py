import time
from typing import Optional, List

from selenium.webdriver.remote.webelement import WebElement

from ..base_page import BasePage
from locators.settings.wallet_settings_locators import WalletSettingsLocators
from pages.wallet.add_edit_account_modal import AddEditAccountModal
from pages.wallet.keycard_auth_modal import KeycardAuthenticationModal


class WalletSettingsPage(BasePage):
    """Page object for Wallet Settings view (Settings → Wallet)."""

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = WalletSettingsLocators()

    def is_loaded(self, timeout: Optional[int] = 10) -> bool:
        """Verify wallet settings view is displayed.
        
        Checks for the Add Account button as indicator the main view is loaded.
        """
        return self.is_element_visible(
            self.locators.ADD_ACCOUNT_BUTTON, timeout=timeout
        )

    def open_add_account_popup(self, timeout: int = 10) -> Optional[AddEditAccountModal]:
        """Click the Add Account button and return the modal.
        
        Returns:
            AddEditAccountModal if opened successfully, None otherwise.
        """
        if not self.safe_click(self.locators.ADD_ACCOUNT_BUTTON, timeout=timeout):
            self.logger.error("Failed to click Add Account button")
            return None

        modal = AddEditAccountModal(self.driver)
        if modal.is_displayed(timeout=timeout):
            return modal
        self.logger.error("Add Account modal did not appear")
        return None

    def _swipe_up(self, duration_ms: int = 300) -> bool:
        """Swipe up to scroll the wallet settings list.

        Uses window size to avoid hard-coded coordinates that vary per device.
        """
        try:
            size = self.driver.get_window_size()
            x = int(size["width"] * 0.5)
            start_y = int(size["height"] * 0.8)
            end_y = int(size["height"] * 0.3)
            self.driver.swipe(
                start_x=x,
                start_y=start_y,
                end_x=x,
                end_y=end_y,
                duration=duration_ms,
            )
            return True
        except Exception as e:
            self.logger.warning(f"Swipe up failed: {e}")
            return False

    def _scroll_until_visible(
        self,
        locator: tuple,
        *,
        scroll_attempts: int = 3,
        per_attempt_timeout: int = 2,
    ) -> bool:
        """Scroll until an element becomes visible."""
        if self.is_element_visible(locator, timeout=per_attempt_timeout):
            return True

        for attempt in range(scroll_attempts):
            self.logger.debug(f"Element not visible, scrolling (attempt {attempt + 1})")
            if not self._swipe_up():
                break
            if self.is_element_visible(locator, timeout=per_attempt_timeout):
                return True

        return False

    def get_account_rows(self, timeout: int = 10) -> List[WebElement]:
        """Return list of account row elements in the wallet settings.
        
        Note: This returns the keypair delegate containers which may contain
        multiple accounts. Use find_account_by_name for specific accounts.
        """
        try:
            # Best-effort wait for list to be present
            self.is_element_visible(self.locators.KEYPAIR_DELEGATE, timeout=timeout)
            return self.driver.find_elements(*self.locators.KEYPAIR_DELEGATE)
        except Exception as e:
            self.logger.debug(f"get_account_rows failed: {e}")
            return []

    def find_account_by_name(
        self, name: str, timeout: int = 10, scroll_attempts: int = 3
    ) -> Optional[WebElement]:
        """Find an account element by its name.
        
        Args:
            name: The account name to search for.
            timeout: Maximum wait time in seconds.
            scroll_attempts: Number of scroll attempts to find off-screen accounts.
            
        Returns:
            WebElement if found, None otherwise.
        """
        locator = self.locators.account_row_by_name(name)
        
        # First try without scrolling
        element = self.find_element_safe(locator, timeout=min(timeout, 3))
        if element:
            return element
        
        # Try scrolling down to find the account
        for attempt in range(scroll_attempts):
            self.logger.debug(
                f"Account '{name}' not found, scrolling down (attempt {attempt + 1})"
            )
            if not self._swipe_up():
                break
            element = self.find_element_safe(locator, timeout=3)
            if element:
                return element
        
        return None

    def select_account_by_name(self, name: str, timeout: int = 10) -> bool:
        """Click on an account to open its details view.
        
        Args:
            name: The account name to select.
            timeout: Maximum wait time in seconds.
            
        Returns:
            bool: True if account was clicked successfully.
        """
        locator = self.locators.account_row_by_name(name)

        if not self._scroll_until_visible(
            locator,
            scroll_attempts=3,
            per_attempt_timeout=min(2, timeout),
        ):
            self.logger.error(f"Account '{name}' not visible in wallet settings list")
            return False
        
        # Account rows are StatusListItems nested in a scrollview; the first tap
        # can drop mid-settle. Retry until the details view actually opens.
        from pages.wallet.account_details_page import AccountDetailsPage
        details = AccountDetailsPage(self.driver)
        for attempt in range(3):
            time.sleep(0.4)
            try:
                self.safe_click(locator, timeout=timeout, max_attempts=1)
            except Exception as e:
                self.logger.debug(f"select_account tap attempt {attempt + 1}: {e}")
            if details.is_loaded(timeout=3):
                return True
            self.logger.debug(f"Account '{name}' tap did not open details (attempt {attempt + 1})")
        self.logger.error(f"Account '{name}' selected but details view did not open")
        return False

    def select_account_by_index(self, index: int = 0, timeout: int = 10) -> bool:
        """Click on an account at the specified index.
        
        Args:
            index: The index of the account to select (0-based).
            timeout: Maximum wait time in seconds.
            
        Returns:
            bool: True if account was clicked successfully.
        """
        rows = self.get_account_rows(timeout=timeout)
        if not rows:
            self.logger.error("No account rows found in wallet settings")
            return False
        
        if index < 0:
            index = len(rows) + index
            
        if index >= len(rows) or index < 0:
            self.logger.error(f"Account index {index} out of range (0-{len(rows)-1})")
            return False
        
        try:
            rows[index].click()
            return True
        except Exception as e:
            self.logger.error(f"Failed to click account at index {index}: {e}")
            return False

    def add_account(
        self,
        name: str,
        auth_password: Optional[str] = None,
        timeout: int = 10,
    ) -> bool:
        """Add a new account with the given name.
        
        Args:
            name: The name for the new account.
            auth_password: Password for authentication if required.
            timeout: Maximum wait time for each operation.
            
        Returns:
            bool: True if account was added successfully.
        """
        modal = self.open_add_account_popup(timeout=timeout)
        if not modal:
            return False

        if not modal.set_name(name):
            self.logger.error(f"Failed to set account name to '{name}'")
            return False

        if not modal.save_changes():
            self.logger.error("Failed to save account changes")
            return False

        # Handle authentication if required
        auth_modal = KeycardAuthenticationModal(self.driver)
        if not auth_modal.is_displayed(timeout=5):
            # No authentication required, wait for modal to close
            if not modal.wait_until_hidden(timeout=timeout):
                self.logger.error("Add account modal did not close and no auth prompt appeared")
                return False
            return True

        # Authentication modal appeared - password is required
        if not auth_password:
            self.logger.error("Authentication required but no password provided")
            return False
        if not auth_modal.authenticate(auth_password):
            self.logger.error("Authentication failed")
            return False

        return True

    def open_networks(self, timeout: int = 10) -> bool:
        """Open Settings → Wallet → Networks.

        Returns True once the networks view is displayed (testnet switch
        visible in its title row).
        """
        if not self._scroll_until_visible(self.locators.NETWORKS_ITEM):
            self.logger.error("Networks item not visible in wallet settings")
            return False
        if not self.try_click(self.locators.NETWORKS_ITEM, timeout=timeout):
            self.logger.error("Failed to click Networks item")
            return False
        return self.is_element_visible(
            self.locators.TESTNET_MODE_SWITCH, timeout=timeout
        )

    def enable_testnet_mode(self, timeout: int = 10) -> bool:
        """Turn on testnet mode from the Networks view (no-op if already on)."""
        if not self.is_element_visible(self.locators.TESTNET_MODE_SWITCH, timeout=timeout):
            self.logger.error("Testnet mode switch not visible")
            return False
        if self._is_element_checked(self.locators.TESTNET_MODE_SWITCH):
            self.logger.info("Testnet mode already enabled")
            return True
        if not self.try_click(self.locators.TESTNET_MODE_SWITCH, timeout=timeout):
            self.logger.error("Failed to tap testnet mode switch")
            return False
        if not self.try_click(
            self.locators.TESTNET_CONFIRM_BUTTON,
            fallback_locators=[self.locators.TESTNET_CONFIRM_BUTTON_FALLBACK],
            timeout=timeout,
        ):
            self.logger.error("Failed to confirm testnet mode popup")
            return False
        return self.wait_for_element_checked(
            self.locators.TESTNET_MODE_SWITCH, timeout=15
        )

    def account_exists(self, name: str, timeout: int = 5) -> bool:
        """Check if an account with the given name exists.
        
        Args:
            name: The account name to check for.
            timeout: Maximum wait time in seconds.
            
        Returns:
            bool: True if account exists.
        """
        return self.find_account_by_name(name, timeout=timeout) is not None
