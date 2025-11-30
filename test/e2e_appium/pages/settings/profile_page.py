from typing import Optional

from ..base_page import BasePage
from locators.settings.profile_locators import ProfileSettingsLocators


class ProfileSettingsPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ProfileSettingsLocators()

    def is_loaded(self, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(
            self.locators.PROFILE_TAB_IDENTITY, timeout=timeout
        )

    def open_identity_tab(self) -> bool:
        return self.safe_click(self.locators.PROFILE_TAB_IDENTITY, max_attempts=1)

    def open_share_profile(self):
        from .share_profile_dialog import ShareProfileDialog

        if not self.safe_click(self.locators.SHARE_PROFILE_BUTTON):
            return None
        dialog = ShareProfileDialog(self.driver)
        return dialog if dialog.is_displayed(timeout=8) else None


