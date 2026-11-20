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
        assert driver.wait_until(lambda: self.text == value, configs.timeouts.UI_LOAD_TIMEOUT_MSEC), \
            f'Type text failed, value in field: "{self.text}", expected: {value}'

    @allure.step('Type: {1} in {0}')
    def type_text(self, value: str):
        driver.type_text(self.object, value)
        LOG.info('%s: value changed to "%s"', self, value)
        return self

    @allure.step('Clear {0}')
    def clear(self, verify: bool = True):
        self.object.clear()
        if verify:
            assert driver.wait_until(lambda: not self.text), \
                f'Clear text field failed, value in field: "{self.text}"'
        LOG.info('%s: cleared', self)
        return self

    @allure.step('Search: {1} in {0}')
    def search(self, query: str):
        self.wait_until_appears()
        self.set_text_property(query)
        LOG.info('%s: search query set to "%s"', self, query)
        return self

    @allure.step('Right click at character {1} in {0}')
    def right_click_at_character(self, index: int):
        rect = self.object.positionToRectangle(index)
        self.right_click(int(rect.x) + 1, int(rect.y + rect.height / 2))
        return self

    def _spell_checker(self):
        return self.object.spellChecker

    def spell_issues_count(self) -> int:
        issues = self._spell_checker().issues
        length = getattr(issues, 'length', None)
        if callable(length):
            return int(length())
        if length is not None:
            return int(length)
        return len(issues)

    def spell_check_finished(self) -> bool:
        pending = getattr(self._spell_checker(), 'checkPending', False)
        if callable(pending):
            pending = pending()
        return not pending

    def has_spell_issues(self) -> bool:
        return self.spell_check_finished() and self.spell_issues_count() > 0

    def has_no_spell_issues(self) -> bool:
        return self.spell_check_finished() and self.spell_issues_count() == 0
