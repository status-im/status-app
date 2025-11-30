from ..base_page import BasePage
from locators.onboarding.biometrics_locators import BiometricsLocators
from utils.exceptions import ElementInteractionError


class BiometricsPage(BasePage):
    """Page object for the biometrics opt-in prompt shown during onboarding."""

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = BiometricsLocators()
        self.IDENTITY_LOCATOR = self.locators.MAYBE_LATER_BUTTON

    def select_maybe_later(self) -> bool:
        try:
            self.safe_click(self.locators.MAYBE_LATER_BUTTON)
        except ElementInteractionError:
            self.logger.error("Failed to tap 'Maybe later' on biometrics prompt", exc_info=True)
            return False

        return self.wait_for_invisibility(self.IDENTITY_LOCATOR)

