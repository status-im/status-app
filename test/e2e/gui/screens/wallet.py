import logging
import time
import typing

import allure
import pyperclip

import configs
import constants
import driver
from constants import WalletAccount
from driver.objects_access import walk_children
from gui.components.context_menu import ContextMenu
from gui.components.wallet.add_saved_address_popup import AddEditSavedAddressPopup
from gui.components.wallet.asset_context_menu_popup import AssetContextMenuPopup
from gui.components.wallet.assets_view import AssetsView
from gui.components.wallet.bridge_popup import BridgePopup
from gui.components.wallet.confirmation_popup import ConfirmationPopup
from gui.components.wallet.delete_account_confirmation_popup import RemoveAccountWithConfirmation
from gui.components.wallet.receive_popup import ReceivePopup
from gui.components.wallet.send_popup import SendPopup
from gui.components.wallet.swap_popup import SwapPopup
from gui.components.wallet.wallet_account_context_menu import WalletAccountContextMenu
from gui.components.wallet.wallet_account_popups import AccountPopup
from gui.elements.button import Button
from gui.elements.list import List
from gui.elements.object import QObject
from gui.elements.text_label import TextLabel
from gui.objects_map import wallet_names, settings_names, names
from helpers.wallet_helper import (
    _asset_items_finished_loading,
    is_activity_tab_content_loaded,
)

LOG = logging.getLogger(__name__)


def _wait_until(
    condition: typing.Callable[[], bool],
    timeout_msec: int | None,
    error_message: str,
    check_interval: float = 0.1,
) -> None:
    if timeout_msec is None:
        while not condition():
            time.sleep(check_interval)
        return
    assert driver.waitFor(condition, timeout_msec), error_message


class WalletScreen(QObject):

    def __init__(self):
        super().__init__(wallet_names.mainWindow_WalletLayout)
        self.left_panel: WalletLeftPanel = WalletLeftPanel()
        self.main_wallet_layout = QObject(wallet_names.mainWindow_WalletLayout)


