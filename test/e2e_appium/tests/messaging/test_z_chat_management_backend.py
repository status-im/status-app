"""Clear-history and close-chat, with a headless backend as counterparty."""

import asyncio
import uuid

import pytest

from support.peer_chat_state import peer_chat_row_visible, wait_for_peer_chat_row_gone
from tests.messaging.peer_base import PeerChatBase


def _unique_message(prefix: str = "test") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:8]}"

# Long enough for a propagated deletion to have shown up if one were coming.
# These two cases assert an absence, so the wait is the assertion's strength.
NON_PROPAGATION_SETTLE_SECONDS = 20


@pytest.mark.messaging
@pytest.mark.backend_peer
@pytest.mark.portrait
@pytest.mark.device_count(1)
@pytest.mark.timeout(1200)
class TestChatManagementBackend(PeerChatBase):
    """Chat-level management actions."""

    @pytest.mark.spec("SC-DM-07")
    async def test_peer_clear_history_leaves_phone_messages(self) -> None:
        """The other participant clearing their history does not clear ours."""
        marker = _unique_message("peer_clear")

        async with self.step("Peer sends a marker the phone can see"):
            chat_page = self.chat_page()
            self.send_from_peer(marker)
            await self.await_on_phone(chat_page, marker)

        async with self.step("Peer clears its own history"):
            self.peer.purge_chat_history(self.phone_key)
            # Without this the case asserts the absence of an effect that may
            # never have been triggered, and passes however broken the RPC is.
            assert marker not in self.peer.chat_message_texts(self.phone_key), (
                "The peer still has the marker, so its history was not cleared "
                "and this case cannot say anything about propagation"
            )
            await asyncio.sleep(NON_PROPAGATION_SETTLE_SECONDS)

        async with self.step("Phone still shows the marker"):
            assert chat_page.message_exists(marker, timeout=self.UI_TIMEOUT), (
                "Phone lost the marker after the peer cleared its history; "
                "clear history must be local to the device that ran it"
            )

    @pytest.mark.spec("SC-DM-06")
    async def test_peer_close_chat_leaves_phone_chat_row(self) -> None:
        """The other participant closing the chat does not close ours."""
        marker = _unique_message("peer_close")

        async with self.step("Confirm the chat is open and the two are talking"):
            chat_page = self.chat_page()
            assert self.peer.dm_is_active(self.phone_key), (
                "The peer does not have the chat open to begin with"
            )
            # The control for the absence asserted below: without it, a pair
            # that propagates nothing at all would pass this case.
            self.send_from_peer(marker)
            await self.await_on_phone(chat_page, marker)

        async with self.step("Peer closes the chat on its side"):
            self.peer.deactivate_dm(self.phone_key)
            assert not self.peer.dm_is_active(self.phone_key), (
                "The peer still lists the chat as active, so it was not closed "
                "and this case cannot say anything about propagation"
            )
            await asyncio.sleep(NON_PROPAGATION_SETTLE_SECONDS)

        async with self.step("Phone still lists the chat"):
            self.chat_page()
            self.open_chat_list()
            await asyncio.sleep(0.5)
            assert peer_chat_row_visible(self.device, self.peer, timeout=self.UI_TIMEOUT), (
                "Phone lost the chat row after the peer closed the chat; "
                "closing must be local to the device that ran it"
            )

    @pytest.mark.spec("SC-DM-07")
    async def test_clear_history_empties_chat_but_keeps_it_listed(self) -> None:
        """Clearing on the phone empties the chat and keeps it in the list."""
        marker = _unique_message("clear_hist")

        async with self.step("Send a marker message"):
            chat_page = await self.send_from_phone(marker)

        async with self.step("Clear history"):
            assert chat_page.clear_history(timeout=self.UI_TIMEOUT), (
                "Failed to clear chat history"
            )

        async with self.step("No messages remain"):
            await asyncio.sleep(1)
            if not chat_page.is_element_visible(
                chat_page.locators.MESSAGE_INPUT, timeout=3,
            ):
                chat_page = self.chat_page()
            assert not chat_page.message_exists(marker, timeout=5), (
                "Marker should be gone after clearing history"
            )
            assert chat_page.message_count() == 0, (
                "No messages should remain after clearing history"
            )
            # A propagated clear would arrive after the click returns, so the
            # absence below only means anything once the window has passed.
            await asyncio.sleep(NON_PROPAGATION_SETTLE_SECONDS)
            assert marker in self.peer.chat_message_texts(self.phone_key), (
                "clearing on the phone must not clear the other participant's copy"
            )

        async with self.step("Chat is still in the chat list"):
            self.open_chat_list()
            await asyncio.sleep(0.5)
            assert peer_chat_row_visible(self.device, self.peer, timeout=self.UI_TIMEOUT), (
                "Chat should still be listed after clearing its history"
            )

    @pytest.mark.spec("SC-DM-06")
    async def test_close_chat_removes_it_from_the_chat_list(self) -> None:
        """Closing on the phone removes the row."""
        marker = _unique_message("close_chat")

        async with self.step("Confirm the chat is open, listed, and live"):
            chat_page = self.chat_page()
            # wait_for_peer_chat_row_gone accepts an absent row, so without this
            # the case would pass on a run where the row was never there.
            self.open_chat_list()
            assert peer_chat_row_visible(self.device, self.peer, timeout=self.UI_TIMEOUT), (
                "The chat row is not listed to begin with, so its later absence "
                "would say nothing about closing"
            )
            chat_page = self.chat_page()
            self.send_from_peer(marker)
            await self.await_on_phone(chat_page, marker)

        async with self.step("Close the chat"):
            assert chat_page.close_chat(timeout=self.UI_TIMEOUT), "Failed to close chat"

        async with self.step("Chat is no longer listed"):
            self.open_chat_list()
            assert wait_for_peer_chat_row_gone(self.device, self.peer, timeout=10), (
                "Chat should not be listed after closing it"
            )

        async with self.step("The other participant still has the chat open"):
            await asyncio.sleep(NON_PROPAGATION_SETTLE_SECONDS)
            assert self.peer.dm_is_active(self.phone_key), (
                "closing on the phone must not close the other participant's chat"
            )
