from typing import Optional

from ..base_page import BasePage
from locators.settings.send_contact_request_locators import SendContactRequestLocators


class SendContactRequestModal(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = SendContactRequestLocators()

    def is_displayed(self, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(self.locators.MODAL_ROOT, timeout=timeout)

    def enter_chat_key(self, chat_key: str) -> bool:
        """Enter chat key."""
        return self.qt_safe_input(
            self.locators.CHAT_KEY_INPUT, chat_key, max_retries=1, verify=False
        )

    def enter_message(self, message: str) -> bool:
        """Enter message."""
        return self.qt_safe_input(
            self.locators.MESSAGE_INPUT, message, max_retries=1, verify=False
        )

    def send(self, wait_for_enabled: int = 5) -> bool:
        """Wait for send button to be enabled, then click it."""
        if not self.wait_for_element_enabled(
            self.locators.SEND_BUTTON, timeout=wait_for_enabled
        ):
            self.logger.error("Send button not enabled after waiting")
            return False
        return self.safe_click(self.locators.SEND_BUTTON)


