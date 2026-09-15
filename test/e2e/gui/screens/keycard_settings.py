import allure

import configs
import constants
import driver
from gui.components.keycard.management_popup import KeycardManagementPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_label import TextLabel
from gui.objects_map import keycard_names, settings_names


class KeycardSettingsView(QObject):

    def __init__(self):
        super().__init__(keycard_names.mainWindow_KeycardView)
        self._read_keycard_button = Button(keycard_names.settings_Keycard_ReadKeycardButton)
        self._details_title = TextLabel(keycard_names.keycardSettingsDetailsTitle)
        self._details_info = TextLabel(keycard_names.keycardSettingsDetailsInfo)
        self._key_pair_info = QObject(keycard_names.keycardSettingsKeyPairInfo)
        self._import_seed_phrase_item = Button(keycard_names.settingsKeycardDetailsImportSeedPhrase)
        self._import_new_keypair_item = Button(keycard_names.settingsKeycardDetailsImportNewKeypair)
        self._move_profile_keypair_item = Button(keycard_names.settingsKeycardDetailsMoveProfileKeypair)
        self._factory_reset_item = Button(keycard_names.settingsKeycardDetailsFactoryReset)
        self._unblock_puk_item = Button(keycard_names.settingsKeycardDetailsUnblockPuk)
        self._unblock_recovery_item = Button(keycard_names.settingsKeycardDetailsUnblockRecovery)
        self._set_or_change_puk_item = Button(keycard_names.settingsKeycardDetailsSetOrChangePuk)
        self._back_button = Button(settings_names.main_toolBar_back_button)

    @property
    def is_read_keycard_button_visible(self) -> bool:
        return self._read_keycard_button.is_visible

    @property
    def details_title(self) -> str:
        return self._details_title.text

    @property
    def details_info(self) -> str:
        return self._details_info.text

    @property
    def is_unblock_puk_visible(self) -> bool:
        return self._unblock_puk_item.is_visible

    @property
    def is_unblock_recovery_visible(self) -> bool:
        return self._unblock_recovery_item.is_visible

    @property
    def key_pair_location(self) -> str:
        return str(getattr(self._key_pair_info.object, 'subTitle', ''))

    @allure.step('Wait until keycard settings view appears')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._read_keycard_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Go back to Keycard settings main screen')
    def go_back_to_main(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        if self.is_read_keycard_button_visible:
            return self
        self._back_button.wait_until_appears(timeout_msec)
        self._back_button.click()
        self._read_keycard_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Open Read Keycard flow')
    def open_read_keycard(self) -> KeycardManagementPopup:
        self.go_back_to_main()
        self._read_keycard_button.click()
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Wait until Keycard details appear')
    def wait_until_details_appears(
            self,
            expected_title: str = constants.KEYCARD_PROFILE_DETAILS_TITLE,
            timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
    ):
        assert driver.waitFor(
            lambda: self.details_title == expected_title,
            timeout_msec,
        ), f'Expected Keycard details title {expected_title!r}, got {self.details_title!r}'
        if expected_title in (constants.KEYCARD_EMPTY_TITLE, constants.KEYCARD_BLOCKED_TITLE):
            return self
        self._key_pair_info.wait_until_appears(timeout_msec)
        assert driver.waitFor(
            lambda: constants.KEYCARD_ON_KEYCARD_LABEL in self.key_pair_location,
            timeout_msec,
        ), f'Expected On Keycard label, got {self.key_pair_location!r}'
        return self

    @allure.step('Import a key pair from recovery phrase')
    def import_from_recovery_phrase(self) -> KeycardManagementPopup:
        self._import_seed_phrase_item.click()
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Import a new key pair to Keycard')
    def import_new_keypair(self) -> KeycardManagementPopup:
        self._import_new_keypair_item.click()
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Move profile key pair to Keycard')
    def move_profile_keypair(self) -> KeycardManagementPopup:
        self._move_profile_keypair_item.click()
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Factory reset Keycard')
    def factory_reset(self) -> KeycardManagementPopup:
        self._factory_reset_item.click()
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Set or change Keycard PUK')
    def set_or_change_puk(self) -> KeycardManagementPopup:
        self._set_or_change_puk_item.wait_until_appears()
        self._set_or_change_puk_item.click()
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Unblock Keycard with PUK')
    def unblock_with_puk(self) -> KeycardManagementPopup:
        self._unblock_puk_item.wait_until_appears()
        self._unblock_puk_item.click()
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Wait until blocked Keycard details appear')
    def wait_until_blocked_details_appear(
            self,
            timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
    ):
        self.wait_until_details_appears(constants.KEYCARD_BLOCKED_TITLE, timeout_msec)
        assert driver.waitFor(
            lambda: self.details_info == constants.KEYCARD_BLOCKED_PIN_MESSAGE,
            timeout_msec,
        ), (
            f'Expected blocked PIN message {constants.KEYCARD_BLOCKED_PIN_MESSAGE!r}, '
            f'got {self.details_info!r}'
        )
        self._unblock_puk_item.wait_until_appears(timeout_msec)
        self._unblock_recovery_item.wait_until_appears(timeout_msec)
        return self
