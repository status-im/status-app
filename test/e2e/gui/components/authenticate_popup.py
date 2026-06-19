import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import names


class AuthenticatePopup(QObject):

    def __init__(self):
        super().__init__(names.authenticatePopup)
        self._password_text_edit = TextEdit(names.authenticate_keycardPasswordInput)
        self._authenticate_button = Button(names.authenticate_StatusButton)
        self._primary_button = Button(names.sharedPopup_Primary_Button)
        self._close_button = Button(names.headerCloseButton_StatusFlatRoundButton)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._password_text_edit.wait_until_appears(timeout_msec)
        return self

    @allure.step('Authenticate actions with password {0}')
    def authenticate(self, password: str):
        self._password_text_edit.set_text_property(password)
        # TODO https://github.com/status-im/status-app/issues/15345
        self._primary_button.click()
        self.wait_until_hidden(timeout_msec=10000)

    @allure.step('Check if authenticate button is present')
    def is_authenticate_button_visible(self):
        return self._primary_button.is_visible

    @allure.step('Close authenticate popup by close button')
    def close_authenticate_popup(self):
        self._close_button.click()
