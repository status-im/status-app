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

    @property
    def _typing_target(self):
        """For StatusInput and similar wrappers, use inner edit for typing (focus)."""
        obj = self.object
        if hasattr(obj, 'input') and hasattr(obj.input, 'edit'):
            return obj.input.edit
        return obj

    @allure.step('Type: {1} in {0}')
    def type_text(self, value: str):
        obj = self.object
        # StatusInput: set text via property to avoid "clipped by parent" with driver.type on VM
        if hasattr(obj, 'input') and hasattr(obj.input, 'edit') and hasattr(obj, 'text'):
            obj.text = value
        else:
            driver.type(self._typing_target, value)
        LOG.info('%s: value changed to "%s"', self, value)
        return self

    @allure.step('Clear {0}')
    def clear(self, verify: bool = True):
        obj = self.object
        if hasattr(obj, 'clear'):
            obj.clear()
        elif hasattr(obj, 'reset'):
            obj.reset()
        elif hasattr(obj, 'text'):
            obj.text = ""
        else:
            driver.type(obj, "<Ctrl+a><Delete>")
        if verify:
            assert driver.waitFor(lambda: not self.text), \
                f'Clear text field failed, value in field: "{self.text}"'
        LOG.info('%s: cleared', self)
        return self
