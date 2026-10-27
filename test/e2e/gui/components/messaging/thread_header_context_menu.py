import allure

import configs
import driver
from gui.components.messaging.thread_delete_confirmation_popup import ThreadDeleteConfirmationPopup
from gui.elements.button import Button
from gui.objects_map import messaging_names


class ThreadHeaderMenu:

    def __init__(self):
        self._menu_button = Button(messaging_names.threadHeaderMenuButton)
        self._follow_item = Button(messaging_names.threadContextMenuFollow)
        self._edit_name_item = Button(messaging_names.threadContextMenuEditName)
        self._mute_item = Button(messaging_names.threadContextMenuMute)
        self._mute_duration_anchor = Button(messaging_names.muteChatMenuFor15Mins)
        self._mute_until_on_item = Button(messaging_names.muteChatMenuUntilTurnedOn)
        self._unmute_item = Button(messaging_names.threadContextMenuUnmute)
        self._delete_item = Button(messaging_names.threadContextMenuDelete)

    @allure.step('Open thread header menu')
    def open(self):
        self._menu_button.wait_until_appears().click()
        self._follow_item.wait_until_appears()
        return self

    @allure.step('Select {label!r} on thread header menu')
    def select_follow(self, label: str):
        self._follow_item.wait_until_appears()
        assert self._follow_item.text == label, (
            f'Thread follow menu label was {self._follow_item.text!r}, expected {label!r}'
        )
        self._follow_item.click()
        return self

    @allure.step('Select Edit name on thread header menu')
    def select_edit_name(self):
        self._edit_name_item.wait_until_appears().click()
        return self

    @allure.step('Mute the open thread until turned back on')
    def select_mute_until_turned_on(self):
        self._mute_item.wait_until_appears().hover()
        self._mute_duration_anchor.wait_until_appears()
        self._mute_until_on_item.wait_until_appears().object.click()
        self.open()
        self._unmute_item.wait_until_appears(configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000)
        self.close()
        return self

    @allure.step('Unmute the open thread')
    def select_unmute(self):
        self._unmute_item.wait_until_appears().click()
        return self

    @allure.step('Delete is offered in the open thread menu')
    def delete_is_available(self) -> bool:
        return self._delete_item.is_visible

    @allure.step('Close the thread header menu')
    def close(self):
        driver.type_text(self._menu_button.object, '<Escape>')
        return self

    @allure.step('Select Delete on thread header menu')
    def select_delete(self):
        self._delete_item.wait_until_appears()
        assert self._delete_item.text == 'Delete', (
            f'Thread delete menu label was {self._delete_item.text!r}, expected "Delete"'
        )
        self._delete_item.click()
        return ThreadDeleteConfirmationPopup().wait_until_appears()