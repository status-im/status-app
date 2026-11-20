import logging

import allure

import configs
import driver
from gui.elements.object import QObject

LOG = logging.getLogger(__name__)


class CheckBox(QObject):

    @allure.step("Set {0} value: {1}")
    def set(self, value: bool):
        checked = self.checkState != 0
        if checked is not value:
            self.click()
            assert driver.wait_until(
                lambda: value == (self.checkState != 0), configs.timeouts.UI_LOAD_TIMEOUT_MSEC), 'Value not changed'
        LOG.info('%s: value changed to "%s"', self, value)
