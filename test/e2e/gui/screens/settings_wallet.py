import typing

import allure

import configs.timeouts
import driver
from constants.wallet import (
    TokenListItem,
    WalletAccountListItem,
)
from driver import objects_access
from driver.objects_access import walk_children
from gui.components.context_menu import ContextMenu
from gui.components.settings.rename_keypair_popup import RenameKeypairPopup
from gui.components.wallet.remove_saved_address_popup import RemoveSavedAddressPopup
from gui.components.wallet.add_saved_address_popup import AddEditSavedAddressPopup
from gui.components.wallet.delete_account_confirmation_popup import RemoveAccountWithConfirmation
from gui.components.wallet.testnet_mode_popup import TestnetModePopup

from gui.components.wallet.wallet_account_popups import AccountPopup, EditAccountFromSettingsPopup
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.elements.text_label import TextLabel
from gui.objects_map import settings_names, wallet_names


class WalletSettingsView(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_WalletView)
        self.scroll = Scroll(settings_names.settingsContentBase_ScrollView)
        self.wallet_settings_add_new_account_button = Button(
            settings_names.settings_Wallet_MainView_AddNewAccountButton)
        self.wallet_network_button = Button(settings_names.settings_Wallet_MainView_Networks)
        self.wallet_manage_tokens_button = Button(settings_names.settings_Wallet_MainView_Manage_Tokens)
        self.account_order_button = Button(
            settings_names.settingsContentBaseScrollView_accountOrderItem_StatusListItem)
        self.saved_addresses_button = Button(
            settings_names.settingsContentBaseScrollView_savedAddressesItem_StatusListItem)
        self.status_account_in_keypair = QObject(settings_names.settingsWalletAccountDelegate_Status_account)
        self.wallet_account_from_keypair = QObject(settings_names.settingsWalletAccountDelegate)
        self.wallet_settings_keypair_item = QObject(settings_names.settingsWalletKeyPairDelegate)
        self.wallet_settings_total_balance_item = QObject(settings_names.settingsWalletAccountTotalBalance)
        self.wallet_settings_total_balance_toggle = CheckBox(settings_names.settingsWalletAccountTotalBalanceToggle)
        self.rename_keypair_menu_item = QObject(settings_names.rename_keypair_StatusMenuItem)

    @allure.step('Open add account pop up in wallet settings')
    def open_add_account_pop_up(self, attempts: int = 3) -> 'AccountPopup':
        for _ in range(attempts):
            try:
                self.wallet_settings_add_new_account_button.click()
                return AccountPopup()
            except Exception:
                pass  # retry one more time
        raise LookupError(f"Failed to open add account popup in settings")

    @allure.step('Open saved addresses in wallet settings')
    def open_saved_addresses(self, attempts: int = 3) -> 'SavedAddressesWalletSettings':
        for _ in range(attempts):
            try:
                self.saved_addresses_button.click()
                return SavedAddressesWalletSettings().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f"Failed to open saved addresses popup in settings")

    @allure.step('Open networks in wallet settings')
    def open_networks(self, attempts: int = 3) -> 'NetworkWalletSettings':
        for _ in range(attempts):
            try:
                self.wallet_network_button.click()
                return NetworkWalletSettings().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f"Failed to open Networks in settings")

    @allure.step('Open manage tokens in wallet settings')
    def open_manage_tokens(self, attempts: int = 3) -> 'ManageTokensSettingsView':
        for _ in range(attempts):
            try:
                self.wallet_manage_tokens_button.click()
                return ManageTokensSettingsView().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Manage tokens view did not show up after {attempts} retries')

    @allure.step('Open account order in wallet settings')
    def open_account_order(self, attempts: int = 2):
        self.account_order_button.click()
        try:
            return EditAccountOrderSettings().wait_until_appears()
        except Exception as err:
            if attempts:
                return self.open_account_order(attempts - 1)
            else:
                raise err

    @allure.step('Get keypair settings_names')
    def get_keypairs_names(self):
        keypair_names = []
        for item in driver.findAllObjects(self.wallet_settings_keypair_item.real_name):
            keypair_names.append(str(getattr(item, 'title', '')))
        if len(keypair_names) == 0:
            raise LookupError(
                'No keypairs found on the wallet settings screen')
        else:
            return keypair_names

    @allure.step('Open account view in wallet settings by name')
    def open_account_in_settings(self, name: str, index: int, attempts: int = 3):
        self.wallet_account_from_keypair.real_name['objectName'] = name
        self.wallet_account_from_keypair.real_name['index'] = index
        for _ in range(attempts):
            try:
                self.wallet_account_from_keypair.click()
                return AccountDetailsView().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Account details view did not show up with {attempts} retries')

    @allure.step('Interact with the total balance toggle')
    def toggle_total_balance(self, value: bool):
        self.wallet_settings_total_balance_toggle.set(value)

    @allure.step('Click open menu button')
    def click_open_menu_button(self, title: str):
        for item in driver.findAllObjects(self.wallet_settings_keypair_item.real_name):
            if str(getattr(item, 'title', '')) == title:
                for child in walk_children(item):
                    if getattr(child, 'objectName', '') == 'more-icon':
                        more_button = QObject(real_name=driver.objectMap.realName(child))
                        self.scroll.vertical_scroll_down(more_button)
                        more_button.click()
                        break

    @allure.step('Choose rename keypair option')
    def click_rename_keypair(self):
        self.rename_keypair_menu_item.click()
        return RenameKeypairPopup().wait_until_appears()


