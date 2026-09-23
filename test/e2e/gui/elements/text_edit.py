import logging

import allure

import configs
import driver
from gui.elements.object import QObject

LOG = logging.getLogger(__name__)


class TextEdit(QObject):

    @property
    @allure.step('Get current text {0}')
    def text(self) -> str:
        return str(self.object.text)

    @text.setter
    @allure.step('Type text {1} {0}')
    def text(self, value: str):
        self.clear()
        self.type_text(value)
        assert driver.waitFor(lambda: self.text == value, configs.timeouts.UI_LOAD_TIMEOUT_MSEC), \
            f'Type text failed, value in field: "{self.text}", expected: {value}'

    @allure.step('Type: {1} in {0}')
    def type_text(self, value: str):
        driver.type(self.object, value)
        LOG.info('%s: value changed to "%s"', self, value)
        return self

    @allure.step('Clear {0}')
    def clear(self, verify: bool = True):
        self.object.clear()
        if verify:
            assert driver.waitFor(lambda: not self.text), \
                f'Clear text field failed, value in field: "{self.text}"'
        LOG.info('%s: cleared', self)
        return self

    @allure.step('Search: {1} in {0}')
    def search(self, query: str):
        self.wait_until_appears()
        self.set_text_property(query)
        LOG.info('%s: search query set to "%s"', self, query)
        return self
