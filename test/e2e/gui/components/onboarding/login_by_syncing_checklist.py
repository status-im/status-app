import allure

from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import onboarding_names, names


class LogInBySyncingDialog(QObject):
    def __init__(self):
        super().__init__(names.commonDialog)
        self.cancel_button = Button(onboarding_names.cancelButton)
        self.continue_button = Button(onboarding_names.continueButton)

    @allure.step('Click continue button for Log in by syncing dialog')
    def complete(self):
        assert self.continue_button.is_enabled
        self.continue_button.click()