class AccountDetailsView(QObject):
    def __init__(self):
        super().__init__(settings_names.walletAccountViewDetailsLabel)
        self._back_button = Button(settings_names.main_toolBar_back_button)
        self._edit_account_button = Button(settings_names.walletAccountViewEditAccountButton)
        self._remove_account_button = Button(settings_names.walletAccountViewRemoveAccountButton)
        self._wallet_account_title = TextLabel(settings_names.walletAccountViewAccountName)
        self._wallet_account_emoji = QObject(settings_names.walletAccountViewAccountEmoji)
        self._wallet_account_details_label = TextLabel(settings_names.walletAccountViewDetailsLabel)
        self._wallet_account_balance = QObject(settings_names.walletAccountViewBalance)
        self._wallet_account_keypair_item = QObject(settings_names.walletAccountViewKeypairItem)
        self._wallet_account_address = QObject(settings_names.walletAccountViewAddress)
        self._wallet_account_origin = TextLabel(settings_names.walletAccountViewOrigin)
        self._wallet_account_derivation_path = QObject(settings_names.walletAccountViewDerivationPath)
        self._wallet_account_stored = TextLabel(settings_names.walletAccountViewStored)
        self._wallet_preferred_networks = QObject(settings_names.walletAccountViewPreferredNetworks)
        self.scroll = Scroll(settings_names.settingsContentBase_ScrollView)

    @allure.step('Click Edit button')
    def open_edit_account_popup(self, attempts: int = 3):
        for _ in range(attempts):
            try:
                self._edit_account_button.click()
                return EditAccountFromSettingsPopup().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Edit account popup did not show up after {attempts} retries')

    @allure.step('Click Remove account button')
    def open_remove_account_with_confirmation_popup(self, attempts: int = 3):
        for _ in range(attempts):
            try:
                self._remove_account_button.click()
                return RemoveAccountWithConfirmation().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Remove account popup did not show up after {attempts} retries')

    @allure.step('Get account name')
    def get_account_name_value(self):
        return self._wallet_account_title.text

    @allure.step('Get account balance value')
    def get_account_balance_value(self):
        balance = str(getattr(self._wallet_account_balance.object, 'subTitle'))[:-4]
        return balance

    @allure.step("Get account address value")
    def get_account_address_value(self):
        self._wallet_account_details_label.wait_until_appears()
        self.scroll.vertical_scroll_down(
            self._wallet_account_address,
            timeout_sec=configs.timeouts.UI_LOAD_TIMEOUT_MSEC // 1000,
        )
        raw_value = str(getattr(self._wallet_account_address.object, 'subTitle'))
        address = raw_value.split(">")[-1]
        return address

    @allure.step('Get account color value')
    def get_account_color_value(self):
        color_name = str(getattr(self._wallet_account_title.object, 'color')['name'])
        return color_name

    @allure.step('Get account emoji id')
    def get_account_emoji_id(self):
        emoji_id = str(getattr(self._wallet_account_emoji.object, 'emojiId'))
        return emoji_id

    @allure.step('Get account origin value')
    def get_account_origin_value(self):
        return str(getattr(self._wallet_account_origin.object, 'subTitle'))

    @allure.step('Get account derivation path value')
    def get_account_derivation_path_value(self):
        return str(getattr(self._wallet_account_derivation_path.object, 'subTitle'))

    @allure.step('Get derivation path visibility')
    def is_derivation_path_visible(self):
        return self._wallet_account_derivation_path.is_visible

    @allure.step('Get account storage value')
    def get_account_storage_value(self):
        raw_value = str(getattr(self._wallet_account_stored.object, 'subTitle'))
        storage = raw_value.split(">")[-1]
        return storage

    @allure.step('Get account storage visibility')
    def is_account_storage_visible(self):
        return self._wallet_account_stored.is_visible

    @allure.step('Click back button')
    def click_back_button(self):
        self._back_button.click()


