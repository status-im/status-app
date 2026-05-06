"""Tests for chat management actions (clear history, close chat).

These tests are destructive — they alter the chat session state — so they
live in their own module with a dedicated established_chat fixture scope.
"""

import asyncio
import uuid
from contextlib import asynccontextmanager

import pytest

from config.logging_config import get_logger
from pages.app import App
from pages.messaging.chat_page import ChatPage
from utils.timeouts import cross_device_timeout


def _unique_message(prefix: str = "test") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:8]}"


@pytest.mark.messaging
@pytest.mark.portrait
@pytest.mark.device_count(2)
@pytest.mark.timeout(1200)
@pytest.mark.flaky(reruns=1, reruns_delay=5)
class TestChatManagement:
    """Tests for chat-level management actions.

    Tests in this class are destructive (clear/close) and live in their own
    module so they don't share state with tests that depend on intact
    message history.
    """

    UI_TIMEOUT = 30
    # Env-aware: 180s on Pi LAN, 300s on BrowserStack cloud.
    # See utils/timeouts.cross_device_timeout for rationale.
    CROSS_DEVICE_TIMEOUT = cross_device_timeout()
    logger = get_logger("TestChatManagement")

    @pytest.fixture(autouse=True)
    def setup(self, chat_ready):
        self.ctx = chat_ready
        self.driver = chat_ready.primary.driver
        self.device = chat_ready.primary

    @asynccontextmanager
    async def step(self, description: str):
        self.logger.info(f"Step: {description}")
        yield
        self.logger.info(f"Completed: {description}")

    async def _ensure_in_chat(self) -> ChatPage:
        """Ensure primary is in the chat with message input visible."""
        app = App(self.driver)
        chat_page = ChatPage(self.driver)

        if chat_page.is_element_visible(chat_page.locators.MESSAGE_INPUT, timeout=2):
            return chat_page

        chat_page.dismiss_backup_prompt(timeout=3)
        app.click_messages_button()
        chat_page.dismiss_backup_prompt(timeout=2)
        await asyncio.sleep(0.5)

        if chat_page.wait_for_message_input(timeout=5):
            return chat_page

        if self.ctx.secondary_suffix:
            secondary_name = None
            if self.ctx.secondary.user:
                secondary_name = self.ctx.secondary.user.display_name

            if chat_page.open_chat_by_suffix(
                self.ctx.secondary_suffix,
                display_name=secondary_name,
            ):
                if chat_page.wait_for_message_input(timeout=self.UI_TIMEOUT):
                    return chat_page

        if chat_page.open_first_chat(timeout=self.UI_TIMEOUT):
            if chat_page.wait_for_message_input(timeout=self.UI_TIMEOUT):
                return chat_page

        raise AssertionError(
            "Could not navigate to a chat with message input."
        )

    async def _ensure_secondary_in_chat(self) -> ChatPage:
        """Ensure secondary device is in the chat with primary."""
        secondary_chat = ChatPage(self.ctx.secondary.driver)
        secondary_app = App(self.ctx.secondary.driver)

        if secondary_chat.is_element_visible(secondary_chat.locators.MESSAGE_INPUT, timeout=2):
            return secondary_chat

        secondary_chat.dismiss_backup_prompt(timeout=3)
        secondary_app.click_messages_button()
        secondary_chat.dismiss_backup_prompt(timeout=2)
        await asyncio.sleep(0.5)

        if self.ctx.primary_suffix:
            primary_name = None
            if self.ctx.primary.user:
                primary_name = self.ctx.primary.user.display_name

            if secondary_chat.open_chat_by_suffix(
                self.ctx.primary_suffix,
                display_name=primary_name,
            ):
                if secondary_chat.wait_for_message_input(timeout=self.UI_TIMEOUT):
                    return secondary_chat

        if secondary_chat.open_first_chat(timeout=self.UI_TIMEOUT):
            secondary_chat.wait_for_message_input(timeout=self.UI_TIMEOUT)

        return secondary_chat

    @pytest.mark.gate
    @pytest.mark.smoke
    @pytest.mark.spec("SC-DM-07")
    async def test_clear_history_is_local_only(self) -> None:
        """Verify clearing chat history only affects the local device.

        Desktop parity: D12 from test_messaging_1x1_chat.py verifies
        len(messages) == 0 on clearer, chat still in list, and the
        other user's history remains intact.
        """
        marker_msg = _unique_message("clear_hist")

        async with self.step("Send a marker message from primary"):
            chat_page = await self._ensure_in_chat()
            assert chat_page.send_message(marker_msg), (
                "Failed to send marker message"
            )
            assert chat_page.message_exists(marker_msg, timeout=self.UI_TIMEOUT), (
                "Marker message not visible on primary"
            )

        async with self.step("Verify marker message on secondary"):
            secondary_chat = await self._ensure_secondary_in_chat()
            assert secondary_chat.message_exists(marker_msg, timeout=self.CROSS_DEVICE_TIMEOUT), (
                "Secondary should see marker message before clear"
            )

        async with self.step("Clear history on primary"):
            assert chat_page.clear_history(timeout=self.UI_TIMEOUT), (
                "Failed to clear chat history"
            )

        async with self.step("Verify no messages on primary after clear"):
            # After clearing, we may still be in the chat view or
            # returned to the chat list. Re-enter the chat if needed.
            await asyncio.sleep(1)  # Let UI settle after clear
            if not chat_page.is_element_visible(
                chat_page.locators.MESSAGE_INPUT, timeout=3,
            ):
                # Clear may have navigated back to chat list — re-open
                chat_page = await self._ensure_in_chat()

            assert not chat_page.message_exists(marker_msg, timeout=5), (
                "Primary: Marker message should be gone after clearing history"
            )
            assert chat_page.message_count() == 0, (
                "Primary: No messages should remain after clearing history"
            )

        async with self.step("Verify chat still in primary's chat list"):
            app = App(self.driver)
            chat_page.dismiss_backup_prompt(timeout=3)
            app.click_messages_button()
            chat_page.dismiss_backup_prompt(timeout=2)
            await asyncio.sleep(0.5)

            secondary_name = None
            if self.ctx.secondary.user:
                secondary_name = self.ctx.secondary.user.display_name

            assert chat_page.chat_exists_in_list(
                self.ctx.secondary_suffix,
                display_name=secondary_name,
                timeout=self.UI_TIMEOUT,
            ), "Primary: Chat should still appear in chat list after clearing history"

        async with self.step("Verify secondary's messages are intact"):
            # Re-enter secondary's chat to confirm messages survived
            secondary_chat = await self._ensure_secondary_in_chat()
            assert secondary_chat.message_exists(marker_msg, timeout=self.CROSS_DEVICE_TIMEOUT), (
                "Secondary: Marker message should still be visible — "
                "clear history must be local only"
            )

    @pytest.mark.gate
    @pytest.mark.smoke
    @pytest.mark.spec("SC-DM-06")
    async def test_close_chat_is_local_only(self) -> None:
        """Verify closing a chat only removes it for the closer.

        Desktop parity: D13 from test_messaging_1x1_chat.py verifies
        user not in get_chats_names for closer, user in get_chats_names
        for other.

        Must run after test_clear_history_is_local_only — closing the
        chat destroys the shared session's chat context.
        """
        async with self.step("Ensure primary is in the chat"):
            chat_page = await self._ensure_in_chat()

        async with self.step("Close chat on primary"):
            assert chat_page.close_chat(timeout=self.UI_TIMEOUT), (
                "Failed to close chat"
            )

        async with self.step("Verify chat NOT in primary's chat list"):
            await asyncio.sleep(1)  # Let UI settle after close
            app = App(self.driver)
            chat_page.dismiss_backup_prompt(timeout=3)
            app.click_messages_button()
            chat_page.dismiss_backup_prompt(timeout=2)
            await asyncio.sleep(0.5)

            secondary_name = None
            if self.ctx.secondary.user:
                secondary_name = self.ctx.secondary.user.display_name

            assert not chat_page.chat_exists_in_list(
                self.ctx.secondary_suffix,
                display_name=secondary_name,
                timeout=10,
            ), "Primary: Chat should NOT appear in chat list after closing"

        async with self.step("Verify chat still in secondary's chat list"):
            secondary_chat = ChatPage(self.ctx.secondary.driver)
            secondary_app = App(self.ctx.secondary.driver)

            secondary_chat.dismiss_backup_prompt(timeout=3)
            secondary_app.click_messages_button()
            secondary_chat.dismiss_backup_prompt(timeout=2)
            await asyncio.sleep(0.5)

            primary_name = None
            if self.ctx.primary.user:
                primary_name = self.ctx.primary.user.display_name

            assert secondary_chat.chat_exists_in_list(
                self.ctx.primary_suffix,
                display_name=primary_name,
                timeout=self.UI_TIMEOUT,
            ), "Secondary: Chat should still appear in chat list — close is local only"
