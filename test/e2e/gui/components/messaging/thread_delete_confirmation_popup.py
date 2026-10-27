import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import messaging_names


class ThreadDeleteConfirmationPopup(QObject):

    def __init__(self):
        super().__init__(messaging_names.threadDeleteConfirmPopup)
        self._confirm_button = Button(messaging_names.threadDeleteConfirmButton)

    @allure.step('Wait until thread delete confirmation appears')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._confirm_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Confirm thread deletion')
    def confirm(self):
        self._confirm_button.click()
        self.wait_until_hidden()