class SavedAddressesWalletSettings(QObject):
    def __init__(self):
        super().__init__(settings_names.settingsWallet_View)
        self.add_new_address_button = Button(settings_names.settings_Wallet_SavedAddresses_AddAddressButton)
        self.saved_address_item = QObject(settings_names.settings_Wallet_SavedAddress_ItemDelegate)
        self.saved_address_item_kebab_button = Button(settings_names.savedAddressItemKebabButton)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.add_new_address_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Click add new address button')
    def open_add_edit_saved_address_popup(self, attempts: int = 3) -> 'AddEditSavedAddressPopup':
        for _ in range(attempts):
            try:
                self.add_new_address_button.click()
                return AddEditSavedAddressPopup()
            except Exception:
                pass
        raise LookupError(f'Add saved address popup was not displayed within {attempts} attempts')

    @allure.step('Get saved addresses settings_names list')
    def get_saved_address_names_list(self):
        settings_names = [str(address.name) for address in driver.findAllObjects(self.saved_address_item.real_name)]
        return settings_names

    @allure.step("Open context menu for saved address item")
    def open_context_menu_for_saved_address(self, address_name) -> 'ContextMenu':
        for _ in range(2):
            try:
                self.saved_address_item.real_name['objectName'] = "savedAddressView_Delegate_" + address_name
                self.saved_address_item.hover()
                self.saved_address_item_kebab_button.real_name[
                    'objectName'] = 'savedAddressView_Delegate_menuButton_' + address_name
                self.saved_address_item_kebab_button.click()
                return ContextMenu().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Could not open context menu for saved address with 2 retries')

    @allure.step('Open Remove saved address popup')
    def open_delete_saved_address_confirmation_popup(self, address_name) -> 'RemoveSavedAddressPopup':
        context = self.open_context_menu_for_saved_address(address_name=address_name)
        context.delete_saved_address_from_context.click()
        return RemoveSavedAddressPopup().wait_until_appears()

    @allure.step('Confirm delete')
    def delete_saved_address_with_confirmation(self, account_name):
        confirmation = self.open_delete_saved_address_confirmation_popup(account_name)
        confirmation.remove_saved_address_button.click()
        confirmation.wait_until_hidden()
        return self


class NetworkWalletSettings(WalletSettingsView):

    def __init__(self):
        super().__init__()
        self.testnet_mode_toggle = Button(settings_names.settings_Wallet_NetworksView_TestNet_Toggle)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self):
        self.testnet_mode_toggle.wait_until_appears(configs.timeouts.FEES_TIMEOUT_MSEC)
        return self

    @allure.step('Switch testnet mode toggle')
    def switch_testnet_mode_toggle(self) -> 'TestnetModePopup':
        for _ in range(3):
            self.testnet_mode_toggle.click()
            try:
                return TestnetModePopup().wait_until_appears()
            except Exception:
                pass
        raise LookupError(f'Could not open testnet mode popup')


class EditAccountOrderSettings(WalletSettingsView):

    def __init__(self):
        super(EditAccountOrderSettings, self).__init__()
        self._account_item = QObject(
            settings_names.settingsContentBaseScrollView_draggableDelegate_StatusDraggableListItem)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._account_item.wait_until_appears(timeout_msec)
        return self

    @property
    @allure.step('Get accounts')
    def accounts(self) -> typing.List[WalletAccountListItem]:
        _accounts = []
        for account_item in driver.findAllObjects(self._account_item.real_name):
            element = QObject(real_name=driver.objectMap.realName(account_item))
            name = str(account_item.title)
            icon_color = None
            icon_emoji = None
            for child in objects_access.walk_children(account_item):
                if getattr(child, 'objectName', '') == 'identicon':
                    icon_color = str(child.color.name)
                    icon_emoji = str(child.emoji)
                    break
            _accounts.append(WalletAccountListItem(name, icon_color, icon_emoji, element))

        return sorted(_accounts, key=lambda account: account.object.y)

    @allure.step('Get account in accounts list')
    def _get_account_item(self, name: str):
        for obj in driver.findAllObjects(self._account_item.real_name):
            if getattr(obj, 'title', '') == name:
                return obj
        raise LookupError(f'Account item: {name} not found')

    @allure.step('Get eye icon on watch-only account')
    def get_eye_icon(self, name: str):
        for child in objects_access.walk_children(self._get_account_item(name)):
            if getattr(child, 'objectName', '') == 'show-icon':
                return child
        raise LookupError(f'Eye icon not found on {name} account item')


class ManageTokensSettingsView(WalletSettingsView):

    def __init__(self):
        super(ManageTokensSettingsView, self).__init__()
        self._window_item = QObject(wallet_names.statusDesktop_mainWindow)
        self._token_item = QObject(wallet_names.settingsContentBaseScrollView_manageTokensDelegate_ManageTokensDelegate)
        self._assets_button = Button(wallet_names.tabBar_Assets_StatusTabButton)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._assets_button.wait_until_appears(timeout_msec)
        return self

    @property
    @allure.step('Get tokens')
    def tokens(self) -> typing.List[TokenListItem]:
        _tokens = []
        for token_item in driver.findAllObjects(self._token_item.real_name):
            element = QObject(real_name=driver.objectMap.realName(token_item))
            name = str(token_item.title)
            _tokens.append(TokenListItem(name, element))

        return sorted(_tokens, key=lambda token: token.object.y)

    @allure.step('Drag token to change the order')
    def drag_token(self, name: str, index: int):
        assert driver.waitFor(lambda: len([token for token in self.tokens if token.title == name]) == 1), \
            'Token not found or found more then one'
        bounds = [token for token in self.tokens if token.title == name][0].object.bounds
        d_bounds = self.tokens[index].object.bounds
        driver.mouse.press_and_move(self._window_item.object, bounds.x, bounds.y, d_bounds.x, d_bounds.y + 1)
