"""Tests for Message Context Menu functionality.

Tests the long-press context menu on messages including:
- Menu visibility and actions
- Quick reactions
- Reply, Edit, Delete, Copy, Pin actions

These tests use a module-scoped fixture that establishes a chat once,
then all tests in this module share that session.
"""

import asyncio
import uuid
from contextlib import asynccontextmanager

import pytest

from config.logging_config import get_logger
from pages.app import App
from pages.messaging.chat_page import ChatPage
from pages.messaging.message_context_menu_page import MessageContextMenuPage


def _unique_message(prefix: str = "test") -> str:
    """Generate a unique test message."""
    return f"{prefix}_{uuid.uuid4().hex[:8]}"


@pytest.mark.messaging
@pytest.mark.device_count(2)
@pytest.mark.timeout(1200)
@pytest.mark.flaky(reruns=1, reruns_delay=5)
class TestMessageContextMenu:
    """Tests for message context menu interactions.
    
    Uses module-scoped established_chat fixture for shared session.
    Each test sends its own unique message to operate on.
    """

    UI_TIMEOUT = 30
    logger = get_logger("TestMessageContextMenu")

    @pytest.fixture(autouse=True)
    def setup(self, established_chat):
        """Auto-setup using the module-scoped established_chat fixture."""
        self.ctx = established_chat
        self.driver = established_chat.primary.driver
        self.device = established_chat.primary

    @asynccontextmanager
    async def step(self, description: str):
        """Simple step context manager for logging."""
        self.logger.info(f"Step: {description}")
        yield
        self.logger.info(f"Completed: {description}")

    async def _ensure_in_chat(self) -> ChatPage:
        """Ensure we're in a chat with message input visible.
        
        Handles various app states and navigates to an open chat with input ready.
        """
        app = App(self.driver)
        chat_page = ChatPage(self.driver)
        
        # Check if already in a chat with message input
        if chat_page.is_element_visible(chat_page.locators.MESSAGE_INPUT, timeout=2):
            self.logger.info("Already in chat with message input visible")
            return chat_page
        
        # Navigate to messages tab
        self.logger.info("Navigating to Messages tab")
        app.click_messages_button()
        chat_page.dismiss_backup_prompt(timeout=3)

        # Allow the UI to settle after navigation (BrowserStack latency)
        await asyncio.sleep(0.5)

        # Check if message input appeared (we might already be in a chat)
        if chat_page.wait_for_message_input(timeout=5):
            self.logger.info("Message input ready after navigation")
            return chat_page
        
        # Try opening the chat with the secondary user by suffix
        if hasattr(self, 'ctx') and self.ctx.secondary_suffix:
            self.logger.info(f"Opening chat with secondary user ({self.ctx.secondary_suffix})")
            secondary_name = None
            if self.ctx.secondary.user:
                secondary_name = self.ctx.secondary.user.display_name
            
            if chat_page.open_chat_by_suffix(
                self.ctx.secondary_suffix,
                display_name=secondary_name,
            ):
                if chat_page.wait_for_message_input(timeout=self.UI_TIMEOUT):
                    self.logger.info("Opened chat with secondary user")
                    return chat_page
        
        # Fallback: try opening first available chat
        self.logger.info("Attempting to open first available chat")
        if chat_page.open_first_chat(timeout=self.UI_TIMEOUT):
            if chat_page.wait_for_message_input(timeout=self.UI_TIMEOUT):
                self.logger.info("Opened first chat successfully")
                return chat_page
        
        raise AssertionError(
            "Could not navigate to a chat with message input. "
            "App may be in unexpected state."
        )

    async def _send_test_message(self, message: str) -> ChatPage:
        """Send a test message and verify it appears."""
        chat_page = await self._ensure_in_chat()

        assert chat_page.send_message(message), f"Failed to send message: {message}"
        if not chat_page.message_exists(message, timeout=self.UI_TIMEOUT):
            # Capture diagnostics before failing
            chat_page.dump_page_source(f"msg_not_visible_{message[:20]}")
            chat_page.take_screenshot(f"msg_not_visible_{message[:20]}")
            raise AssertionError(f"Message not visible after sending: {message}")

        return chat_page

    async def _ensure_secondary_in_chat(self) -> ChatPage:
        """Ensure secondary device is in the chat with primary.
        
        The fixture establishes the chat, but secondary may have navigated away.
        This ensures secondary is viewing the same conversation as primary.
        """
        secondary_chat = ChatPage(self.ctx.secondary.driver)
        secondary_app = App(self.ctx.secondary.driver)
        
        # Check if already in chat with message visible
        if secondary_chat.is_element_visible(secondary_chat.locators.MESSAGE_INPUT, timeout=2):
            self.logger.info("Secondary already in chat")
            return secondary_chat
        
        # Navigate to messages
        self.logger.info("Navigating secondary to Messages tab")
        secondary_app.click_messages_button()
        secondary_chat.dismiss_backup_prompt(timeout=3)

        # Allow the UI to settle after navigation (BrowserStack latency)
        await asyncio.sleep(0.5)

        # Try to open chat with primary
        if hasattr(self, 'ctx') and self.ctx.primary_suffix:
            primary_name = None
            if self.ctx.primary.user:
                primary_name = self.ctx.primary.user.display_name
            
            if secondary_chat.open_chat_by_suffix(
                self.ctx.primary_suffix,
                display_name=primary_name,
            ):
                if secondary_chat.wait_for_message_input(timeout=self.UI_TIMEOUT):
                    self.logger.info("Secondary opened chat with primary")
                    return secondary_chat
        
        # Fallback: open first chat
        if secondary_chat.open_first_chat(timeout=self.UI_TIMEOUT):
            secondary_chat.wait_for_message_input(timeout=self.UI_TIMEOUT)
        
        return secondary_chat

    @pytest.mark.gate
    @pytest.mark.smoke
    async def test_context_menu_own_message_actions(self) -> None:
        """Verify context menu shows correct actions for own message.
        
        Own messages should show: Reply, Edit, Copy, Pin, Mark as unread, Delete
        """
        test_message = _unique_message("ctx_menu_test")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send test message"):
            await self._send_test_message(test_message)

        async with self.step("Long-press to open context menu"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.is_displayed(), "Context menu not visible"

        async with self.step("Verify own message actions are visible"):
            assert context_menu.is_reply_visible(), "Reply action not visible"
            assert context_menu.is_edit_visible(), "Edit action not visible (own message)"
            assert context_menu.is_copy_visible(), "Copy action not visible"
            assert context_menu.is_pin_visible(), "Pin action not visible"
            assert context_menu.is_delete_visible(), "Delete action not visible (own message)"

        async with self.step("Dismiss context menu"):
            assert context_menu.dismiss(), "Failed to dismiss context menu"

    @pytest.mark.gate
    @pytest.mark.smoke
    async def test_add_reaction_to_message(self) -> None:
        """Verify adding a quick reaction to a message."""
        test_message = _unique_message("react_test")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send test message"):
            await self._send_test_message(test_message)

        async with self.step("Add reaction via context menu"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            # Tap first quick reaction (😀)
            assert context_menu.tap_grin(), "Failed to add grin reaction"

        async with self.step("Verify menu closed after reaction"):
            assert context_menu.wait_until_hidden(timeout=5), (
                "Context menu should close after adding reaction"
            )

    @pytest.mark.gate
    @pytest.mark.smoke
    async def test_copy_message_action(self) -> None:
        """Verify copy message action works."""
        test_message = _unique_message("copy_test")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send test message"):
            await self._send_test_message(test_message)

        async with self.step("Copy message via context menu"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.tap_copy(), "Failed to tap Copy action"

        async with self.step("Verify menu closed after copy"):
            assert context_menu.wait_until_hidden(timeout=5), (
                "Context menu should close after copying"
            )
            # Note: Clipboard verification would require platform-specific APIs

    @pytest.mark.smoke
    async def test_delete_own_message(self) -> None:
        """Verify deleting own message removes it from both devices.
        
        Multi-device: Verifies deletion syncs to secondary device.
        """
        test_message = _unique_message("delete_test")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send test message"):
            chat_page = await self._send_test_message(test_message)

        async with self.step("Ensure secondary is in chat and verify message visible"):
            secondary_chat = await self._ensure_secondary_in_chat()
            assert secondary_chat.message_exists(test_message, timeout=self.UI_TIMEOUT), (
                "Secondary should see message before deletion"
            )

        async with self.step("Delete message via context menu"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.tap_delete(), "Failed to tap Delete action"

        async with self.step("Confirm deletion"):
            # Status shows a confirmation dialog for message deletion
            assert context_menu.confirm_delete(), "Failed to confirm deletion"

        async with self.step("Verify message deleted on primary"):
            assert not chat_page.message_exists(test_message, timeout=10), (
                "Primary: Message should be deleted"
            )

        async with self.step("Verify message deleted on secondary"):
            assert not secondary_chat.message_exists(test_message, timeout=self.UI_TIMEOUT), (
                "Secondary: Message should be deleted (sync)"
            )

    @pytest.mark.smoke
    @pytest.mark.gate
    async def test_reply_to_message(self) -> None:
        """Verify replying to a message activates reply mode.
        
        Desktop parity: test_messaging_1x1_chat.py verifies reply corner appears.
        """
        test_message = _unique_message("reply_test")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send test message"):
            chat_page = await self._send_test_message(test_message)

        async with self.step("Open context menu and tap Reply"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.tap_reply(), "Failed to tap Reply action"

        async with self.step("Verify reply mode is active"):
            assert context_menu.wait_until_hidden(timeout=5), (
                "Context menu should close after Reply"
            )
            # Reply mode shows a preview bar above the input
            assert chat_page.is_reply_mode_active(timeout=5), (
                "Reply mode should be active after tapping Reply"
            )

        async with self.step("Cancel reply mode"):
            # Clean up by canceling reply mode
            chat_page.cancel_reply(timeout=3)

    @pytest.mark.smoke
    async def test_pin_message(self) -> None:
        """Verify pinning a message via context menu syncs to both devices.
        
        Desktop parity: test_create_edit_join_community_pin_unpin_message.py
        verifies pinned state with color and 'Pinned by' text.
        
        Multi-device: Verifies pin is visible on both primary and secondary.
        
        Uses the setup message from fixture (already confirmed visible on both devices)
        to avoid sync timing issues.
        
        Requires QML: StatusPinMessageDetails with objectName "statusPinMessageDetails"
        and Accessible.name containing "Pinned by".
        """
        # Use the setup message that was sent during fixture - already synced to both devices
        setup_message = f"Setup message from {self.ctx.secondary_suffix}"
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Ensure primary is in chat"):
            chat_page = await self._ensure_in_chat()
            # Verify the setup message is visible (it should be, from fixture)
            assert chat_page.message_exists(setup_message, timeout=self.UI_TIMEOUT), (
                f"Primary: Setup message '{setup_message}' should be visible"
            )

        async with self.step("Pin message via context menu"):
            assert context_menu.long_press_message(setup_message), (
                "Failed to open context menu"
            )
            assert context_menu.tap_pin(), "Failed to tap Pin action"

        async with self.step("Verify context menu closed"):
            assert context_menu.wait_until_hidden(timeout=5), (
                "Context menu should close after Pin"
            )

        async with self.step("Verify message is pinned on primary device"):
            assert chat_page.message_is_pinned(setup_message, timeout=self.UI_TIMEOUT), (
                "Primary: Message should show 'Pinned by' indicator after pinning"
            )

        async with self.step("Verify message is pinned on secondary device"):
            # Ensure secondary is in the chat
            secondary_chat = await self._ensure_secondary_in_chat()
            # Setup message is already confirmed visible on secondary (from fixture)
            assert secondary_chat.message_is_pinned(setup_message, timeout=self.UI_TIMEOUT), (
                "Secondary: Message should show 'Pinned by' indicator (sync)"
            )

    @pytest.mark.gate
    @pytest.mark.smoke
    async def test_verify_reaction_on_message(self) -> None:
        """Verify that a reaction appears on the message and syncs to both devices.

        Desktop parity: test_messaging_1x1_chat.py verifies reaction emoji
        code appears on the message.

        Multi-device: Verifies reaction is visible on both primary and secondary.

        Sends a fresh message before reacting to ensure the chat view has
        finished scrolling.  The QML ``onPressAndHold`` handler silently
        ignores long-press gestures while ``chatLogView.moving`` is true
        (MessageView.qml), so a settling period after navigation is
        required.
        """
        test_message = _unique_message("reaction_sync")
        context_menu = MessageContextMenuPage(self.driver)
        emoji_code = "1f600"  # 😀 grin

        async with self.step("Send test message"):
            await self._send_test_message(test_message)

        async with self.step("Add reaction via context menu"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.tap_grin(), "Failed to add grin reaction"

        async with self.step("Verify context menu closed"):
            assert context_menu.wait_until_hidden(timeout=5), (
                "Context menu should close after adding reaction"
            )

        async with self.step("Verify reaction appears on primary device"):
            chat_page = ChatPage(self.driver)
            assert chat_page.message_has_reaction(emoji_code, timeout=self.UI_TIMEOUT), (
                f"Primary: Reaction {emoji_code} should appear on message after adding"
            )

        async with self.step("Verify reaction appears on secondary device"):
            secondary_chat = await self._ensure_secondary_in_chat()
            assert secondary_chat.message_has_reaction(emoji_code, timeout=self.UI_TIMEOUT), (
                f"Secondary: Reaction {emoji_code} should appear on message (sync)"
            )
