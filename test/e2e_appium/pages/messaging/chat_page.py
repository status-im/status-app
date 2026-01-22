from typing import Optional

from ..base_page import BasePage
from locators.messaging.chat_locators import ChatLocators


class ChatPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ChatLocators()

    def _is_chat_list_visible(self, timeout: int = 3) -> bool:
        return (
            self.is_element_visible(self.locators.CHAT_SEARCH_BOX, timeout=timeout)
            or self.is_element_visible(self.locators.START_CHAT_BUTTON, timeout=1)
        )

    def _ensure_chat_list_visible(self, timeout: int = 5) -> bool:
        if self._is_chat_list_visible(timeout=2):
            return True
        if self.is_portrait_mode():
            self.safe_click(self.locators.TOOLBAR_BACK_BUTTON, timeout=2)
            return self._is_chat_list_visible(timeout=timeout)
        return False

    def is_loaded(self, timeout: Optional[int] = 15) -> bool:
        self.dismiss_introduce_prompt(timeout=2)
        return self._ensure_chat_list_visible(timeout=timeout)

    def open_chat(self, display_name: str) -> bool:
        locator = self.locators.chat_list_item(display_name)
        return self.safe_click(locator, max_attempts=2)

    def _resolve_chat_locators(self, chat_identifier: str, display_name: Optional[str] = None):
        locators = [self.locators.dm_row_button(chat_identifier)]
        if display_name:
            locators.append(self.locators.chat_list_item(display_name))
        return locators

    def open_chat_by_suffix(
        self,
        chat_identifier: str,
        *,
        display_name: Optional[str] = None,
        timeout: Optional[int] = 15,
    ) -> bool:
        self._ensure_chat_list_visible()
        for locator in self._resolve_chat_locators(chat_identifier, display_name):
            if self.is_element_visible(locator, timeout=timeout):
                return self.safe_click(locator, timeout=timeout, max_attempts=3)
        return False

    def wait_for_message_input(self, timeout: Optional[int] = 10) -> bool:
        return self.is_element_visible(self.locators.MESSAGE_INPUT, timeout=timeout)

    def tap_start_chat(self, timeout: Optional[int] = 5) -> bool:
        self.dismiss_backup_prompt(timeout=2)
        return self.safe_click(self.locators.START_CHAT_BUTTON, timeout=timeout)

    def send_message(self, message: str, timeout: Optional[int] = None) -> bool:
        self.dismiss_introduce_prompt(timeout=2)
        payload = f"{message}\n"
        return self.qt_safe_input(
            self.locators.MESSAGE_INPUT,
            payload,
            verify=False,
            timeout=timeout,
        )

    def message_exists(self, content: str, timeout: Optional[int] = 10) -> bool:
        locators = (
            self.locators.message_text_exact(content),
            self.locators.message_text(content),
        )

        def _found_message() -> bool:
            return any(self.find_element_safe(locator, timeout=2) for locator in locators)

        return self.wait_for_condition(_found_message, timeout=timeout)

    def dismiss_introduce_prompt(self, timeout: Optional[int] = 2) -> bool:
        element = self.find_element_safe(self.locators.INTRODUCE_SKIP_BUTTON, timeout=timeout)
        if not element:
            return False
        try:
            element.click()
            return True
        except Exception as e:
            self.logger.debug(f"dismiss_introduce_prompt direct click failed: {e}")
            try:
                return self.safe_click(self.locators.INTRODUCE_SKIP_BUTTON, timeout=timeout)
            except Exception as e2:
                self.logger.debug(f"dismiss_introduce_prompt click also failed: {e2}")
                return False

    def dismiss_backup_prompt(self, timeout: Optional[int] = 2) -> bool:
        element = self.find_element_safe(self.locators.BACKUP_SKIP_BUTTON, timeout=timeout)
        if not element:
            return False
        try:
            element.click()
            return True
        except Exception as e:
            self.logger.debug(f"dismiss_backup_prompt direct click failed: {e}")
            try:
                return self.safe_click(self.locators.BACKUP_SKIP_BUTTON, timeout=timeout)
            except Exception as e2:
                self.logger.debug(f"dismiss_backup_prompt click also failed: {e2}")
                return False

    def wait_for_new_chat_to_arrive(
        self,
        chat_identifier: str,
        *,
        display_name: Optional[str] = None,
        timeout: int = 60,
    ) -> bool:
        self.dismiss_introduce_prompt(timeout=2)

        if self.is_element_visible(self.locators.MESSAGE_INPUT, timeout=2):
            return True

        self._ensure_chat_list_visible()
        locators = self._resolve_chat_locators(chat_identifier, display_name)
        return self.wait_for_condition(
            lambda: any(self.find_element_safe(loc, timeout=1) for loc in locators),
            timeout=timeout,
            poll_interval=1.0,
        )

    def is_chat_selected(
        self,
        chat_identifier: str,
        *,
        display_name: Optional[str] = None,
        timeout: Optional[int] = 4,
    ) -> bool:
        locators = self._resolve_chat_locators(chat_identifier, display_name)
        element = None
        for locator in locators:
            element = self.find_element_safe(locator, timeout=timeout)
            if element:
                break
        if not element:
            return False
        try:
            return str(element.get_attribute("selected")).lower() == "true"
        except Exception as e:
            self.logger.debug(f"is_chat_selected attribute read failed: {e}")
            return False


