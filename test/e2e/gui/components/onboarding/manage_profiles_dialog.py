import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import onboarding_names


class DeleteMultiaccountConfirmationDialog(QObject):

    def __init__(self):
        super().__init__(onboarding_names.deleteMultiaccountConfirmationDialog)
        self.confirm_button = Button(onboarding_names.confirmDeleteMultiaccountBtn)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.confirm_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Confirm remove profile')
    def confirm(self):
        self.confirm_button.click()
        self.wait_until_hidden()


class ManageProfilesDialog(QObject):

    def __init__(self):
        super().__init__(onboarding_names.manageProfilesDialog)
        self.profile_row = QObject(onboarding_names.manageProfilesRow)
        self.delete_profile_button = Button(dict(onboarding_names.deleteProfileButton))
        self.done_button = Button(onboarding_names.doneBtnManageProfiles)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.done_button.wait_until_appears(timeout_msec)
        return self

    def _row_by_name(self, user_name: str):
        raw_data = driver.findAllObjects(self.profile_row.real_name)
        if not raw_data:
            raise ValueError(f"Can't find {user_name} in manage profiles list as the list is empty")
        for row in raw_data:
            if str(QObject(row).object.label) == user_name:
                return row
        raise ValueError(f'User "{user_name}" was not found in manage profiles list')

    @allure.step('Delete profile by name')
    def delete_profile_by_name(self, user_name: str):
        row = self._row_by_name(user_name)
        key_uid = str(QObject(row).object.objectName).removeprefix('manageProfilesDelegate-')
        self.delete_profile_button.real_name['objectName'] = f'deleteProfileButton-{key_uid}'
        self.delete_profile_button.click()
        DeleteMultiaccountConfirmationDialog().wait_until_appears().confirm()
        return self
