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
        return self.qt_safe_input(self.locators.CHAT_KEY_INPUT, chat_key)

    def enter_message(self, message: str) -> bool:
        return self.qt_safe_input(self.locators.MESSAGE_INPUT, message)

    def send(self) -> bool:
        return self.safe_click(self.locators.SEND_BUTTON)


