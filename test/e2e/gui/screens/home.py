import time

import allure

import driver
from gui.components.back_up_your_seed_phrase_popup import BackUpYourSeedPhrasePopUp
from gui.components.online_identifier import OnlineIdentifier
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import home_names
from gui.screens.community_portal import CommunitiesPortal
from gui.screens.settings_messaging import MessagingSettingsView
from gui.screens.settings_profile import ProfileSettingsView
from gui.screens.settings_syncing import SyncingSettingsView
from gui.screens.wallet import WalletScreen


class HomeScreen(QObject):

    def __init__(self):
        super().__init__(home_names.home_container)
        self.search_field = TextEdit(home_names.home_search_field)
        self.grid = QObject(home_names.home_grid)
        self.dock = QObject(home_names.home_dock)
        self.profile_button = QObject(home_names.home_profile)

    # =============================================================================
    # SEARCH FUNCTIONS
    # =============================================================================

    @allure.step('Search in Home')
    def search(self, query: str):
        """Enter search query in the home search field"""
        self.search_field.clear()
        self.search_field.type_text(query)

    @allure.step('Clear Home search')
    def clear_search(self):
        """Clear the search field"""
        self.search_field.clear()

    @allure.step('Get search text')
    def get_search_text(self) -> str:
        """Get current search text"""
        return self.search_field.text

    # =============================================================================
    # GRID FUNCTIONS
    # =============================================================================

    @allure.step('Get grid items count')
    def get_grid_items_count(self) -> int:
        """Get number of items currently visible in the grid"""
        return self.grid.object.count if hasattr(self.grid.object, 'count') else 0

    @allure.step('Click grid item by title')
    def click_grid_item_by_title(self, title: str):
        """Click a grid item by its title"""
        locator = home_names.home_grid_item.copy()
        locator["title"] = title
        grid_item = Button(locator)
        grid_item.click()

    @allure.step('Check if grid item exists by title')
    def has_grid_item_by_title(self, title: str) -> bool:
        """Check if a grid item with the given title exists in the home grid"""
        locator = home_names.home_grid_item.copy()
        locator["title"] = title
        grid_item = Button(locator)
        return grid_item.is_visible

    @allure.step('Wait for grid item to appear')
    def wait_for_grid_item_by_title(self, title: str, timeout_msec: int = 10000):
        """Wait for a grid item to appear in the home grid"""
        return driver.waitFor(
            lambda: self.has_grid_item_by_title(title), timeout_msec
        )

    @allure.step('Wait for grid item to be removed')
    def wait_for_grid_item_removed_by_title(self, title: str, timeout_msec: int = 10000):
        """Wait for a grid item to be removed from the home grid"""
        return driver.waitFor(
            lambda: not self.has_grid_item_by_title(title), timeout_msec
        )

    @allure.step('Open Messaging settings view from home page')
    def open_messaging_settings_from_grid(self) -> 'MessagingSettingsView':
        self.click_grid_item_by_title("Messaging")
        return MessagingSettingsView().wait_until_appears()
    
    @allure.step('Open Syncing settings from home page')
    def open_syncing_settings_from_grid(self) -> 'SyncingSettingsView':
        self.click_grid_item_by_title("Syncing")
        return SyncingSettingsView().wait_until_appears()

    @allure.step('Open Profile settings from home page')
    def open_profile_settings_from_grid(self) -> 'ProfileSettingsView':
        self.click_grid_item_by_title("Profile")
        return ProfileSettingsView().wait_until_appears()

    @allure.step('Open Communities Portal from home page')
    def open_communities_portal_from_grid(self) -> 'CommunitiesPortal':
        self.click_grid_item_by_title("Communities")
        return CommunitiesPortal().wait_until_appears()

    @allure.step('Back up seed phrase from home page')
    def open_back_up_seed_popup_from_home_page(self) -> 'BackUpYourSeedPhrasePopUp':
        self.click_grid_item_by_title("Back up recovery phrase")
        return BackUpYourSeedPhrasePopUp().wait_until_appears()

    @allure.step('Open Wallet from home page')
    def open_wallet_from_home_page(self) -> 'WalletScreen':
        self.click_grid_item_by_title("Wallet")
        return WalletScreen().wait_until_appears()

    @allure.step('Open online identifier from home screen')
    def open_online_identifier_from_home_screen(self, attempts: int = 3) -> 'OnlineIdentifier':
        for _ in range(attempts):
            try:
                self.profile_button.click()
                return OnlineIdentifier().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Online identifier popup was not opened after {attempts} retries')


    # =============================================================================
    # UTILITY FUNCTIONS
    # =============================================================================

    @allure.step('Wait for home UI to be fully loaded')
    def wait_for_home_ui_loaded(self):
        # TODO: https://github.com/status-im/status-app/issues/18325
        time.sleep(0.5)
        return self
