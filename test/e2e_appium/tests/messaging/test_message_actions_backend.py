"""Message actions taken ON the phone, with a headless backend as counterparty."""

import uuid

import pytest

from pages.messaging.chat_page import ChatPage
from pages.messaging.message_context_menu_page import MessageContextMenuPage
from tests.messaging.peer_base import PeerChatBase


def _unique_message(prefix: str = "test") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:8]}"


@pytest.mark.messaging
@pytest.mark.backend_peer
@pytest.mark.portrait
@pytest.mark.device_count(1)
@pytest.mark.timeout(1200)
class TestMessageActions(PeerChatBase):
    """The phone's own message actions, with the peer holding the other copy."""

    async def test_context_menu_own_message_actions(self) -> None:
        """Own messages offer Reply, Edit, Copy, Pin and Delete."""
        test_message = _unique_message("ctx_menu_test")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send test message"):
            await self.send_from_phone(test_message)

        async with self.step("Long-press to open context menu"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.is_displayed(), "Context menu not visible"

        async with self.step("Verify collapsed quick actions"):
            assert not context_menu.is_expanded(), (
                "Menu should open collapsed on long-press"
            )
            assert context_menu.is_reply_visible(), "Reply action not visible"
            assert context_menu.is_edit_visible(), "Edit action not visible (own message)"
            assert context_menu.is_copy_visible(), "Copy action not visible"

        async with self.step("Expand the menu"):
            assert context_menu.tap_expand(), "Failed to expand context menu"

        async with self.step("Verify full own-message action set"):
            assert context_menu.is_reply_visible(), "Reply not in expanded menu"
            assert context_menu.is_edit_visible(), "Edit not in expanded menu"
            assert context_menu.is_copy_visible(), "Copy not in expanded menu"
            assert context_menu.is_mark_unread_visible(), "Mark as unread not in expanded menu"
            assert context_menu.is_pin_visible(), "Pin action not visible"
            assert context_menu.is_delete_visible(), "Delete action not visible (own message)"

        async with self.step("Dismiss context menu"):
            assert context_menu.dismiss(), "Failed to dismiss context menu"

    @pytest.mark.spec("SC-MACT-09")
    async def test_add_reaction_to_message(self) -> None:
        """A quick reaction can be added and closes the menu."""
        test_message = _unique_message("react_test")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send test message"):
            await self.send_from_phone(test_message)

        async with self.step("Add reaction via context menu"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.tap_grin(), "Failed to add grin reaction"

        async with self.step("Verify menu closed after reaction"):
            assert context_menu.wait_until_hidden(timeout=5), (
                "Context menu should close after adding reaction"
            )

    @pytest.mark.spec("SC-MACT-11")
    async def test_copy_message_action(self) -> None:
        """Copy is offered and closes the menu."""
        test_message = _unique_message("copy_test")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send test message"):
            await self.send_from_phone(test_message)

        async with self.step("Copy message via context menu"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.tap_copy(), "Failed to tap Copy action"

        async with self.step("Verify menu closed after copy"):
            assert context_menu.wait_until_hidden(timeout=5), (
                "Context menu should close after copying"
            )

    @pytest.mark.spec("SC-MACT-01")
    async def test_reply_shows_reply_corner_on_sender(self) -> None:
        """Replying marks the reply with the reply-corner indicator."""
        test_message = _unique_message("reply_test")
        reply_text = _unique_message("reply_body")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send the message that will be replied to"):
            chat_page = await self.send_from_phone(test_message)
            original = await self.await_on_peer(test_message)

        async with self.step("Open context menu and tap Reply"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.tap_reply(), "Failed to tap Reply action"

        async with self.step("Verify reply mode is active"):
            assert context_menu.wait_until_hidden(timeout=5), (
                "Context menu should close after Reply"
            )
            assert chat_page.is_reply_mode_active(timeout=5), (
                "Reply mode should be active after tapping Reply"
            )

        async with self.step("Send reply message"):
            assert chat_page.send_message(reply_text), (
                f"Failed to send reply: {reply_text}"
            )
            assert chat_page.message_exists(reply_text, timeout=self.UI_TIMEOUT), (
                "Reply message not visible after sending"
            )

        async with self.step("Verify reply indicator"):
            assert chat_page.message_is_reply(reply_text, timeout=self.UI_TIMEOUT), (
                "Reply message should show the reply corner indicator"
            )

        async with self.step("Verify the reply reached the other participant as a reply"):
            reply = await self.await_on_peer(reply_text)
            assert reply.get("responseTo") == original["id"], (
                f"the peer holds {reply_text!r} but not as a reply to {test_message!r}"
            )

    @pytest.mark.spec("SC-MACT-02")
    async def test_edit_shows_edited_indicator_on_sender(self) -> None:
        """Editing updates the text and marks the message edited."""
        original_text = _unique_message("edit_orig")
        edited_text = original_text + " v2"
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Send original message"):
            chat_page = await self.send_from_phone(original_text)
            original = await self.await_on_peer(original_text)

        async with self.step("Long-press message and tap Edit"):
            assert context_menu.long_press_message(original_text), (
                "Failed to open context menu"
            )
            assert context_menu.tap_edit(), "Failed to tap Edit action"

        async with self.step("Modify text and submit edit"):
            assert chat_page.submit_message_edit(edited_text), (
                "Failed to submit message edit"
            )

        async with self.step("Verify edited message"):
            assert chat_page.message_is_edited(edited_text, timeout=self.UI_TIMEOUT), (
                "Edit indicator should be visible for the edited message"
            )

        async with self.step("Verify the edit reached the other participant as an edit"):
            edited = await self.await_on_peer(edited_text)
            assert edited["id"] == original["id"], (
                f"the peer holds {edited_text!r} as a new message, not an edit of {original_text!r}"
            )
            assert self.peer.find_message(self.phone_key, original_text) is None, (
                "the peer still holds the pre-edit text"
            )

    @pytest.mark.spec("SC-MACT-09")
    async def test_reaction_badge_appears_on_sender(self) -> None:
        """The reaction badge renders on the reacted-to message."""
        test_message = _unique_message("reaction_sent")
        context_menu = MessageContextMenuPage(self.driver)
        emoji_code = "1f600"

        async with self.step("Send test message"):
            await self.send_from_phone(test_message)
            message = await self.await_on_peer(test_message)

        async with self.step("Add reaction via context menu"):
            assert context_menu.long_press_message(test_message), (
                "Failed to open context menu"
            )
            assert context_menu.tap_grin(), "Failed to add grin reaction"
            assert context_menu.wait_until_hidden(timeout=5), (
                "Context menu should close after adding reaction"
            )

        async with self.step("Verify reaction badge on the message"):
            chat_page = ChatPage(self.driver)
            assert chat_page.message_has_reaction_on(
                test_message, emoji_code, timeout=self.UI_TIMEOUT,
            ), f"Reaction {emoji_code} should appear on {test_message!r} after adding"

        async with self.step("Verify the reaction reached the other participant"):
            reactions = await self.peer.await_reaction(
                self.phone_key, message["id"], timeout=self.CROSS_DEVICE_TIMEOUT,
            )
            assert any(r.get("from") == self.phone_key for r in reactions), (
                f"the peer holds reactions on the message, none from the phone: {reactions!r}"
            )

    @pytest.mark.spec("SC-MTYP-04")
    async def test_send_emoji_via_picker(self) -> None:
        """An emoji chosen from the picker is posted to the chat."""
        chat_page = self.chat_page()

        async with self.step("Send emoji from the picker"):
            count_before = chat_page.message_count()
            known = self.peer_message_ids()
            assert chat_page.send_emoji_to_chat("thumbsup", timeout=self.UI_TIMEOUT), (
                "Failed to send emoji via picker"
            )

        async with self.step("Verify the emoji message appears"):
            assert chat_page.wait_for_message_count(
                count_before + 1, timeout=self.UI_TIMEOUT,
            ), "Emoji message should appear in the chat"

        async with self.step("Verify it reached the other participant"):
            # The picker chooses the text, so the peer is matched on "new from
            # the phone" rather than on a sentinel.
            await self.await_new_message_on_peer(known)
