"""Tests for emoji and media coverage in messaging."""

import pytest

from config.logging_config import get_logger
from pages.app import App
from pages.messaging.chat_page import ChatPage
from pages.messaging.message_context_menu_page import MessageContextMenuPage
from utils.generators import generate_account_name
from utils.timeouts import CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS


def _unique_message(prefix: str) -> str:
    return f"{prefix}_{generate_account_name(8)}"


@pytest.mark.messaging
@pytest.mark.portrait
@pytest.mark.smoke
@pytest.mark.device_count(2)
class TestEmojiAndMedia:
    """Emoji and media coverage for 1:1 chats."""

    UI_TIMEOUT = 30
    CROSS_DEVICE_TIMEOUT = CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS
    logger = get_logger("TestEmojiAndMedia")

    @pytest.fixture(autouse=True)
    def setup(self, chat_ready):
        self.ctx = chat_ready
        self.primary = chat_ready.primary
        self.secondary = chat_ready.secondary
        self.driver = chat_ready.primary.driver
        self.primary_suffix = chat_ready.primary_suffix
        self.secondary_suffix = chat_ready.secondary_suffix

    def _ensure_in_chat(self) -> ChatPage:
        app = App(self.driver)
        chat_page = ChatPage(self.driver)

        if chat_page.wait_for_message_input(timeout=5):
            return chat_page

        self.logger.info("Navigating to Messages tab")
        chat_page.dismiss_backup_prompt(timeout=3)
        assert app.click_messages_button(), "Failed to open Messages tab"
        chat_page.dismiss_backup_prompt(timeout=2)

        if chat_page.wait_for_message_input(timeout=5):
            return chat_page

        display_name = (
            self.secondary.user.display_name if self.secondary and self.secondary.user else None
        )
        assert chat_page.open_chat_by_suffix(
            self.secondary_suffix,
            display_name=display_name,
            timeout=self.CROSS_DEVICE_TIMEOUT,
        ), "Failed to open chat by suffix"
        assert chat_page.wait_for_message_input(timeout=10), "Message input not ready"
        return chat_page

    @pytest.mark.xfail(reason="status-go#7393: cross-device delivery unreliable", strict=False)
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

    @pytest.mark.gate
    @pytest.mark.spec("SC-MTYP-04")
    @pytest.mark.flaky(reruns=1, reruns_delay=5)
    async def test_emoji_received_cross_device(self) -> None:
        """Verify emoji message is delivered to the receiving device.

        Desktop parity: D7 from test_messaging_1x1_chat.py verifies emoji
        character in unparsedText on both sender and receiver.

        Note: emoji content is not assertable via content-desc — Emoji.parse()
        converts the unicode character to an <img> tag in the QML RichText
        renderer, leaving the accessibility label empty.  We assert delivery
        via message count instead.  Content assertion requires adding
        Accessible.name to StatusTextMessage_chatText (QML change, tracked
        separately in OXI-123).
        """
        # Navigate secondary into chat and capture baseline count BEFORE
        # primary sends, so we have a reliable baseline to wait against.
        secondary_chat = ChatPage(self.secondary.driver)
        secondary_app = App(self.secondary.driver)

        if not secondary_chat.wait_for_message_input(timeout=3):
            secondary_chat.dismiss_backup_prompt(timeout=3)
            secondary_app.click_messages_button()
            secondary_chat.dismiss_backup_prompt(timeout=2)

            display_name = (
                self.primary.user.display_name if self.primary and self.primary.user else None
            )
            secondary_chat.open_chat_by_suffix(
                self.primary_suffix,
                display_name=display_name,
                timeout=self.CROSS_DEVICE_TIMEOUT,
            )
            secondary_chat.wait_for_message_input(timeout=10)

        secondary_count_before = secondary_chat.message_count()

        chat_page = self._ensure_in_chat()
        primary_count_before = chat_page.message_count()

        assert chat_page.send_emoji_to_chat(
            "thumbsup",
            timeout=self.UI_TIMEOUT,
        ), "Failed to send emoji via picker"

        assert chat_page.wait_for_message_count(
            primary_count_before + 1,
            timeout=self.UI_TIMEOUT,
        ), "Primary: Emoji message should appear in chat"

        assert secondary_chat.wait_for_message_count(
            secondary_count_before + 1,
            timeout=self.CROSS_DEVICE_TIMEOUT,
        ), "Secondary: Emoji message should be delivered (cross-device sync)"

    @pytest.mark.xfail(reason="status-go#7393: cross-device delivery unreliable", strict=False)
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

    @pytest.mark.skip(
        reason="D8 image send: native file picker (StatusFileDialog) cannot be "
        "automated via Appium. Requires BrowserStack pushFile API integration "
        "and adb share intent (~6h infrastructure work). Parked as manual-only "
        "coverage — revisit when pushFile infra is built. See OXI-123."
    )
    async def test_image_dialog_opens(self) -> None:
        chat_page = self._ensure_in_chat()
        assert chat_page.open_image_dialog(
            timeout=self.UI_TIMEOUT,
        ), "Failed to open image dialog"
