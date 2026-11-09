import allure

from gui.components.messaging.thread_delete_confirmation_popup import ThreadDeleteConfirmationPopup
from gui.elements.button import Button
from gui.objects_map import messaging_names


class ThreadHeaderMenu:

    def __init__(self):
        self._menu_button = Button(messaging_names.threadHeaderMenuButton)
        self._follow_item = Button(messaging_names.threadContextMenuFollow)
        self._delete_item = Button(messaging_names.threadContextMenuDelete)

    @allure.step('Open thread header menu')
    def open(self):
        self._menu_button.wait_until_appears().click()
        return self

    @allure.step('Select {label!r} on thread header menu')
    def select_follow(self, label: str):
        self._follow_item.wait_until_appears()
        assert self._follow_item.text == label, (
            f'Thread follow menu label was {self._follow_item.text!r}, expected {label!r}'
        )
        self._follow_item.click()
        return self

    @allure.step('Select Delete on thread header menu')
    def select_delete(self):
        self._delete_item.wait_until_appears()
        assert self._delete_item.text == 'Delete', (
            f'Thread delete menu label was {self._delete_item.text!r}, expected "Delete"'
        )
        self._delete_item.click()
        return ThreadDeleteConfirmationPopup().wait_until_appears()
