import configs.timeouts
from constants.settings import PasswordView
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class ChangePasswordPopup(QObject):

    def __init__(self):
        super().__init__(names.changePasswordPopup)
        self.re_encrypt_data_restart_button = Button(names.reEncryptRestartButton)

    def click_re_encrypt_data_restart_button(self):
        """
        The Restart button is visible but disabled while re-encryption runs — wait for enabled,
        not merely for the object to exist (see ConfirmChangePasswordModal.qml).
        """
        timeout_msec = configs.timeouts.APP_LOAD_TIMEOUT_MSEC

        self.re_encrypt_data_restart_button.click()
        self.re_encrypt_data_restart_button.wait_until_enabled(timeout_msec=timeout_msec)
        assert getattr(self.re_encrypt_data_restart_button.object, 'text') == PasswordView.RESTART_STATUS.value, \
            f'Expected Restart button label, got {self.re_encrypt_data_restart_button.object.text!r}'
        self.re_encrypt_data_restart_button.click()
