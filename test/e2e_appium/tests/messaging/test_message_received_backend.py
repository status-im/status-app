"""Receiving-side UI, with a headless backend driving the other end."""

import uuid

import pytest

from pages.messaging.message_context_menu_page import MessageContextMenuPage
from tests.messaging.peer_base import PeerChatBase


def _unique_message(prefix: str = "test") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:8]}"


@pytest.mark.messaging
@pytest.mark.backend_peer
@pytest.mark.portrait
@pytest.mark.device_count(1)
@pytest.mark.timeout(1200)
class TestMessageActionsReceived(PeerChatBase):
    """What the phone renders for actions taken by the other participant."""

    @pytest.mark.spec("SC-MACT-01")
    async def test_received_reply_shows_reply_corner(self) -> None:
        """A reply sent by the other participant renders with its indicator."""
        original_text = _unique_message("peer-reply-orig")
        reply_text = _unique_message("peer-reply-body")

        async with self.step("Peer sends a message the phone can see"):
            chat_page = self.chat_page()
            original_id = self.send_from_peer(original_text)
            await self.await_on_phone(chat_page, original_text)

        async with self.step("Peer replies to its own message"):
            self.peer.send_reply(self.phone_key, reply_text, original_id)

        async with self.step("Phone shows the reply with the reply corner"):
            await self.await_on_phone(chat_page, reply_text)
            await self.await_on_phone(
                chat_page, reply_text,
                probe=lambda t: chat_page.message_is_reply(reply_text, timeout=t),
                describe=f"Reply corner on {reply_text!r}",
            )

    @pytest.mark.spec("SC-MACT-02")
    async def test_received_edit_updates_text_and_indicator(self) -> None:
        """An edit made by the other participant updates the rendered message."""
        original_text = _unique_message("peer-edit-orig")
        edited_text = original_text + "-v2"

        async with self.step("Peer sends a message the phone can see"):
            chat_page = self.chat_page()
            message_id = self.send_from_peer(original_text)
            await self.await_on_phone(chat_page, original_text)

        async with self.step("Peer edits that message"):
            self.peer.revise_message(message_id, edited_text)

        async with self.step("Phone shows the edited text and the edited indicator"):
            await self.await_on_phone(
                chat_page, edited_text,
                probe=lambda t: chat_page.message_is_edited(edited_text, timeout=t),
                describe=f"Edited text {edited_text!r} with its indicator",
            )

    @pytest.mark.spec("SC-MACT-09")
    async def test_received_reaction_appears_on_message(self) -> None:
        """A reaction added by the other participant renders as a badge."""
        message_text = _unique_message("peer-reaction")
        emoji_code = "1f600"

        async with self.step("Peer sends a message the phone can see"):
            chat_page = self.chat_page()
            message_id = self.send_from_peer(message_text)
            await self.await_on_phone(chat_page, message_text)

        async with self.step("Peer reacts to its own message"):
            self.peer.add_reaction(self.phone_key, message_id, emoji_code)

        async with self.step("Phone shows the reaction badge"):
            await self.await_on_phone(
                chat_page, message_text,
                probe=lambda t: chat_page.message_has_reaction_on(
                    message_text, emoji_code, timeout=t,
                ),
                describe=f"Reaction {emoji_code} on {message_text!r}",
            )

    @pytest.mark.spec("SC-MTYP-04")
    async def test_received_message_increments_chat(self) -> None:
        """A message from the other participant lands in the open chat."""
        async with self.step("Take the phone's baseline message count"):
            chat_page = self.chat_page()
            count_before = chat_page.message_count()

        async with self.step("Peer sends an emoji message"):
            self.send_from_peer("\U0001f44d")

        async with self.step("Phone's chat grows by one"):
            await self.await_on_phone(
                chat_page, "emoji",
                probe=lambda t: chat_page.wait_for_message_count(count_before + 1, timeout=t),
                describe="Emoji message from the peer",
            )

    @pytest.mark.spec("SC-MACT-05")
    async def test_cannot_delete_other_users_message(self) -> None:
        """Delete is not offered on another participant's message."""
        other_message = _unique_message("peer-msg")
        context_menu = MessageContextMenuPage(self.driver)

        async with self.step("Peer sends a message"):
            chat_page = self.chat_page()
            self.send_from_peer(other_message)
            await self.await_on_phone(chat_page, other_message)

        async with self.step("Long-press the other participant's message"):
            assert context_menu.long_press_message(other_message), (
                "Failed to open context menu on the peer's message"
            )
            assert context_menu.is_displayed(), "Context menu not visible"

        async with self.step("Expand the menu"):
            # Delete is never in the collapsed row, so without this the
            # negative below holds for any message.
            assert context_menu.tap_expand(), "Failed to expand context menu"

        async with self.step("Verify Delete is NOT offered"):
            # The positive sibling keeps the negative honest: a dismissed or
            # still-collapsed menu fails here instead of passing below.
            assert context_menu.is_pin_visible(), (
                "Expanded menu should show Pin for the peer's message"
            )
            assert not context_menu.is_delete_visible(), (
                "Delete should not be visible for another participant's message"
            )

        async with self.step("Dismiss context menu"):
            assert context_menu.dismiss(), "Failed to dismiss context menu"
