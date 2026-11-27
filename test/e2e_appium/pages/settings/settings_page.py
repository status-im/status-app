import re
from typing import Optional
from xml.etree import ElementTree

from locators.settings.settings_locators import SettingsLocators
from locators.settings.wallet_settings_locators import WalletSettingsLocators
from locators.wallet.saved_addresses_locators import SavedAddressesLocators
from pages.wallet.saved_addresses_page import SavedAddressesPage

from ..base_page import BasePage
from .backup_seed_modal import BackupSeedModal
from .contacts_page import ContactsSettingsPage
from .messaging_page import MessagingSettingsPage
from .password_change_page import PasswordChangePage
from .profile_page import ProfileSettingsPage
from .share_profile_dialog import ShareProfileDialog
from .wallet_settings_page import WalletSettingsPage


class SettingsPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = SettingsLocators()

    def is_loaded(self, timeout: Optional[int] = 6) -> bool:
        return self.is_element_visible(self.locators.PROFILE_MENU_ITEM, timeout=timeout)

    def visible_menu_item_ids(self) -> set[str]:
        """Read the Settings rows with on-screen bounds in the Android tree."""
        items = set()
        for node in ElementTree.fromstring(self.driver.page_source).iter():
            menu_item = self.locators.MENU_ITEM_RESOURCE_ID.search(
                node.get("resource-id", "")
            )
            if menu_item is None:
                menu_item = self.locators.MENU_ITEM_TEST_ID.search(
                    node.get("content-desc", "")
                )
            if menu_item is None or node.get("displayed") == "false":
                continue

            bounds = re.findall(r"-?\d+", node.get("bounds", ""))
            if len(bounds) == 4:
                left, top, right, bottom = map(int, bounds)
                if left < right and top < bottom:
                    items.add(menu_item[1])
        return items

    def swipe_toward_end_of_menu(self) -> None:
        size = self.driver.get_window_size()
        x = int(size["width"] * 0.2)
        height = size["height"]
        # Leave overlap between viewports so each row is sampled.
        self.driver.swipe(x, int(height * 0.8), x, int(height * 0.3), duration=1000)

    def open_sign_out(self) -> bool:
        return self.try_click(
            self.locators.SIGN_OUT_MENU_ITEM,
            fallback_locators=[self.locators.SIGN_OUT_MENU_ITEM_TEXT],
        )

    def confirm_sign_out(self) -> bool:
        return self.try_click(
            self.locators.CONFIRM_SIGN_OUT,
            fallback_locators=[self.locators.CONFIRM_SIGN_OUT_TEXT],
        )

    def open_backup_recovery_phrase(self) -> Optional[BackupSeedModal]:
        if not self.is_element_visible(
            self.locators.BACKUP_RECOVERY_MENU_ITEM, timeout=10
        ):
            return None
        if not self.try_click(
            self.locators.BACKUP_RECOVERY_MENU_ITEM, timeout=5,
            catch_driver_errors=True,
        ):
            return None
        modal = BackupSeedModal(self.driver)
        return modal if modal.is_displayed(timeout=10) else None

    def open_password_settings(self) -> Optional[PasswordChangePage]:
        if not self.is_loaded(timeout=10):
            return None
        if not self.try_click(
            self.locators.PASSWORD_MENU_ITEM,
            timeout=5,
            fallback_locators=[self.locators.PASSWORD_MENU_ITEM_TEXT],
            catch_driver_errors=True,
        ):
            return None

        page = PasswordChangePage(self.driver)
        return page if page.is_loaded(timeout=10) else None

    def is_backup_entry_removed(self) -> bool:
        return not self.is_element_visible(
            self.locators.BACKUP_RECOVERY_MENU_ITEM, timeout=2
        )

    def open_saved_addresses(self) -> Optional[SavedAddressesPage]:
        locators = SavedAddressesLocators()
        if not self.is_loaded(timeout=10):
            return None
        # Optional pre-step: in some layouts Saved addresses sits under the
        # Wallet menu entry; a miss here is expected in the others.
        self.try_click(locators.SETTINGS_WALLET_MENU_ITEM)
        if not self.is_element_visible(locators.SAVED_ADDRESSES_ITEM, timeout=10):
            return None
        if not self.try_click(locators.SAVED_ADDRESSES_ITEM, catch_driver_errors=True):
            return None
        page = SavedAddressesPage(self.driver)
        return page if page.is_loaded(timeout=10) else None

    def open_wallet_settings(self, timeout: int = 10) -> Optional[WalletSettingsPage]:
        """Navigate to Settings → Wallet.
        
        Opens the wallet settings view from the main settings menu.
        
        Args:
            timeout: Maximum wait time for page load.
            
        Returns:
            WalletSettingsPage if opened successfully, None otherwise.
        """
        wallet_locators = WalletSettingsLocators()
        if not self.try_click(wallet_locators.WALLET_MENU_ITEM, timeout=timeout):
            self.logger.error("Failed to click Wallet menu item in settings")
            return None
        
        page = WalletSettingsPage(self.driver)
        if page.is_loaded(timeout=timeout):
            return page
        self.logger.error("Wallet settings page did not load")
        return None

    def open_messaging_settings(self) -> Optional[MessagingSettingsPage]:
        if self.try_click(
            self.locators.MESSAGING_MENU_ITEM,
            fallback_locators=[self.locators.CONTACTS_MENU_ITEM],
        ):
            page = MessagingSettingsPage(self.driver)
            return page if page.is_loaded(timeout=10) else None
        return None

    def open_contacts_settings(self) -> Optional[ContactsSettingsPage]:
        if self.try_click(self.locators.CONTACTS_MENU_ITEM, max_attempts=1):
            page = ContactsSettingsPage(self.driver)
            if page.is_loaded(timeout=8):
                return page
        messaging_page = self.open_messaging_settings()
        if not messaging_page:
            return None
        return messaging_page.open_contacts()

    def open_profile_settings(self) -> Optional[ProfileSettingsPage]:
        if self.try_click(self.locators.PROFILE_MENU_ITEM):
            page = ProfileSettingsPage(self.driver)
            return page if page.is_loaded(timeout=10) else None
        return None

    def open_share_profile_dialog(self) -> Optional[ShareProfileDialog]:
        profile_page = self.open_profile_settings()
        if not profile_page:
            return None
        if not profile_page.open_identity_tab():
            return None
        return profile_page.open_share_profile()