class WalletLeftPanel(QObject):

    def __init__(self):
        super(WalletLeftPanel, self).__init__(wallet_names.mainWallet_LeftTab)
        self.saved_addresses_button = Button(wallet_names.mainWallet_Saved_Addresses_Button)
        self.wallet_account_item = QObject(wallet_names.walletAccount_StatusListItem)
        self.add_account_button = Button(wallet_names.mainWallet_Add_Account_Button)
        self.all_accounts_button = Button(wallet_names.mainWallet_All_Accounts_Button)
        self.all_accounts_balance = TextLabel(wallet_names.mainWallet_All_Accounts_Balance)

    @property
    @allure.step('Build and return list of wallet accounts on wallet main screen')
    def accounts(self, timeout_sec: int = 10) -> typing.List[WalletAccount]:
        if 'title' in self.wallet_account_item.real_name.keys():
            del self.wallet_account_item.real_name['title']

        start_time = time.monotonic()
        accounts = []
        while time.monotonic() - start_time < timeout_sec:
            try:
                raw_data = driver.findAllObjects(self.wallet_account_item.real_name)
                for account_item in raw_data:
                    name = str(account_item.title)
                    color = str(account_item.asset.color.name).lower()
                    emoji = ''
                    for child in walk_children(account_item):
                        if hasattr(child, 'emojiId'):
                            emoji = str(child.emojiId)
                            break
                    accounts.append(constants.WalletAccount(name=name, color=color, emoji=emoji.split('-')[0]))
                return accounts
            except LookupError as e:
                LOG.debug(f'accounts are not found: {e}')
                time.sleep(0.1)

        raise TimeoutError(f"Accounts list is not built within {timeout_sec}")

    @allure.step('Get total balance value from All accounts')
    def get_total_balance_value(self):
        return self.all_accounts_balance.text

    @allure.step('Choose saved addresses on left wallet panel')
    def open_saved_addresses(self) -> 'SavedAddressesView':
        self.saved_addresses_button.click()
        return SavedAddressesView().wait_until_appears()

    @allure.step('Select account from list')
    def select_account(self, account_name: str) -> 'WalletAccountView':
        account_items = self.accounts
        existing_accounts_names = [account.name for account in account_items]
        if account_name in existing_accounts_names:
            self.wallet_account_item.real_name['title'] = account_name
            last_error = None
            for _ in range(2):
                self.wallet_account_item.click()
                try:
                    account_view = WalletAccountView().wait_until_appears()
                    assert driver.waitFor(
                        lambda: account_view.name == account_name,
                        configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
                    ), f'Wallet account view did not switch to {account_name}'
                    return account_view
                except Exception as error:
                    last_error = error
            raise LookupError(f'Could not select {account_name}') from last_error
        raise LookupError(f'{account_name} is not present in {account_items}')

    @allure.step('Open all Wallet accounts')
    def open_all_accounts(
        self,
        account_name: str,
        timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
    ) -> 'WalletLeftPanel':
        self.all_accounts_button.click()
        assert driver.waitFor(
            lambda: account_name in [account.name for account in self.accounts],
            timeout_msec,
        ), f'Wallet account list did not show {account_name}'
        return self

    @allure.step('Open context menu from left wallet panel')
    def _open_context_menu(self) -> WalletAccountContextMenu:
        super(WalletLeftPanel, self).right_click()
        return WalletAccountContextMenu().wait_until_appears()

    @allure.step('Open context menu for specific account')
    def _open_context_menu_for_account(self, account_name: str, attempts: int = 2) -> WalletAccountContextMenu:
        account_items = self.accounts
        if not any(account.name == account_name for account in account_items):
            raise LookupError(f'Account "{account_name}" not found in {[account.name for account in account_items]}')
        
        self.wallet_account_item.real_name['title'] = account_name
        for _ in range(attempts):
            self.wallet_account_item.right_click()
            try:
                return WalletAccountContextMenu().wait_until_appears()
            except Exception:
                pass  # Retry one more time
        raise LookupError(f'Could not open context menu for "{account_name}" after {attempts} attempts')

    @allure.step("Select Hide/Include in total balance from context menu for account")
    def hide_include_in_total_balance_from_context_menu(self, account_name: str):
        self._open_context_menu_for_account(account_name).hide_include_in_total_balance.click()

    @allure.step('Open account popup for editing from context menu')
    def open_edit_account_popup_from_context_menu(self, account_name: str, attempts = 3) -> AccountPopup:
        for _ in range(attempts):
            try:
                context_menu = self._open_context_menu_for_account(account_name)
                context_menu.edit_from_wallet_account_context.click()
                return AccountPopup().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Account popup is not shown after {attempts} retries')

    @allure.step('Open account popup')
    def open_add_account_popup(self, attempts: int = 3) -> 'AccountPopup':
        for _ in range(attempts):
            try:
                self.add_account_button.click()
                return AccountPopup().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Account popup is not opened with {attempts} retries')

    @allure.step('Select add watched address from context menu')
    def select_add_watched_address_from_context_menu(self, attempts: int = 3) -> 'AccountPopup':
        for _ in range(attempts):
            try:
                self._open_context_menu().add_watched_address.click()
                return AccountPopup().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Account popup is not opened with {attempts} retries')

    @allure.step('Delete account from the list from context menu')
    def delete_account_from_context_menu(self, account_name: str, attempts: int = 2) -> RemoveAccountWithConfirmation:
        for _ in range(attempts):
            try:
                self._open_context_menu_for_account(account_name).delete_from_wallet_account_context.click()
                return RemoveAccountWithConfirmation().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Could not open Remove Account Popup')


    @allure.step('Copy address for the account in the context menu')
    def copy_account_address_in_context_menu(self, account_name: str):
        self._open_context_menu_for_account(account_name).copy_address_from_wallet_account_context.click()
        return str(pyperclip.paste())


