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

    def accept_contact_request(self, display_name: str) -> bool:
        """Accept a pending contact request.

        Primary is ``FIRST_PENDING_ACCEPT_BUTTON`` — the receiver's UI tags
        the incoming request with an auto-generated identity name (e.g.
        "Negligible Authorized Chafer"), not ``display_name``, so the
        filtered xpath never matches in the one-pending-request flow. The
        filtered xpath remains as a fallback for future multi-request
        scenarios where the receiver knows the contact.
        """
        try:
            return self.safe_click(
                self.locators.FIRST_PENDING_ACCEPT_BUTTON,
                fallback_locators=[self.locators.accept_button(display_name)],
                timeout=6,
                max_attempts=2,
            )
        except Exception as exc:
            self.logger.error("Accept click failed for sender '%s': %s", display_name, exc)
            return False

    def open_chat_with(self, display_name: str) -> bool:
        """Open chat with a specific contact.

        Primary is ``FIRST_CONTACT_CHAT_BUTTON`` — Status's ContactPanel
        content-desc carries the auto-generated identity name (e.g.
        "Unselfish Free Crocodile"), not the chat-key suffix, so the
        filtered xpath misses. Mirrors ``accept_contact_request``. The
        filtered locator stays as fallback for future scenarios where
        the contact panel does carry the suffix or display_name.
        """
        return self.safe_click(
            self.locators.FIRST_CONTACT_CHAT_BUTTON,
            fallback_locators=[self.locators.chat_button(display_name)],
            timeout=10,
            max_attempts=2,
        )

    def contacts_row_exists(
        self, identifier: str, timeout: Optional[int] = 10
    ) -> bool:
        locator = self.locators.contact_row(identifier)
        if self.is_element_visible(locator, timeout=timeout):
            return True
        suffix_locator = self.locators.contact_row(identifier[-6:])
        return self.is_element_visible(suffix_locator, timeout=timeout)


