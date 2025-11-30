from typing import Optional

from ..base_page import BasePage
from locators.settings.messaging_locators import MessagingSettingsLocators


class MessagingSettingsPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = MessagingSettingsLocators()

    def is_loaded(self, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(self.locators.CONTACTS_ENTRY, timeout=timeout)

    def open_contacts(self):
        from .contacts_page import ContactsSettingsPage

        if not self.safe_click(self.locators.CONTACTS_ENTRY):
            return None
        page = ContactsSettingsPage(self.driver)
        return page if page.is_loaded(timeout=10) else None