class SavedAddressesView(QObject):

    def __init__(self):
        super(SavedAddressesView, self).__init__(wallet_names.mainWindow_SavedAddressesView)
        self._add_new_address_button = Button(wallet_names.mainWallet_Saved_Addresses_Add_Buttton)
        self._address_list_item = QObject(wallet_names.savedAddressView_Delegate)
        self._addresses_area = QObject(wallet_names.savedAddresses_area)
        self._addresses_list_view = QObject(wallet_names.mainWallet_Saved_Addresses_List)
        self._send_button = Button(wallet_names.send_StatusRoundButton)
        self._open_menu_button = Button(wallet_names.savedAddressView_Delegate_menuButton)
        self._saved_address_item = QObject(wallet_names.savedAddressView_Delegate)

    @property
    @allure.step('Get saved addresses wallet_names')
    def address_names(self):
        address_names = []
        for child in walk_children(self._addresses_list_view.object):
            if getattr(child, 'id', '') == 'savedAddressDelegate':
                address_names.append(str(child.name))
        return address_names

    @allure.step('Get saved addresses list')
    def get_saved_addresses_list(self):
        addresses = [str(address.name) for address in driver.findAllObjects(self._saved_address_item.real_name)]
        return addresses

    @allure.step('Open add new address popup')
    def open_add_edit_saved_address_popup(self, attempts=2) -> 'AddEditSavedAddressPopup':
        for _ in range(attempts):
            try:
                self._add_new_address_button.click()
                return AddEditSavedAddressPopup().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Could not open AddEditSavedAddress popup within {attempts} attempts')

    @allure.step('Open edit address popup for saved address')
    def right_click_edit_saved_address_popup(self, name: str) -> 'AddEditSavedAddressPopup':
        self.right_click(name).edit_saved_address_from_context.click()
        return AddEditSavedAddressPopup()

    @allure.step('Delete saved address from the list')
    def delete_saved_address(self, address_name):
        context_menu = self.right_click(address_name)
        # Ensure the delete menu item is ready before clicking
        context_menu.delete_saved_address_from_context.wait_until_appears().click()
        confirmation_popup = ConfirmationPopup().wait_until_appears()
        assert confirmation_popup.get_confirmation_text().startswith('Are you sure you want to remove')
        confirmation_popup.confirm()

    @allure.step('Open context menu in saved address')
    def right_click(self, name) -> ContextMenu:
        self._open_menu_button.real_name['objectName'] = 'savedAddressView_Delegate_menuButton' + '_' + name
        self._address_list_item.real_name['objectName'] = 'savedAddressView_Delegate' + '_' + name
        self._address_list_item.hover()
        self._open_menu_button.click()
        return ContextMenu().wait_until_appears()


