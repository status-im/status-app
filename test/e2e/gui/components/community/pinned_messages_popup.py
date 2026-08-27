import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class PinnedMessagesPopup(QObject):

    def __init__(self):
        super().__init__(names.pinnedMessagesPopup)
        self._close_button = Button(names.headerActionsCloseButton_StatusFlatRoundButton)
        self._context_menu = QObject(names.contextMenu_PopupItem)
        self._unpin_menu_item = Button(names.pinnedMessagesPopup_unpin_StatusMenuItem)
        self._pinned_message_details = QObject(names.pinMessageDetails_in_pinnedPopup)

    @allure.step('Unpin message')
    def unpin_message(self):
        self._pinned_message_details.wait_until_appears()
        self._pinned_message_details.right_click()
        self._context_menu.wait_until_appears()
        self._unpin_menu_item.wait_until_appears().click()
        return self

    @allure.step('Close pinned messages popup')
    def close(self):
        self._close_button.click()
        self.wait_until_hidden()
