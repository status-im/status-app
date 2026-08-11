import configs.timeouts
from constants.settings import PasswordView
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class ChangePasswordPopup(QObject):

    def __init__(self):
        super().__init__(names.changePasswordPopup)
        self.re_encrypt_data_restart_button = Button(names.reEncryptRestartButton)

    def confirm_password_change(self) -> bool:
        """
        Starts the password change and completes the popup flow.

        Returns True when the app is restarting (slow path: one-time migration of a legacy
        profile, or the rekey option), False when the fast path finished — the popup was
        closed and the app keeps running.

        The button is visible but disabled while the operation runs — wait for enabled,
        not merely for the object to exist (see ConfirmChangePasswordModal.qml).
        """
        timeout_msec = configs.timeouts.FAST_PASSWORD_TIMEOUT_MSEC

        self.re_encrypt_data_restart_button.click()
        self.re_encrypt_data_restart_button.wait_until_enabled(timeout_msec=timeout_msec)

        label = getattr(self.re_encrypt_data_restart_button.object, 'text')
        assert label in (PasswordView.RESTART_STATUS.value, PasswordView.CLOSE.value), \
            f'Expected Restart/Close button label, got {label!r}'

        self.re_encrypt_data_restart_button.click()
        return label == PasswordView.RESTART_STATUS.value
