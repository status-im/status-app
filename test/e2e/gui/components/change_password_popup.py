import driver
from configs.system import get_platform
from constants.settings import PasswordView
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_label import TextLabel
from gui.objects_map import names


class ChangePasswordPopup(QObject):

    def __init__(self):
        super().__init__(names.changePasswordPopup)
        self.re_encrypt_data_restart_button = Button(names.reEncryptRestartButton)
        self.re_encryption_complete_element = TextLabel(names.reEncryptionComplete)

    def click_re_encrypt_data_restart_button(self):
        """
        Timeout is set as rough estimation. What is happening when changing password is
        the process of re-hashing DB initiated. Taking into account the user is new , so DB is relatively small
        I assume, 30 seconds should be enough on Linux to finish re-hashing and show the Restart button.
        On Windows CI, this process takes longer (60 seconds timeout).
        This time is not really predictable, especially for huge DBs.
        In case it does not please check https://github.com/status-im/status-app/issues/13013 for context
        """
        # Platform-specific timeout: Windows CI needs more time for re-encryption
        timeout_msec = 60000 if get_platform() == "Windows" else 30000
        timeout_sec = timeout_msec / 1000
        
        self.re_encrypt_data_restart_button.click()
        assert driver.waitForObject(self.re_encryption_complete_element.real_name, timeout_msec), \
            f'Re-encryption confirmation is not present within {timeout_sec} seconds'
        assert driver.waitForObject(self.re_encrypt_data_restart_button.real_name, timeout_msec)
        assert getattr(self.re_encrypt_data_restart_button.object, 'text') == PasswordView.RESTART_STATUS.value
        self.re_encrypt_data_restart_button.click()
