import logging
import time

import allure

import driver
from gui.elements.object import QObject
from gui.objects_map import names

LOG = logging.getLogger(__name__)


class BasePopup(QObject):

    def __init__(self):
        super().__init__(names.basePopupItem)
        self.wait_until_enabled()

    @allure.step('Close')
    def close(self):
        driver.type_text(self.object, '<Escape>')
        self.wait_until_hidden()
