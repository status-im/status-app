import allure

import configs.timeouts
from gui.components.settings.keycard_popup import KeycardPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.elements.text_label import TextLabel
from gui.objects_map import settings_names


class KeycardSettingsView(QObject):

    def __init__(self):
        super(KeycardSettingsView, self).__init__(settings_names.mainWindow_KeycardView)
        self._scroll = Scroll(settings_names.settingsContentBase_ScrollView)
        self._setup_keycard_with_existing_account_button = Button(settings_names.setupFromExistingKeycardAccount_StatusListItem)
        self._create_new_keycard_account_button = Button(settings_names.createNewKeycardAccount_StatusListItem)
        self._import_restore_via_seed_phrase_button = Button(settings_names.importRestoreKeycard_StatusListItem)
        self._import_from_keycard_button = Button(settings_names.importFromKeycard_StatusListItem)
        self._check_whats_on_keycard_button = Button(settings_names.checkWhatsNewKeycard_StatusListItem)
        self._factory_reset_keycard_button = Button(settings_names.factoryResetKeycard_StatusListItem)
        self._get_keycard_button = Button(settings_names.get_keycard_StatusButton)
        self._read_keycard_button = Button(settings_names.read_keycard_StatusButton)
        self._main_view_description = TextLabel(settings_names.keycard_main_view_description_StatusBaseText)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._get_keycard_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Check that keycard screen displayed')
    def check_keycard_screen_loaded(self):
        assert KeycardSettingsView().is_visible

    @allure.step('Choose create new keycard account with new seed phrase')
    def click_create_new_account_with_new_seed_phrase(self):
        self._create_new_keycard_account_button.click()
        return KeycardPopup().wait_until_appears()

    @allure.step('Choose import or restore keycard via seed phrase')
    def click_import_restore_via_seed_phrase(self):
        self._scroll.vertical_scroll_down(self._import_restore_via_seed_phrase_button)
        self._import_restore_via_seed_phrase_button.click()
        return KeycardPopup().wait_until_appears()

    @allure.step('Choose setup keycard with an existing account')
    def click_setup_keycard_with_existing_account(self):
        self._scroll.vertical_scroll_down(self._setup_keycard_with_existing_account_button)
        self._setup_keycard_with_existing_account_button.click()
        return KeycardPopup().wait_until_appears()

    @allure.step('Choose check whats on keycard')
    def click_check_whats_on_keycard(self):
        self._scroll.vertical_scroll_down(self._check_whats_on_keycard_button)
        self._check_whats_on_keycard_button.click()
        return KeycardPopup().wait_until_appears()

    @allure.step('Choose factory reset a keycard')
    def click_factory_reset_keycard(self):
        self._scroll.vertical_scroll_down(self._factory_reset_keycard_button)
        self._factory_reset_keycard_button.click()
        return KeycardPopup().wait_until_appears()

    @allure.step('Check that main keycard screen elements are displayed')
    def all_keycard_options_available(self):
        assert self._get_keycard_button.is_visible, 'Get Keycard button not visible'
        assert self._read_keycard_button.is_visible, 'Read Keycard button not visible'
        assert self._main_view_description.is_visible, 'Keycard main view description not visible'
        assert self._main_view_description.text == 'Secure your funds. Keep your profile safe.'
