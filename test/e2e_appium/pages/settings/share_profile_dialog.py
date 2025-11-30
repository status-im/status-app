from typing import Optional

from ..base_page import BasePage
from locators.settings.profile_locators import ProfileSettingsLocators


class ShareProfileDialog(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ProfileSettingsLocators()

    def is_displayed(self, timeout: Optional[int] = 6) -> bool:
        return self.is_element_visible(self.locators.SHARE_PROFILE_DIALOG, timeout=timeout)

    def get_profile_link(self) -> Optional[str]:
        element = self.find_element_safe(self.locators.PROFILE_LINK_INPUT)
        if not element:
            return None
        value = element.get_attribute("text")
        if value:
            return value
        placeholder = element.get_attribute("hint")
        return placeholder or element.get_attribute("content-desc")


