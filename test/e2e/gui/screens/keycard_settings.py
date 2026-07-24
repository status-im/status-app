import allure

import configs
import constants
import driver
from gui.components.keycard.management_popup import KeycardManagementPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_label import TextLabel
from gui.objects_map import keycard_names


class KeycardSettingsView(QObject):

    def __init__(self):
        super().__init__(keycard_names.mainWindow_KeycardView)
        self._read_keycard_button = Button(keycard_names.settings_Keycard_ReadKeycardButton)
        self._details_title = TextLabel(keycard_names.keycardSettingsDetailsTitle)
        self._key_pair_info = QObject(keycard_names.keycardSettingsKeyPairInfo)

    @property
    def is_read_keycard_button_visible(self) -> bool:
        return self._read_keycard_button.is_visible

    @property
    def details_title(self) -> str:
        return self._details_title.text

    @property
    def key_pair_location(self) -> str:
        return str(getattr(self._key_pair_info.object, 'subTitle', ''))

    @allure.step('Wait until keycard settings view appears')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._read_keycard_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Open Read Keycard flow')
    def open_read_keycard(self) -> KeycardManagementPopup:
        self._read_keycard_button.click()
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Wait until Keycard profile details appear')
    def wait_until_details_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        assert driver.waitFor(
            lambda: self.details_title == constants.KEYCARD_PROFILE_DETAILS_TITLE,
            timeout_msec,
        ), f'Expected Keycard profile details title, got {self.details_title!r}'
        self._key_pair_info.wait_until_appears(timeout_msec)
        assert driver.waitFor(
            lambda: constants.KEYCARD_ON_KEYCARD_LABEL in self.key_pair_location,
            timeout_msec,
        ), f'Expected On Keycard label, got {self.key_pair_location!r}'
        return self
