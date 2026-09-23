import logging

import allure

from gui.elements.object import QObject

LOG = logging.getLogger(__name__)


class Button(QObject):

    @property
    @allure.step('Get text {0}')
    def text(self) -> str:
        return str(self.object.text)
