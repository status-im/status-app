import logging

import allure

import configs
import driver
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import browser_names

LOG = logging.getLogger(__name__)


class BrowserScreen(QObject):

    def __init__(self):
        super().__init__(browser_names.browserLayout)
        self.address_field = TextEdit(browser_names.browserAddressField)

    @property
    def tab_title(self) -> str:
        return str(self.object.currentTitle)

    @allure.step('Open {url} in the browser address bar')
    def open_url(self, url: str) -> 'BrowserScreen':
        self.address_field.click()
        self.address_field.text = url
        driver.type(self.address_field.object, '<Return>')
        LOG.info('Browser address submitted: %s', url)
        return self

    @allure.step('Wait until the current tab title matches {title}')
    def wait_for_title(
            self,
            title: str,
            timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            *,
            startswith: bool = False,
    ) -> None:
        def matches() -> bool:
            current = self.tab_title
            return current.startswith(title) if startswith else current == title

        assert driver.waitFor(matches, timeout_msec), (
            f'Browser tab title did not match {title!r}; last title={self.tab_title!r}'
        )
