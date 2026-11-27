from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support.ui import WebDriverWait

from locators.app_locators import AppLocators
from locators.browser_locators import BrowserLocators
from pages.app import App
from pages.base_page import BasePage
from support.screen_identity import dismiss_backup_modal

KEYCODE_A = 29
KEYCODE_DEL = 67
KEYCODE_ENTER = 66
META_CTRL_ON = 4096
KEYCODE_BACK = 4


class BrowserPage(BasePage):
    """In-app browser: address field, downloads, and the apps that open them."""

    def open_browser(self) -> None:
        dismiss_backup_modal(self, timeout=2)
        app = App(self.driver)
        assert app._ensure_main_nav_visible(), "App navigation did not open"
        assert app._click_nav_item(AppLocators.LEFT_NAV_BROWSER), "Browser navigation failed"
        self.find_element(BrowserLocators.ADDRESS_FIELD, timeout=30)

    def foreground_package(self) -> str:
        return self.driver.current_package

    def load_url(self, url: str) -> None:
        assert not self.is_element_visible(BrowserLocators.DOWNLOAD_PILL, timeout=1), (
            "Use a fresh browser session so the download pill identifies this download"
        )
        # qt_safe_input calls element.clear(), which leaves this field empty and
        # drops the keys typed after it, so select all and delete instead.
        self.click(BrowserLocators.ADDRESS_FIELD)
        self.driver.press_keycode(KEYCODE_A, metastate=META_CTRL_ON)
        self.driver.press_keycode(KEYCODE_DEL)
        actions = ActionChains(self.driver)
        for character in url:
            actions.send_keys(character).pause(0.1)
        actions.perform()
        self.driver.press_keycode(KEYCODE_ENTER)

    def wait_for_completed_download(self, timeout: int = 60) -> None:
        """Wait until Share file is enabled, which happens only for completed downloads.

        The 60 s default covers the file transfer from the fixture server.
        """
        self.click(BrowserLocators.DOWNLOAD_OPTIONS, timeout=timeout)
        try:
            self.find_element(BrowserLocators.COMPLETED_FILE_ACTION, timeout=timeout)
        finally:
            self.driver.press_keycode(KEYCODE_BACK)
        assert self.wait_for_invisibility(BrowserLocators.DOWNLOAD_MENU, timeout=5), (
            "Download options did not close"
        )

    def open_completed_download(self) -> None:
        pill = self.find_element(BrowserLocators.DOWNLOAD_PILL)
        self.driver.execute_script("mobile: clickGesture", {"elementId": pill.id})

    def wait_for_external_package(self, status_package: str, timeout: int = 20) -> str:
        """Return the package of the app that opened the download.

        The 20 s default allows for Android starting a second app, which is
        slower than a screen change inside Status.
        """

        def external_package(driver):
            package = driver.current_package
            return package if package and package != status_package else False

        return WebDriverWait(self.driver, timeout).until(
            external_package, message=f"Downloaded file did not leave {status_package}"
        )

    def return_from_external_app(self, status_package: str) -> None:
        """Close the app that opened the download and bring Status back."""
        try:
            self.driver.press_keycode(KEYCODE_BACK)
        finally:
            self.driver.activate_app(status_package)
