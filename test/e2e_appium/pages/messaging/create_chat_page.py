import time
from typing import Optional

from ..base_page import BasePage
from .chat_page import ChatPage
from locators.messaging.create_chat_locators import CreateChatLocators


class CreateChatPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = CreateChatLocators()

    def enter_profile_link(
        self, profile_link: str, verify: bool = False, timeout: int = 10
    ) -> bool:
        if not profile_link:
            self.logger.error("Cannot paste empty profile link into create chat input")
            return False

        if not self.qt_safe_input(
            self.locators.RECIPIENT_INPUT, profile_link, timeout=timeout, verify=verify
        ):
            self.logger.error("Failed to input profile link into create chat field")
            self.take_screenshot("create_chat_input_failure")
            self.dump_page_source("create_chat_input_failure")
            return False

        return True

    def tap_start_chat(
        self, timeout: Optional[int] = 5, wait_for_input: bool = True
    ) -> bool:
        try:
            ChatPage(self.driver).dismiss_backup_prompt(timeout=2)
        except Exception as exc:
            self.logger.debug("Backup prompt dismiss check failed: %s", exc)

        if not self.safe_click(self.locators.START_CHAT_BUTTON, timeout=timeout):
            return False

        if wait_for_input and not self.is_element_visible(
            self.locators.RECIPIENT_INPUT, timeout=timeout or 5
        ):
            self.logger.error("Create chat input did not appear after tapping start chat")
            self.take_screenshot("create_chat_input_missing")
            self.dump_page_source("create_chat_input_missing")
            return False

        return True

    def wait_for_contact_request_modal(self, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(
            self.locators.CONTACT_REQUEST_MODAL_ROOT, timeout=timeout
        )

    def send_contact_request(
        self, message: Optional[str] = None, timeout: Optional[int] = 10
    ) -> bool:
        if not message:
            message = "Hi! Please add me on Status."

        time.sleep(3)

        if not self.wait_for_contact_request_modal(timeout=timeout):
            self.logger.error("Contact request modal did not appear")
            self.take_screenshot("contact_request_modal_missing")
            self.dump_page_source("contact_request_modal_missing")
            return False

        if not self.qt_safe_input(
            self.locators.CONTACT_REQUEST_MESSAGE_INPUT, message, timeout=timeout, verify=False
        ):
            self.logger.error("Failed to type contact request message")
            self.take_screenshot("contact_request_message_failure")
            self.dump_page_source("contact_request_message_failure")
            return False

        if not self.wait_for_element_enabled(self.locators.CONTACT_REQUEST_SEND_BUTTON, timeout=timeout or 5):
            button_el = self.find_element_safe(self.locators.CONTACT_REQUEST_SEND_BUTTON, timeout=1)
            if button_el:
                enabled_attr = button_el.get_attribute("enabled")
                focusable_attr = button_el.get_attribute("focusable")
                self.logger.error(
                    "Contact request send button not enabled (enabled=%s, focusable=%s)",
                    enabled_attr,
                    focusable_attr,
                )
            else:
                self.logger.error(
                    "Contact request send button element not found when checking enabled state"
                )
            self.take_screenshot("contact_request_send_disabled")
            return False

        button_element = self.find_element_safe(self.locators.CONTACT_REQUEST_SEND_BUTTON, timeout=timeout)
        if button_element is not None:
            try:
                button_element.click()
                return True
            except Exception as exc:
                self.logger.debug("Direct click on send button failed: %s", exc)

        if not self.safe_click(self.locators.CONTACT_REQUEST_SEND_BUTTON, timeout=timeout):
            self.logger.error("Failed to tap contact request send button")
            self.take_screenshot("contact_request_send_failure")
            self.dump_page_source("contact_request_send_failure")
            return False

        return True
