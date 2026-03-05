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
        QObject.wait_until_appears(self)

    @allure.step('Close')
    def close(self):
        driver.type(self.object, '<Escape>')
        self.wait_until_hidden()
