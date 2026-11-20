import allure

import configs
import driver
from gui.components.base_popup import BasePopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import names


class RespondToIDRequestPopup(BasePopup):

    def __init__(self):
        super().__init__()
        self._message_input = QObject(names.messageInput_StatusInput)
        self._answer_to_verification_request_field = TextEdit(names.edit_TextEdit)
        self._send_answer_button = Button(names.send_Answer_StatusButton)
        self._refuse_verification_button = Button(names.refuse_Verification_StatusButton)
        self._change_answer_button = Button(names.change_answer_StatusFlatButton)
        self._close_button = Button(names.close_StatusButton)

    @property
    @allure.step('Get message note from identity verification request')
    def message_note(self) -> str:
        return str(self._message_input.object.placeholderText)

    @property
    @allure.step('Get send answer button enabled state')
    def is_send_answer_button_enabled(self) -> bool:
        return driver.wait_exists(self._send_answer_button.real_name,
                                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC).enabled

    @property
    @allure.step('Get change answer button visible state')
    def is_change_answer_button_visible(self) -> bool:
        return self._change_answer_button.is_visible

    @allure.step('Click send answer button')
    def send_answer(self):
        self._send_answer_button.click()

    @allure.step('Type message in verification answer')
    def type_message(self, value: str):
        self._answer_to_verification_request_field.text = value
        return self

    @allure.step('Close identification answer popup')
    def close(self):
        self._close_button.click()
