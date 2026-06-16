import logging
import time

import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import settings_names

LOG = logging.getLogger(__name__)


class SignOutPopup(QObject):

    def __init__(self):
        super().__init__(settings_names.signOutDialog)
        self.sign_out_dialog = QObject(settings_names.signOutDialog)
        self._sign_out_and_quit_button = Button(settings_names.signOutConfirmationButton)

    @allure.step('Click sign out and quit button')
    def sign_out_and_quit(self, attempts: int = 3):
        last_exception = None
        for attempt in range(1, attempts + 1):
            try:
                self.wait_until_appears()
                self._sign_out_and_quit_button.wait_until_appears()
                self._sign_out_and_quit_button.wait_until_enabled(
                    timeout_msec=configs.timeouts.LOADING_LIST_TIMEOUT_MSEC,
                )

                if attempt > 1:
                    time.sleep(1)

                # TODO https://github.com/status-im/status-app/issues/15345
                # mouseClick() waits for AUT response and can block up to Squish's 300s timeout
                self._sign_out_and_quit_button.native_mouse_click()
                return
            except Exception as exc:
                LOG.info('Sign out attempt #%s failed: %s', attempt, exc)
                last_exception = exc
                time.sleep(1)
        raise last_exception
