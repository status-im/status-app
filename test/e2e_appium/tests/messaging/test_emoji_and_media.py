"""Tests for emoji and media coverage in messaging."""

import pytest

from config.logging_config import get_logger
from pages.app import App
from pages.messaging.chat_page import ChatPage
from pages.messaging.message_context_menu_page import MessageContextMenuPage
from utils.generators import generate_account_name


def _unique_message(prefix: str) -> str:
    return f"{prefix}_{generate_account_name(8)}"


@pytest.mark.messaging
@pytest.mark.smoke
@pytest.mark.device_count(2)
class TestEmojiAndMedia:
    """Emoji and media coverage for 1:1 chats."""

    UI_TIMEOUT = 30
    logger = get_logger("TestEmojiAndMedia")

    @pytest.fixture(autouse=True)
    def setup(self, established_chat):
        self.ctx = established_chat
        self.primary = established_chat.primary
        self.secondary = established_chat.secondary
        self.driver = established_chat.primary.driver
        self.primary_suffix = established_chat.primary_suffix
        self.secondary_suffix = established_chat.secondary_suffix

    def _ensure_in_chat(self) -> ChatPage:
        app = App(self.driver)
        chat_page = ChatPage(self.driver)

        if chat_page.wait_for_message_input(timeout=5):
            return chat_page

        self.logger.info("Navigating to Messages tab")
        assert app.click_messages_button(), "Failed to open Messages tab"
        chat_page.dismiss_backup_prompt(timeout=3)

        if chat_page.wait_for_message_input(timeout=5):
            return chat_page

        display_name = (
            self.secondary.user.display_name if self.secondary and self.secondary.user else None
        )
        assert chat_page.open_chat_by_suffix(
            self.secondary_suffix,
            display_name=display_name,
            timeout=15,
        ), "Failed to open chat by suffix"
        assert chat_page.wait_for_message_input(timeout=10), "Message input not ready"
        return chat_page

    async def test_send_emoji_via_picker(self) -> None:
        chat_page = self._ensure_in_chat()

        emoji_search = "thumbsup"
        starting_count = chat_page.message_count()

        chat_page.dump_page_source("before_emoji_click")

        assert chat_page.send_emoji_to_chat(
            emoji_search,
            timeout=self.UI_TIMEOUT,
        ), "Failed to send emoji via picker"

        chat_page.dump_page_source("emoji_message_check")

        assert chat_page.wait_for_message_count(
            starting_count + 1,
            timeout=self.UI_TIMEOUT,
        ), "Emoji message should appear in chat"

    async def test_reply_shows_corner_indicator(self) -> None:
        chat_page = self._ensure_in_chat()
        context_menu = MessageContextMenuPage(self.driver)

        original_msg = _unique_message("orig")
        reply_msg = _unique_message("reply")

        assert chat_page.send_message(original_msg), "Failed to send original message"
        assert chat_page.message_exists(original_msg), "Original message not visible"

        assert context_menu.long_press_message(original_msg), "Failed to open context menu"
        assert context_menu.tap_reply(), "Failed to tap Reply action"
        assert chat_page.is_reply_mode_active(
            timeout=5,
        ), "Reply preview bar should be visible"

        assert chat_page.send_message(reply_msg), "Failed to send reply message"
        assert chat_page.message_exists(reply_msg), "Reply message not visible"

        chat_page.dump_page_source("before_reply_details_check")

        assert chat_page.is_element_visible(
            chat_page.locators.REPLY_DETAILS,
            timeout=self.UI_TIMEOUT,
        ), "Reply details should be visible on the reply message"

    @pytest.mark.skip(reason="File dialog automation not supported in Appium environment")
    async def test_image_dialog_opens(self) -> None:
        chat_page = self._ensure_in_chat()
        assert chat_page.open_image_dialog(
            timeout=self.UI_TIMEOUT,
        ), "Failed to open image dialog"
