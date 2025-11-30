from typing import Optional

from ..base_page import BasePage
from locators.settings.contacts_locators import ContactsSettingsLocators


class ContactsSettingsPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ContactsSettingsLocators()

    def is_loaded(self, timeout: Optional[int] = 12) -> bool:
        return self.is_element_visible(
            self.locators.SEND_CONTACT_REQUEST_BUTTON, timeout=timeout
        )

    def open_send_contact_request_modal(self):
        from .send_contact_request_modal import SendContactRequestModal

        if not self.safe_click(self.locators.SEND_CONTACT_REQUEST_BUTTON):
            return None
        modal = SendContactRequestModal(self.driver)
        return modal if modal.is_displayed(timeout=10) else None

    def open_contacts_tab(self, timeout: Optional[int] = None) -> bool:
        return self.safe_click(self.locators.CONTACTS_TAB, timeout=timeout)

    def wait_for_pending_requests_focusable(self, timeout: Optional[int] = 15) -> bool:
        def _is_focusable() -> bool:
            element = self.find_element_safe(self.locators.PENDING_TAB, timeout=1)
            if not element:
                return False
            try:
                value = element.get_attribute("focusable")
                return str(value).lower() == "true"
            except Exception as e:
                self.logger.debug(f"_is_focusable attribute read failed: {e}")
                return False

        return self.wait_for_condition(_is_focusable, timeout=timeout)

    def open_pending_requests_tab(self, timeout: Optional[int] = None) -> bool:
        return self.safe_click(self.locators.PENDING_TAB, timeout=timeout)

    def open_dismissed_tab(self, timeout: Optional[int] = None) -> bool:
        return self.safe_click(self.locators.DISMISSED_TAB, timeout=timeout)

    def open_blocked_tab(self, timeout: Optional[int] = None) -> bool:
        return self.safe_click(self.locators.BLOCKED_TAB, timeout=timeout)

    def pending_request_row_exists(
        self, display_name: Optional[str] = None, timeout: Optional[int] = 10
    ) -> bool:
        if display_name:
            locator = self.locators.contact_row(display_name)
            if self.is_element_visible(locator, timeout=timeout):
                return True
        return self.is_element_visible(self.locators.PENDING_REQUEST_ROW, timeout=timeout)

    def accept_contact_request(self, display_name: Optional[str] = None) -> bool:
        if not display_name:
            self.logger.error("accept_contact_request requires display_name to be provided")
            return False

        locator = self.locators.accept_button(display_name)
        try:
            return self.safe_click(locator, timeout=6, max_attempts=2)
        except Exception as exc:
            self.logger.error("Accept click failed for %s: %s", locator, exc)
            return False

    def open_chat_with(self, display_name: str) -> bool:
        target = self.locators.chat_button(display_name)
        return self.safe_click(target, max_attempts=1)

    def contacts_row_exists(
        self, identifier: str, timeout: Optional[int] = 10
    ) -> bool:
        locator = self.locators.contact_row(identifier)
        if self.is_element_visible(locator, timeout=timeout):
            return True
        suffix_locator = self.locators.contact_row(identifier[-6:])
        return self.is_element_visible(suffix_locator, timeout=timeout)


