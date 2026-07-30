import allure

from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class UnpairDeviceConfirmationPopup(QObject):
    def __init__(self):
        super().__init__(names.confirmationDialog)
        self.unpair_button = Button(names.unpairButton)

    @allure.step('Confirm unpairing')
    def confirm_unpairing(self):
        self.unpair_button.wait_until_enabled()
        self.unpair_button.click()
        return self