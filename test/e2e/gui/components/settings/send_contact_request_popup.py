import allure

import configs
import driver
from constants.messaging import Messaging
from driver.objects_access import walk_children
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

    @property
    @allure.step('Check if send button is enabled')
    def is_send_button_enabled(self) -> bool:
        return driver.waitForObjectExists(
            self._send_button.real_name, configs.timeouts.UI_LOAD_TIMEOUT_MSEC
        ).enabled

    def _fill_form(self, chat_key: str, message: str):
        # Inner QQuickTextEdit is inside StatusBaseInput; driver.type() cannot set focus. Use direct assignment.
        self._chat_key_text_edit.set_text_property(chat_key)
        self._message_text_edit.set_text_property(message)

    @staticmethod
    def _tree_contains_text(root, text: str) -> bool:
        for child in walk_children(root):
            if text in str(getattr(child, 'text', '')):
                return True
        return False

    def _overlay_contains_text(self, text: str) -> bool:
        overlay = driver.waitForObjectExists(names.statusDesktop_mainWindow_overlay, 200)
        return self._tree_contains_text(overlay, text)

    @allure.step('Send contact request')
    def send(self, chat_key: str, message: str):
        self._fill_form(chat_key, message)
        assert driver.waitFor(
            lambda: self._send_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Send Contact Request button stayed disabled after filling fields'
        self._send_button.click()
        self.wait_until_hidden()

    @allure.step('Verify resending contact request is blocked')
    def verify_resend_blocked(self, chat_key: str, message: str):
        self._fill_form(chat_key, message)
        error_message = Messaging.CONTACT_REQUEST_ALREADY_SENT.value

        def resend_is_blocked():
            try:
                return not self.is_send_button_enabled and self._overlay_contains_text(error_message)
            except (LookupError, RuntimeError, AttributeError):
                return False

        assert driver.waitFor(
            resend_is_blocked,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), (
            f'Send Contact Request should stay disabled with {error_message!r} shown'
        )

    @allure.step('Close contact request modal')
    def close(self):
        driver.type(self.contact_request_to_chat_modal.object, '<Escape>')
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
