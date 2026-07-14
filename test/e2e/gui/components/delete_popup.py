import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class ConfirmationPopup(QObject):

    def __init__(self):
        super().__init__(names.confirmationDialog)
        self.confirmation_dialog = QObject(names.confirmationDialog)
        self.delete_button = Button(names.delete_StatusButton)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.delete_button.wait_until_appears(timeout_msec)
        return self


class ConfirmationCategoryPopup(ConfirmationPopup):

    def __init__(self):
        super().__init__()
        self.confirm_button = Button(names.confirm_StatusButton)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.confirm_button.wait_until_appears(timeout_msec)
        return self


class ConfirmationPermissionPopup(ConfirmationPopup):

    def __init__(self):
        super().__init__()
        self.confirm_delete_button = Button(names.confirm_permission_delete_StatusButton)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.confirm_delete_button.wait_until_appears(timeout_msec)
        return self


class ConfirmationMessagePopup(QObject):

    def __init__(self):
        super().__init__(names.confirmationDeleteMessagePopup)
        self.delete_button = Button(names.confirm_delete_message_StatusButton)
