import allure

import configs.timeouts
import driver
from gui.components.wallet.send_popup import SendPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import settings_names


class ENSSettingsView(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_EnsWelcomeView)
        self._start_button = Button(settings_names.mainWindow_Start_StatusButton)

    @allure.step('Start purhasing ens username')
    def start(self):
        self._start_button.click()
        return ENSSearchView().wait_until_appears()


class ENSSearchView(QObject):

    def __init__(self):
        super(ENSSearchView, self).__init__(settings_names.mainWindow_EnsSearchView)
        self._username_text_field = TextEdit(settings_names.mainWindow_ensUsernameInput_StyledTextField)
        self._next_button = Button(settings_names.mainWindow_ensNextButton_StatusRoundButton)
        self._ens_text_note = QObject(settings_names.ens_StatusBaseText)

    @allure.step('Enter user name to text field')
    def enter_user_name(self, name: str):
        self._username_text_field.text = name
        return self._next_button.wait_until_appears()

    @allure.step('Click next button')
    def click_next_button(self):
        self._next_button.click()
        return ENSTermsAndConditionsView().wait_until_appears()

    @allure.step('Get all text notes from ens search view')
    def ens_text_notes(self):
        return [str(note.text) for note in driver.find_all(self._ens_text_note.real_name)]


class ENSTermsAndConditionsView(QObject):

    def __init__(self):
        super(ENSTermsAndConditionsView, self).__init__(settings_names.mainWindow_EnsTermsAndConditionsView)
        self._agree_terms_checkbox = TextEdit(settings_names.sview_ensAgreeTerms_StatusCheckBox)
        self._register_button = Button(settings_names.mainWindow_Register_StatusButton)

    @allure.step('Get registered button enabled state')
    def is_register_button_enabled(self) -> bool:
        return driver.wait_exists(self._register_button.real_name,
                                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC).enabled

    @allure.step('Register ens username')
    def register_ens_name(self, attempts: int = 3):
        last_exception = None
        for attempt in range(1, attempts + 1):
            try:
                self.check_agree_terms_checkbox()
                driver.wait_until(lambda: self.is_register_button_enabled(), configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
                self._register_button.click()
                popup = SendPopup().wait_until_appears()
                return popup
            except Exception as e:
                last_exception = e
                if attempt == attempts:
                    break
        raise Exception(f"Failed to register ENS name after {attempts} attempts: {last_exception}")

    @allure.step('Check agree terms checkbox')
    def check_agree_terms_checkbox(self):
        self._agree_terms_checkbox.click()


class ENSRegisteredView(QObject):

    def __init__(self):
        super(ENSRegisteredView, self).__init__(settings_names.mainWindow_EnsRegisteredView)
