import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import names


class SendContactRequest(QObject):

    def __init__(self):
        super().__init__(names.contactRequestToChatKeyModal)
        self.contact_request_to_chat_modal = QObject(names.contactRequestToChatKeyModal)
        self._chat_key_text_edit = TextEdit(names.sendContactRequestModal_ChatKey_Input_TextEdit)
        self._message_text_edit = TextEdit(names.sendContactRequestModal_SayWhoYouAre_Input_TextEdit)
        self._send_button = Button(names.send_Contact_Request_StatusButton)

    @allure.step('Send contact request')
    def send(self, chat_key: str, message: str):
        # Inner QQuickTextEdit is inside StatusBaseInput; driver.type() cannot set focus. Use direct assignment.
        self._chat_key_text_edit.set_text_property(chat_key)
        self._message_text_edit.set_text_property(message)
        assert driver.waitFor(
            lambda: self._send_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Send Contact Request button stayed disabled after filling fields'
        self._send_button.click()
        self.wait_until_hidden()


class SendContactRequestFromProfile(QObject):

    def __init__(self):
        super().__init__(names.sendContactRequestModal)
        self._message_text_edit = TextEdit(names.profileSendContactRequestModal_sayWhoYouAreInput_TextEdit)
        self._send_button = Button(names.send_contact_request_StatusButton_2)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._message_text_edit.wait_until_appears(timeout_msec)
        return self

    @allure.step('Send contact request')
    def send(self, message: str):
        self._message_text_edit.set_text_property(message)
        self._send_button.click()
