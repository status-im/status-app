import allure

import configs.system
from gui.components.back_up_your_seed_phrase_popup import BackUpYourSeedPhrasePopUp
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.objects_map import settings_names
from gui.screens.settings_advanced import AdvancedSettingsView
from gui.screens.settings_communities import CommunitiesSettingsView
from gui.screens.settings_ens_usernames import ENSSettingsView
from gui.screens.settings_messaging import MessagingSettingsView
from gui.screens.settings_profile import ProfileSettingsView
from gui.screens.settings_syncing import SyncingSettingsView
from gui.screens.settings_wallet import WalletSettingsView
from gui.screens.settings_password import ChangePasswordView
from gui.screens.keycard_settings import KeycardSettingsView
from gui.components.settings.sign_out_popup import SignOutPopup

from scripts.utils.decorators import retry_settings


class SettingsLeftPanel(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_LeftTabView)
        self.settings_section_template = QObject(settings_names.mainWindow_settingsList_SettingsListItem)
        self.scroll = Scroll(settings_names.mainWindow_settingsList_VerticalScroll)
        self.settings_section_back_up_seed_option = QObject(settings_names.settingsBackUpSeedPhraseOption)

    def _open_settings(self, object_name: str):
        self.settings_section_template.real_name['objectName'] = object_name
        if not self.settings_section_template.is_visible:
            self.scroll.vertical_scroll_down(self.settings_section_template)
        self.settings_section_template.click()

    @allure.step('Choose back up seed phrase in settings')
    @retry_settings(BackUpYourSeedPhrasePopUp, '19-MenuItem')
    def open_back_up_seed_phrase(self) -> 'BackUpYourSeedPhrasePopUp':
        return BackUpYourSeedPhrasePopUp().wait_until_appears()

    @allure.step('Open wallet settings')
    @retry_settings(WalletSettingsView, '5-MenuItem')
    def open_wallet_settings(self) -> 'WalletSettingsView':
        return WalletSettingsView().wait_until_appears()

    @allure.step('Open messaging settings')
    @retry_settings(MessagingSettingsView, '4-MenuItem')
    def open_messaging_settings(self) -> 'MessagingSettingsView':
        return MessagingSettingsView().wait_until_appears()

    @allure.step('Open communities settings')
    @retry_settings(CommunitiesSettingsView, '13-MenuItem')
    def open_communities_settings(self) -> 'CommunitiesSettingsView':
        return CommunitiesSettingsView().wait_until_appears()

    @allure.step('Open profile settings')
    @retry_settings(ProfileSettingsView, '0-MenuItem')
    def open_profile_settings(self) -> 'ProfileSettingsView':
        return ProfileSettingsView().wait_until_appears()

    @allure.step('Open password settings')
    @retry_settings(ChangePasswordView, '1-MenuItem')
    def open_password_settings(self) -> 'ChangePasswordView':
        return ChangePasswordView().wait_until_appears()

    @allure.step('Open syncing settings')
    @retry_settings(SyncingSettingsView, '9-MenuItem')
    def open_syncing_settings(self) -> 'SyncingSettingsView':
        return SyncingSettingsView().wait_until_appears()

    @allure.step('Choose sign out and quit in settings')
    @retry_settings(SignOutPopup, '100-MenuItem')
    def open_sign_out_and_quit(self) -> 'SignOutPopup':
        return SignOutPopup().wait_until_appears()

    @allure.step('Open ENS usernames settings')
    @retry_settings(ENSSettingsView, '3-MenuItem')
    def open_ens_usernames_settings(self) -> 'ENSSettingsView':
        return ENSSettingsView().wait_until_appears()

    @allure.step('Open advanced settings')
    @retry_settings(AdvancedSettingsView, '11-MenuItem')
    def open_advanced_settings(self) -> 'AdvancedSettingsView':
        return AdvancedSettingsView().wait_until_appears()

    @allure.step('Open keycard settings')
    @retry_settings(KeycardSettingsView, '14-MenuItem')
    def open_keycard_settings(self) -> 'KeycardSettingsView':
        return KeycardSettingsView().wait_until_appears()


class SettingsScreen(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_ProfileLayout)
        self.left_panel = SettingsLeftPanel().wait_until_appears()