class WalletAccountView(QObject):

    def __init__(self):
        super(WalletAccountView, self).__init__(settings_names.mainWindow_StatusSectionLayout_ContentItem)
        self._account_name_text_label = TextLabel(wallet_names.mainWallet_Account_Name)
        self._addresses_panel = QObject(names.mainWallet_Address_Panel)
        self._send_button = Button(wallet_names.mainWindow_Send_Button)
        self._receive_button = Button(wallet_names.mainWindow_Receive_Button)
        self._bridge_button = Button(wallet_names.mainWindow_Bridge_Button)
        self._filter_button = Button(wallet_names.filterButton_StatusFlatButton)
        self._assets_combobox = List(wallet_names.cmbTokenOrder_SortOrderComboBox)
        self._assets_tab_button = Button(wallet_names.rightSideWalletTabBar_Assets_StatusTabButton)
        self._collectibles_tab_button = Button(wallet_names.rightSideWalletTabBar_Collectibles_StatusTabButton)
        self._activity_tab_button = Button(wallet_names.rightSideWalletTabBar_Activity_StatusTabButton)
        self._collectibles_view = QObject(wallet_names.collectibles_view)
        self._activity_view = QObject(wallet_names.activity_view)
        self._asset_item_delegate = QObject(wallet_names.itemDelegate)
        self._asset_item = QObject(wallet_names.assets_viewTokenItem)
        self._arrow_icon = QObject(wallet_names.arrow_icon_StatusIcon)
        self.footer_swap_button = Button(wallet_names.mainWindow_Swap_Button)

    @property
    @allure.step('Get name of account')
    def name(self) -> str:
        return self._account_name_text_label.text

    @property
    @allure.step('Get address of account')
    def address(self) -> str:
        return str(self._addresses_panel.object.value)

    @allure.step('Open assets list')
    def open_assets_view(self):
        self.open_assets_tab(wait_until_loaded=True)
        return AssetsView().wait_until_appears()

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._account_name_text_label.wait_until_appears(timeout_msec)
        return self

    @allure.step('Open swap popup')
    def open_swap_popup(self) -> SwapPopup:
        self.footer_swap_button.click()
        return SwapPopup().wait_until_appears()

    @allure.step('Open send popup')
    def open_send_popup(self) -> SendPopup:
        self._send_button.click()
        return SendPopup().wait_until_appears()

    @allure.step('Open bridge popup')
    def open_bridge_popup(self) -> BridgePopup:
        self._bridge_button.click()
        return BridgePopup().wait_until_appears()

    @allure.step('Open receive popup')
    def open_receive_popup(self) -> ReceivePopup:
        self._receive_button.click()
        return ReceivePopup().wait_until_appears()

    @allure.step('Wait for assets tab content to finish loading')
    def wait_for_assets_tab_content_loaded(
        self,
        timeout_msec: int | None = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
    ):
        assets_tab_view = QObject(wallet_names.assets_tab_view)

        def assets_loaded():
            if _asset_items_finished_loading(self._asset_item):
                return True
            if not assets_tab_view.is_visible:
                return False
            return not getattr(assets_tab_view.object, 'loading', True)

        _wait_until(assets_loaded, timeout_msec, 'Assets tab did not finish loading')
        return self

    @allure.step('Wait for collectibles tab content to finish loading')
    def wait_for_collectibles_tab_content_loaded(
        self,
        timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        loading_timeout_msec: int | None = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
    ):
        self._collectibles_view.wait_until_appears(timeout_msec)
        _wait_until(
            lambda: not getattr(self._collectibles_view.object, 'isFetching', False)
            and not getattr(self._collectibles_view.object, 'isUpdating', False),
            loading_timeout_msec,
            'Collectibles tab did not finish loading',
        )
        return self

    @allure.step('Wait for History tab content to finish loading')
    def wait_for_activity_tab_content_loaded(
        self,
        timeout_msec: int | None = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
    ):
        _wait_until(
            lambda: is_activity_tab_content_loaded(self._activity_view),
            timeout_msec,
            'History tab did not finish loading',
        )
        return self

    @allure.step('Open assets tab')
    def open_assets_tab(
        self,
        timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        wait_until_loaded: bool = True,
        loading_timeout_msec: int | None = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
    ):
        self._assets_tab_button.click()
        assert driver.waitFor(
            lambda: self._assets_tab_button.is_checked,
            timeout_msec,
        ), 'Assets tab did not become selected'
        AssetsView().wait_until_appears(timeout_msec)
        if wait_until_loaded:
            self.wait_for_assets_tab_content_loaded(loading_timeout_msec)
        return self

    @allure.step('Open collectibles tab')
    def open_collectibles_tab(
        self,
        timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        wait_until_loaded: bool = True,
        loading_timeout_msec: int | None = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
    ):
        self._collectibles_tab_button.click()
        assert driver.waitFor(
            lambda: self._collectibles_tab_button.is_checked,
            timeout_msec,
        ), 'Collectibles tab did not become selected'
        if not wait_until_loaded:
            return self
        self.wait_for_collectibles_tab_content_loaded(timeout_msec, loading_timeout_msec)
        return self

    @allure.step('Open History tab')
    def open_activity_tab(
        self,
        timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        wait_until_loaded: bool = True,
        loading_timeout_msec: int | None = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
    ):
        self._activity_tab_button.click()
        assert driver.waitFor(
            lambda: self._activity_tab_button.is_checked,
            timeout_msec,
        ), 'History tab did not become selected'
        if wait_until_loaded:
            self.wait_for_activity_tab_content_loaded(loading_timeout_msec)
        else:
            self._activity_view.wait_until_appears(timeout_msec)
        return self

    @allure.step('Click filter button')
    def click_filter_button(self):
        self._filter_button.click()
        return self

    @allure.step('Get value from combobox')
    def get_combobox_value(self) -> str:
        return str(self._assets_combobox.object.displayText)

    @allure.step('Choose sort by value')
    def choose_sort_by_value(self, sort_by_value: str):
        self._assets_combobox.click()
        driver.mouseClick(self.get_sort_by_item_object(sort_by_value))

    @allure.step('Get sort by item')
    def get_sort_by_item_object(self, sort_by_value: str):
        for item in driver.findAllObjects(self._asset_item_delegate.real_name):
            if getattr(item, 'text', '') == sort_by_value:
                return item

    @allure.step('Click the arrow button')
    def click_arrow_button(self, arrow_name: str, occurrence: int):
        self._assets_combobox.click()
        self._arrow_icon.real_name['objectName'] = arrow_name
        if occurrence > 1:
            self._arrow_icon.real_name['occurrence'] = occurrence
        self._arrow_icon.click()

    @allure.step('Get list of assets')
    def get_list_of_assets(self) -> typing.List:
        time.sleep(1)
        token_list_items = []
        for item in driver.findAllObjects(self._asset_item.real_name):
            token_list_items.append(item)
        sorted(token_list_items, key=lambda item: item.y)
        return token_list_items

    @allure.step('Open asset context menu')
    def open_asset_context_menu(self, index: int):
        QObject(real_name=driver.objectMap.realName(self.get_list_of_assets()[index])).right_click()
        return AssetContextMenuPopup().wait_until_appears()

    @allure.step('Get list of collectibles')
    def get_list_of_collectibles(self) -> typing.List:
        time.sleep(1)
        token_list_items = []
        for item in driver.findAllObjects(self._collectible_item.real_name):
            token_list_items.append(item)
        sorted(token_list_items, key=lambda item: item.x)
        return token_list_items
