import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class PinnedMessagesPopup(QObject):

    def __init__(self):
        super().__init__(names.pinnedMessagesPopup)
        self._close_button = Button(names.headerActionsCloseButton_StatusFlatRoundButton)
        self._unpin_button = Button(names.unpinButton_StatusFlatRoundButton)
        self._pinned_message_details = QObject(names.pinMessageDetails)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._pinned_message_details.wait_until_appears(timeout_msec)
        return self

    @allure.step('Unpin message')
    def unpin_message(self):
        self._pinned_message_details.hover()
        self._unpin_button.click()
        return self

    @allure.step('Close pinned messages popup')
    def close(self):
        self._close_button.click()
        self._pinned_message_details.wait_until_hidden()
