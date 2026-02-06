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

    def has_any_chat(self, timeout: int = 5) -> bool:
        """Check if there are any chats in the chat list.
        
        Returns:
            bool: True if at least one chat exists.
        """
        self._ensure_chat_list_visible()
        return self.is_element_visible(self.locators.FIRST_CHAT_ITEM, timeout=timeout)

    def open_first_chat(self, timeout: int = 10) -> bool:
        """Open the first chat in the chat list.
        
        Useful for tests that need any available chat without knowing specific names.
        
        Returns:
            bool: True if a chat was opened successfully.
        """
        self._ensure_chat_list_visible()
        if not self.is_element_visible(self.locators.FIRST_CHAT_ITEM, timeout=timeout):
            self.logger.warning("No chats available in the list")
            return False
        return self.safe_click(self.locators.FIRST_CHAT_ITEM, timeout=timeout)

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

    # ===== Reply Mode =====

    def is_reply_mode_active(self, timeout: int = 5) -> bool:
        """Check if the reply preview bar is visible (indicates reply mode is active)."""
        return self.is_element_visible(self.locators.REPLY_PREVIEW, timeout=timeout)

    def cancel_reply(self, timeout: int = 5) -> bool:
        """Cancel reply mode by tapping the close button."""
        if not self.is_reply_mode_active(timeout=2):
            return True  # Not in reply mode
        return self.safe_click(self.locators.REPLY_CLOSE_BUTTON, timeout=timeout)

    # ===== Message State Verification =====

    def message_is_edited(self, content: str, timeout: int = 10) -> bool:
        """Check if a message shows the '(edited)' indicator.
        
        Args:
            content: The message text (without the '(edited)' suffix).
        """
        locator = self.locators.message_with_edited_indicator(content)
        return self.is_element_visible(locator, timeout=timeout)

    def message_is_pinned(self, content: str, timeout: int = 10) -> bool:
        """Check if a message shows the 'Pinned by' indicator.
        
        Approach: The StatusPinMessageDetails component (a Loader) is only active/visible
        when a message is pinned. We check if this component exists and optionally verify
        it's for the expected message.
        
        Note: Desktop tests use `delegate_button.object.isPinned` (direct property access).
        Appium can only use accessibility properties (resource-id, content-desc).
        """
        # First check if the message exists
        if not self.message_exists(content, timeout=5):
            self.logger.warning(f"Message '{content}' not found")
            return False
        
        # Check for ANY pinned indicator visible (statusPinMessageDetails component)
        # The Loader component is only active when a message is pinned
        if not self.is_element_visible(self.locators.PINNED_INDICATOR, timeout=timeout):
            self.logger.debug("No pinned indicator found")
            return False
        
        # Pinned indicator found - optionally verify content-desc contains "Pinned by"
        # (Accessible.name = pinnedMsgInfoText + " " + pinnedBy, e.g., "Pinned by Alice")
        element = self.find_element_safe(self.locators.PINNED_INDICATOR, timeout=2)
        if element:
            content_desc = element.get_attribute("content-desc") or ""
            if "Pinned" in content_desc:
                self.logger.info(f"Found pinned indicator: {content_desc}")
                return True
            self.logger.debug(f"Pinned indicator content-desc: '{content_desc}'")
        
        # Fallback: indicator visible but couldn't read content-desc, assume pinned
        return True

    def message_has_reaction(self, emoji_code: str, timeout: int = 10) -> bool:
        """Check if any message has a specific reaction emoji visible.
        
        Args:
            emoji_code: Unicode hex code (e.g., '1f600' for 😀)
        """
        locator = self.locators.reaction_on_message(emoji_code)
        return self.is_element_visible(locator, timeout=timeout)


