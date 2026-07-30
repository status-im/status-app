import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class LeaveGroupPopup(QObject):

    def __init__(self):
        super().__init__(names.confirmationDialog)
        self.leave_button = Button(names.leave_StatusButton)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.leave_button.wait_until_appears(timeout_msec)
        return self

    @allure.step("Confirm leaving group")
    def confirm_leaving(self):
        self.leave_button.wait_until_appears()
        self.leave_button.wait_until_enabled()
        self.leave_button.click()
        self.leave_button.wait_until_hidden()

