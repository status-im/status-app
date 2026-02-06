from typing import Optional

from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.actions import interaction
from selenium.webdriver.common.actions.action_builder import ActionBuilder
from selenium.webdriver.common.actions.pointer_input import PointerInput

from ..base_page import BasePage
from locators.messaging.message_context_menu_locators import (
    MessageContextMenuLocators,
    EmojiPickerLocators,
)
from locators.messaging.chat_locators import ChatLocators


class MessageContextMenuPage(BasePage):
    """Page object for the Message Context Menu.
    
    Provides actions for interacting with messages via the context menu:
    - Reply to message
    - Edit message (own messages only)
    - Delete message (own messages only)
    - Copy message
    - Pin/Unpin message
    - React with emoji
    
    Usage:
        chat_page = ChatPage(driver)
        chat_page.send_message("Hello")
        
        context_menu = MessageContextMenuPage(driver)
        context_menu.long_press_message("Hello")
        context_menu.tap_reply()
    """

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = MessageContextMenuLocators()
        self.emoji_locators = EmojiPickerLocators()
        self.chat_locators = ChatLocators()

    def is_displayed(self, timeout: int = 5) -> bool:
        """Check if the context menu is currently visible."""
        return self.is_element_visible(self.locators.MENU_CONTAINER, timeout=timeout)

    def wait_until_hidden(self, timeout: int = 10) -> bool:
        """Wait for the context menu to close."""
        return self.wait_for_condition(
            lambda: not self.is_displayed(timeout=1),
            timeout=timeout,
            poll_interval=0.5,
        )

    def long_press_message(
        self,
        message_content: str,
        timeout: int = 10,
        duration_ms: int = 1000,
    ) -> bool:
        """Long-press on a message to open the context menu.
        
        Args:
            message_content: The text content of the message to long-press.
            timeout: Maximum wait time to find the message.
            duration_ms: Duration of the long-press gesture in milliseconds.
            
        Returns:
            bool: True if context menu opened successfully.
        """
        # Try exact match first, then partial match
        locators = (
            self.chat_locators.message_text_exact(message_content),
            self.chat_locators.message_text(message_content),
        )
        
        element = None
        for locator in locators:
            element = self.find_element_safe(locator, timeout=timeout // 2)
            if element:
                break
        
        if not element:
            self.logger.error(f"Message '{message_content}' not found")
            return False

        try:
            # Use W3C Actions for long-press
            actions = ActionBuilder(
                self.driver,
                mouse=PointerInput(interaction.POINTER_TOUCH, "finger"),
            )
            actions.pointer_action.move_to(element)
            actions.pointer_action.pointer_down()
            actions.pointer_action.pause(duration_ms / 1000)
            actions.pointer_action.pointer_up()
            actions.perform()
            
            # Wait for menu to appear
            if self.is_displayed(timeout=5):
                self.logger.info(f"Context menu opened for message '{message_content}'")
                return True
            
            self.logger.warning("Context menu did not appear after long-press")
            return False
            
        except Exception as e:
            self.logger.error(f"Long-press failed: {e}")
            return False

    def long_press_message_by_element(
        self,
        element,
        duration_ms: int = 1000,
    ) -> bool:
        """Long-press on a message element to open the context menu.
        
        Args:
            element: WebElement of the message to long-press.
            duration_ms: Duration of the long-press gesture in milliseconds.
            
        Returns:
            bool: True if context menu opened successfully.
        """
        try:
            actions = ActionBuilder(
                self.driver,
                mouse=PointerInput(interaction.POINTER_TOUCH, "finger"),
            )
            actions.pointer_action.move_to(element)
            actions.pointer_action.pointer_down()
            actions.pointer_action.pause(duration_ms / 1000)
            actions.pointer_action.pointer_up()
            actions.perform()
            
            return self.is_displayed(timeout=5)
        except Exception as e:
            self.logger.error(f"Long-press on element failed: {e}")
            return False

    def _tap_menu_action(self, locator: tuple, action_name: str, timeout: int = 5) -> bool:
        """Tap a menu action and wait for menu to close."""
        if not self.is_displayed(timeout=2):
            self.logger.error(f"Context menu not visible when trying to tap {action_name}")
            return False
        
        if not self.safe_click(locator, timeout=timeout):
            self.logger.error(f"Failed to tap {action_name}")
            return False
        
        self.logger.info(f"Tapped {action_name}")
        return True

    # ===== Primary Actions =====

    def tap_reply(self, timeout: int = 5) -> bool:
        """Tap 'Reply to' to start replying to the message.
        
        Returns:
            bool: True if reply action was triggered.
        """
        return self._tap_menu_action(self.locators.REPLY_TO, "Reply to", timeout)

    def tap_edit(self, timeout: int = 5) -> bool:
        """Tap 'Edit message' to edit own message.
        
        Note: Only visible for user's own messages.
        
        Returns:
            bool: True if edit action was triggered.
        """
        return self._tap_menu_action(self.locators.EDIT_MESSAGE, "Edit message", timeout)

    def tap_delete(self, timeout: int = 5) -> bool:
        """Tap 'Delete message' to delete own message.
        
        Note: Only visible for user's own messages or if user is admin.
        
        Returns:
            bool: True if delete action was triggered.
        """
        return self._tap_menu_action(self.locators.DELETE_MESSAGE, "Delete message", timeout)

    def tap_copy(self, timeout: int = 5) -> bool:
        """Tap 'Copy message' to copy message text to clipboard.
        
        Returns:
            bool: True if copy action was triggered.
        """
        return self._tap_menu_action(self.locators.COPY_MESSAGE, "Copy message", timeout)

    def tap_pin(self, timeout: int = 5) -> bool:
        """Tap 'Pin' or 'Unpin' to toggle message pin status.
        
        Returns:
            bool: True if pin/unpin action was triggered.
        """
        return self._tap_menu_action(self.locators.PIN_MESSAGE, "Pin/Unpin", timeout)

    def tap_mark_as_unread(self, timeout: int = 5) -> bool:
        """Tap 'Mark as unread' to mark conversation unread from this message.
        
        Returns:
            bool: True if mark as unread action was triggered.
        """
        return self._tap_menu_action(self.locators.MARK_AS_UNREAD, "Mark as unread", timeout)

    def tap_copy_message_id(self, timeout: int = 5) -> bool:
        """Tap 'Copy Message Id' to copy message ID (debug feature).
        
        Note: Only visible when debug mode is enabled.
        
        Returns:
            bool: True if copy ID action was triggered.
        """
        return self._tap_menu_action(self.locators.COPY_MESSAGE_ID, "Copy Message Id", timeout)

    # ===== Reactions =====

    def tap_quick_reaction(self, emoji: str, timeout: int = 5) -> bool:
        """Tap a quick reaction emoji from the reactions row.
        
        Args:
            emoji: The emoji character (e.g., '👍', '❤', '😂')
            timeout: Maximum wait time.
            
        Returns:
            bool: True if reaction was added.
        """
        locator = self.locators.quick_reaction_by_emoji(emoji)
        if not self.safe_click(locator, timeout=timeout):
            self.logger.error(f"Failed to tap quick reaction '{emoji}'")
            return False
        
        self.logger.info(f"Added quick reaction '{emoji}'")
        return True

    # ===== Default Quick Reactions (shown in context menu) =====
    # These are the default quick reactions visible in the menu row
    
    def tap_grin(self, timeout: int = 5) -> bool:
        """Add grinning face (😀) reaction - first quick reaction."""
        return self._tap_menu_action(self.locators.REACTION_GRIN, "😀 reaction", timeout)

    def tap_smiley(self, timeout: int = 5) -> bool:
        """Add smiley (😃) reaction - second quick reaction."""
        return self._tap_menu_action(self.locators.REACTION_SMILEY, "😃 reaction", timeout)

    def tap_smile(self, timeout: int = 5) -> bool:
        """Add smile (😄) reaction - third quick reaction."""
        return self._tap_menu_action(self.locators.REACTION_SMILE, "😄 reaction", timeout)

    def tap_beam(self, timeout: int = 5) -> bool:
        """Add beaming (😁) reaction - fourth quick reaction."""
        return self._tap_menu_action(self.locators.REACTION_BEAM, "😁 reaction", timeout)

    def tap_laugh(self, timeout: int = 5) -> bool:
        """Add laughing (😆) reaction - fifth quick reaction."""
        return self._tap_menu_action(self.locators.REACTION_LAUGH, "😆 reaction", timeout)

    # ===== Additional Reactions (via emoji picker) =====
    # These may not be in the quick reactions row - use open_emoji_picker() first
    
    def tap_thumbs_up(self, timeout: int = 5) -> bool:
        """Add thumbs up (👍) reaction. May require emoji picker."""
        return self._tap_menu_action(self.locators.REACTION_THUMBS_UP, "👍 reaction", timeout)

    def tap_thumbs_down(self, timeout: int = 5) -> bool:
        """Add thumbs down (👎) reaction. May require emoji picker."""
        return self._tap_menu_action(self.locators.REACTION_THUMBS_DOWN, "👎 reaction", timeout)

    def tap_heart(self, timeout: int = 5) -> bool:
        """Add heart (❤) reaction. May require emoji picker."""
        return self._tap_menu_action(self.locators.REACTION_HEART, "❤ reaction", timeout)

    def tap_joy(self, timeout: int = 5) -> bool:
        """Add joy/tears of joy (😂) reaction. May require emoji picker."""
        return self._tap_menu_action(self.locators.REACTION_JOY, "😂 reaction", timeout)

    def tap_sad(self, timeout: int = 5) -> bool:
        """Add sad (😢) reaction. May require emoji picker."""
        return self._tap_menu_action(self.locators.REACTION_SAD, "😢 reaction", timeout)

    def tap_angry(self, timeout: int = 5) -> bool:
        """Add angry (😡) reaction. May require emoji picker."""
        return self._tap_menu_action(self.locators.REACTION_ANGRY, "😡 reaction", timeout)

    def open_emoji_picker(self, timeout: int = 5) -> bool:
        """Tap 'Add reaction' to open the full emoji picker.
        
        Returns:
            bool: True if emoji picker opened.
        """
        if not self.safe_click(self.locators.ADD_REACTION_BUTTON, timeout=timeout):
            self.logger.error("Failed to tap Add reaction button")
            return False
        
        if self.is_element_visible(self.emoji_locators.POPUP_CONTAINER, timeout=5):
            self.logger.info("Emoji picker opened")
            return True
        
        self.logger.warning("Emoji picker did not appear")
        return False

    def select_emoji_from_picker(self, emoji: str, timeout: int = 5) -> bool:
        """Select an emoji from the emoji picker popup.
        
        Args:
            emoji: The emoji character to select.
            timeout: Maximum wait time.
            
        Returns:
            bool: True if emoji was selected.
        """
        locator = self.emoji_locators.emoji_by_character(emoji)
        if not self.safe_click(locator, timeout=timeout):
            self.logger.error(f"Failed to select emoji '{emoji}' from picker")
            return False
        
        self.logger.info(f"Selected emoji '{emoji}' from picker")
        return True

    def dismiss(self, timeout: int = 5) -> bool:
        """Dismiss the context menu by tapping outside.
        
        Returns:
            bool: True if menu was dismissed.
        """
        if not self.is_displayed(timeout=2):
            return True  # Already dismissed
        
        try:
            # Tap outside the menu area (top of screen)
            size = self.driver.get_window_size()
            x = int(size["width"] * 0.5)
            y = int(size["height"] * 0.1)
            
            actions = ActionBuilder(
                self.driver,
                mouse=PointerInput(interaction.POINTER_TOUCH, "finger"),
            )
            actions.pointer_action.move_to_location(x, y)
            actions.pointer_action.click()
            actions.perform()
            
            return self.wait_until_hidden(timeout=timeout)
        except Exception as e:
            self.logger.error(f"Failed to dismiss context menu: {e}")
            return False

    # ===== Action Visibility Checks =====

    def is_reply_visible(self, timeout: int = 2) -> bool:
        """Check if Reply action is visible in the menu."""
        return self.is_element_visible(self.locators.REPLY_TO, timeout=timeout)

    def is_edit_visible(self, timeout: int = 2) -> bool:
        """Check if Edit action is visible (own messages only)."""
        return self.is_element_visible(self.locators.EDIT_MESSAGE, timeout=timeout)

    def is_delete_visible(self, timeout: int = 2) -> bool:
        """Check if Delete action is visible (own messages or admin)."""
        return self.is_element_visible(self.locators.DELETE_MESSAGE, timeout=timeout)

    def is_copy_visible(self, timeout: int = 2) -> bool:
        """Check if Copy action is visible."""
        return self.is_element_visible(self.locators.COPY_MESSAGE, timeout=timeout)

    def is_pin_visible(self, timeout: int = 2) -> bool:
        """Check if Pin/Unpin action is visible."""
        return self.is_element_visible(self.locators.PIN_MESSAGE, timeout=timeout)

    # ===== Compound Actions =====

    def reply_to_message(
        self,
        message_content: str,
        reply_text: str,
        timeout: int = 10,
    ) -> bool:
        """Long-press a message and reply to it.
        
        Args:
            message_content: The message text to reply to.
            reply_text: The reply message text.
            timeout: Maximum wait time for each operation.
            
        Returns:
            bool: True if reply was sent successfully.
        """
        if not self.long_press_message(message_content, timeout=timeout):
            return False
        
        if not self.tap_reply(timeout=timeout):
            return False
        
        # Type and send the reply (assumes reply input is focused)
        from pages.messaging.chat_page import ChatPage
        chat = ChatPage(self.driver)
        return chat.send_message(reply_text, timeout=timeout)

    def confirm_delete(self, timeout: int = 5) -> bool:
        """Confirm the delete message dialog.
        
        Call this after tap_delete() when the confirmation dialog appears.
        
        Returns:
            bool: True if confirmation was successful.
        """
        # Wait for confirmation dialog
        if not self.is_element_visible(
            self.locators.DELETE_CONFIRMATION_DIALOG, timeout=timeout
        ):
            self.logger.warning("Delete confirmation dialog not visible")
            return False
        
        if not self.safe_click(self.locators.DELETE_CONFIRMATION_BUTTON, timeout=timeout):
            self.logger.error("Failed to click delete confirmation button")
            return False
        
        self.logger.info("Confirmed message deletion")
        return True

    def delete_message(self, message_content: str, timeout: int = 10) -> bool:
        """Long-press a message and delete it (with confirmation).
        
        Args:
            message_content: The message text to delete.
            timeout: Maximum wait time for each operation.
            
        Returns:
            bool: True if message was deleted.
        """
        if not self.long_press_message(message_content, timeout=timeout):
            return False
        
        if not self.tap_delete(timeout=timeout):
            return False
        
        # Handle confirmation dialog
        return self.confirm_delete(timeout=timeout)

    def react_to_message(
        self,
        message_content: str,
        emoji: str = "👍",
        timeout: int = 10,
    ) -> bool:
        """Long-press a message and add a reaction.
        
        Args:
            message_content: The message text to react to.
            emoji: The emoji to react with (default: thumbs up).
            timeout: Maximum wait time for each operation.
            
        Returns:
            bool: True if reaction was added.
        """
        if not self.long_press_message(message_content, timeout=timeout):
            return False
        
        return self.tap_quick_reaction(emoji, timeout=timeout)
