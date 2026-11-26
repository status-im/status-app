import allure

import configs
import driver
from gui.components.base_popup import BasePopup
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import names


class VerifyIdentityPopup(BasePopup):

    def __init__(self):
        super().__init__()
        self._message_input = QObject(names.messageInput_StatusInput)
        self._identity_verification_text_field = TextEdit(names.profileSendContactRequestModal_sayWhoYouAreInput_TextEdit)
        self._send_verification_button = TextEdit(names.send_verification_request_StatusButton)

    @property
    @allure.step('Get message note from identity verification request')
    def message_note(self) -> str:
        return str(self._message_input.object.label)

    @property
    @allure.step('Get send verification button enabled state')
    def is_send_verification_button_enabled(self) -> bool:
        return driver.wait_exists(self._send_verification_button.real_name,
                                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC).enabled

    @allure.step('Click send verification button')
    def send_verification(self):
        self._send_verification_button.click()
        self.wait_until_hidden()
        return self

    @allure.step('Type message in verification request')
    def type_message(self, value: str):
        self._identity_verification_text_field.text = value
        return self
