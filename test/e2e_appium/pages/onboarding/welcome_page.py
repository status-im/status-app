"""
Welcome Page for Status Desktop E2E Testing

Page object for the initial welcome screen in the onboarding flow.
"""

from ..base_page import BasePage
from locators.onboarding.welcome_screen_locators import WelcomeScreenLocators


class WelcomePage(BasePage):
    """Page object for the Welcome screen"""

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = WelcomeScreenLocators()
        self.IDENTITY_LOCATOR = self.locators.WELCOME_PAGE

    def click_create_profile(self) -> bool:
        self.logger.info("Clicking 'Create profile' button")
        return self.try_click(self.locators.CREATE_PROFILE_BUTTON)

    def click_login(self) -> bool:
        self.logger.info("Clicking 'Log in' button")
        return self.try_click(self.locators.LOGIN_BUTTON)
