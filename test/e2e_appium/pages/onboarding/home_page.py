from ..base_page import BasePage
from locators.onboarding.home_locators import HomeLocators


class HomePage(BasePage):

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = HomeLocators()

    def is_home_loaded(self) -> bool:
        return self.is_element_visible(self.locators.HOME_CONTAINER)

    def wait_for_home_load(self, timeout: int = 30) -> bool:
        return self.is_element_visible(self.locators.HOME_CONTAINER, timeout=timeout)

    def is_search_field_visible(self) -> bool:
        return self.is_element_visible(self.locators.SEARCH_FIELD)

    def click_dock_settings(self) -> bool:
        return self.safe_click(self.locators.SETTINGS_BUTTON)

    def click_dock_wallet(self) -> bool:
        return self.safe_click(self.locators.WALLET_BUTTON)

    def click_dock_messages(self) -> bool:
        return self.safe_click(self.locators.MESSAGES_BUTTON)
