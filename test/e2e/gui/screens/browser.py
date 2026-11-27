import logging

import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import browser_names

LOG = logging.getLogger(__name__)


class BrowserScreen(QObject):

    def __init__(self):
        super().__init__(browser_names.browserLayout)
        self.address_field = TextEdit(browser_names.browserAddressField)
        self.new_tab_button = Button(browser_names.browserNewTabButton)

    @property
    def tab_title(self) -> str:
        return str(self.object.currentTitle)

    @allure.step('Open {url} in the browser address bar')
    def open_url(self, url: str) -> 'BrowserScreen':
        self.new_tab_button.click()
        driver.wait_until(lambda: self.address_field.text == '', configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        self.address_field.click()
        self.address_field.text = url
        driver.type_text(self.address_field.object, '<Return>')
        LOG.info('Browser address submitted: %s', url)
        return self

    @allure.step('Wait until the current tab title matches {title}')
    def wait_for_title(
            self,
            title: str,
            timeout_msec: int = configs.timeouts.BROWSER_PAGE_LOAD_TIMEOUT_MSEC,
            *,
            startswith: bool = False,
    ) -> None:
        def matches() -> bool:
            current = self.tab_title
            return current.startswith(title) if startswith else current == title

        assert driver.wait_until(matches, timeout_msec), (
            f'Browser tab title did not match {title!r}; last title={self.tab_title!r}'
        )

    @property
    def open_failed(self) -> bool:
        return QObject(browser_names.browserOpenFailedText).exists

    @allure.step('Wait for the Tab of the opened file {file_name}')
    def wait_for_opened_file(
            self, file_name: str, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC) -> None:
        """The current Tab shows the file: titled and addressed by its name, no failure page."""
        self.wait_for_title(file_name, timeout_msec)
        assert driver.wait_until(lambda: self.address_field.text == file_name, timeout_msec), (
            f'Address bar shows {self.address_field.text!r}, expected {file_name!r}'
        )
        assert not self.open_failed, f'{file_name} opened as "Couldn\'t open the file"'

    def built_tabs(self) -> list:
        """For each Tab, whether its web view has been built."""
        built = self.object._eval(
            '(function () { const r = [];'
            ' for (let i = 0; i < tabs.count; i++) r.push(!!webViewContext.getWebView(i).adapterItem);'
            ' return r.join(",") })()')
        return [part == 'true' for part in str(built).split(',')]

    @allure.step('Set "Restore open tabs" to {on}')
    def set_restore_open_tabs(self, on: bool) -> None:
        self.object._eval(f'root.browserPreferencesStore.setRestoreOpenTabs({str(on).lower()})')

    @allure.step('Open an empty Tab')
    def open_empty_tab(self) -> None:
        self.new_tab_button.click()
        driver.wait_until(lambda: self.address_field.text == '', configs.timeouts.UI_LOAD_TIMEOUT_MSEC)

    @allure.step('Show Tab {index}')
    def show_tab(self, index: int) -> None:
        self.object._eval(f'tabs.activateTab({index})')

    @allure.step('Wait for "Couldn\'t open the file" for {file_name}')
    def wait_for_open_failed(
            self, file_name: str, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC) -> None:
        QObject(browser_names.browserOpenFailedText).wait_until_appears(timeout_msec)
        shown = str(QObject(browser_names.browserOpenFailedFileName).object.text)
        assert shown == file_name, f'The failure page names {shown!r}, expected {file_name!r}'
