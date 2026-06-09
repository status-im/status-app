import logging

import allure

from gui.components.authenticate_popup import AuthenticatePopup
from gui.components.settings.sync_new_device_popup import SyncNewDevicePopup
from gui.components.settings.unpair_confirmation_popup import UnpairDeviceConfirmationPopup
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.text_label import TextLabel
from gui.objects_map import settings_names

LOG = logging.getLogger(__name__)


class SyncingSettingsView(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_SyncingView)
        self.setup_syncing_button = Button(settings_names.settings_Setup_Syncing_StatusButton)
        self.sync_new_device_instructions_header = TextLabel(settings_names.settings_Sync_New_Device_Header)
        self.sync_new_device_instructions_subtitle = TextLabel(settings_names.settings_Sync_New_Device_SubTitle)
        self.unpair_button = Button(settings_names.unpairButton)
        self.enable_message_syncing_checkbox = CheckBox(settings_names.enableMessageSyncingCheckBox)

    @allure.step('Click Unpair button')
    def open_unpair_confirmation(self):
        self.unpair_button.click()
        return UnpairDeviceConfirmationPopup()

    @allure.step('Setup syncing')
    def open_sync_new_device_popup(self, password: str, message_sync: bool = False):
        if message_sync:
            self.enable_message_syncing_checkbox.set(True)
        auth_popup = self.click_setup_syncing()
        auth_popup.authenticate(password)
        return SyncNewDevicePopup().wait_until_appears()

    @allure.step('Click setup syncing')
    def click_setup_syncing(self, attempts: int = 3):
        last_exception = None
        for i in range(1, attempts + 1):
            try:
                LOG.info(f'Attempt # {i} to open Authentication popup')
                self.setup_syncing_button.click()
                popup = AuthenticatePopup().wait_until_appears()
                return popup
            except Exception as e:
                last_exception = e
                LOG.info(f'Attempt # {i} to open Authentication popup failed with {e}')
        raise LookupError(f'Could not open auth popup with {last_exception}')
