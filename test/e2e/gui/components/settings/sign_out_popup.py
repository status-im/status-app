import logging
import time

import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import settings_names

LOG = logging.getLogger(__name__)


class SignOutPopup(QObject):

    def __init__(self):
        super().__init__(settings_names.signOutDialog)
        self.sign_out_dialog = QObject(settings_names.signOutDialog)
        self._sign_out_button = Button(settings_names.signOutConfirmationButton)

    @allure.step('Click sign out button')
    def sign_out(self, attempts: int = 3):
        last_exception = None
        for attempt in range(1, attempts + 1):
            try:
                self.wait_until_appears()
                self._sign_out_button.wait_until_appears()
                self._sign_out_button.wait_until_enabled(
                    timeout_msec=configs.timeouts.LOADING_LIST_TIMEOUT_MSEC,
                )

                if attempt > 1:
                    time.sleep(1)

                try:
                    self._sign_out_button.click()
                except driver.InspectorError as err:
                    # The app quits on sign-out and may close the connection before it answers the click.
                    LOG.info('Connection closed by sign-out: %s', err)
                return
            except Exception as exc:
                LOG.info('Sign out attempt #%s failed: %s', attempt, exc)
                last_exception = exc
                time.sleep(1)
        raise last_exception
