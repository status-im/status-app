import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names
from helpers.chat_helper import plain_text_from_message_object


class PinnedMessagesPanel(QObject):

    def __init__(self):
        super().__init__(names.chatInfoPinsList)
        self._info_button = Button(names.chatToolbar_infoButton)
        self._unpin_menu_item = Button(names.pinnedMessagesPanel_unpin)
        self._pinned_message_details = QObject(names.pinMessageDetails_in_pinsPanel)
        self._message_view = QObject(names.pinPanel_messageView)

    @allure.step('Wait until pinned message is listed')
    def wait_for_message(
            self,
            message_text: str,
            timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
    ):
        def listed() -> bool:
            for obj in driver.findAllObjects(self._message_view.real_name):
                if message_text in plain_text_from_message_object(obj):
                    return True
            return False

        if not driver.waitFor(listed, timeout_msec):
            raise TimeoutError(
                f'Pinned message {message_text!r} was not listed within {timeout_msec} ms'
            )
        return self

    @allure.step('Unpin message')
    def unpin_message(self):
        self._pinned_message_details.wait_until_appears()
        self._pinned_message_details.right_click()
        self._unpin_menu_item.wait_until_appears().click()
        return self

    @allure.step('Close pinned messages panel')
    def close(self):
        self._info_button.click()
        self.wait_until_hidden()
