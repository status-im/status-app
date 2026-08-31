from ..base_page import BasePage
from locators.onboarding.create_profile_screen_locators import (
    CreateProfileScreenLocators,
)


class CreateProfilePage(BasePage):

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = CreateProfileScreenLocators()
        self.IDENTITY_LOCATOR = self.locators.CREATE_PROFILE_SCREEN

    def click_lets_go(self) -> bool:
        self.logger.info("Clicking 'Let's go!' button")
        return self.try_click(self.locators.LETS_GO_BUTTON_BY_ID)

    def click_use_recovery_phrase(self) -> bool:
        self.logger.info("Clicking 'Use a recovery phrase' button")
        return self.try_click(self.locators.USE_RECOVERY_PHRASE_BUTTON)

    def click_use_keycard(self) -> bool:
        self.logger.info("Clicking 'Use an empty Keycard' button")
        return self.try_click(self.locators.USE_KEYCARD_BUTTON)
