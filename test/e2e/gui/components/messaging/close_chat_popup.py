import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class CloseChatPopup(QObject):

    def __init__(self):
        super().__init__(names.confirmationDialog)
        self._close_chat_button = Button(names.close_chat_StatusButton)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._close_chat_button.wait_until_appears(timeout_msec)
        return self

    @allure.step("Confirm closing chat")
    def confirm_closing_chat(self):
        self._close_chat_button.wait_until_appears()
        self._close_chat_button.wait_until_enabled()
        self._close_chat_button.click()
        self._close_chat_button.wait_until_hidden()
