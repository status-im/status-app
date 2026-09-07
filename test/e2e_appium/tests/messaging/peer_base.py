"""Shared setup for the gate's one-phone-plus-backend-peer tests."""

import time
from contextlib import asynccontextmanager

import pytest

from config.logging_config import get_logger
from pages.app import App
from pages.messaging.chat_page import ChatPage
from support.exceptions import SESSION_FATAL
from support.peer_chat_state import ensure_peer_chat_visible
from support.timeouts import CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS


class PeerChatBase:
    """Wiring for a class whose second participant is a headless backend."""

    UI_TIMEOUT = 30
    CROSS_DEVICE_TIMEOUT = CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS
    LIVENESS_SLICE_SECONDS = 10

    @pytest.fixture(autouse=True)
    def setup(self, peer_chat_ready):
        self.ctx = peer_chat_ready
        self.device = peer_chat_ready.device
        self.driver = peer_chat_ready.device.driver
        self.peer = peer_chat_ready.peer
        self.phone_key = peer_chat_ready.phone_key

    @property
    def logger(self):
        return get_logger(self.__class__.__name__)

    @asynccontextmanager
    async def step(self, description: str):
        self.logger.info("Step: %s", description)
        yield
        self.logger.info("Completed: %s", description)

    def chat_page(self) -> ChatPage:
        """The chat, guaranteed open with the composer visible."""
        return ensure_peer_chat_visible(self.device, self.peer)

    async def send_from_phone(self, text: str) -> ChatPage:
        """Send, see it on the phone, and see it reach the peer. The last part
        is what makes a test in this module a test of two participants rather
        than of one phone that happens to have a peer in its contacts."""
        chat_page = self.chat_page()
        assert chat_page.send_message(text), f"Failed to send message: {text}"
        if not chat_page.message_exists(text, timeout=self.UI_TIMEOUT):
            chat_page.dump_page_source(f"msg_not_visible_{text[:20]}")
            chat_page.take_screenshot(f"msg_not_visible_{text[:20]}")
            raise AssertionError(f"Message not visible after sending: {text}")
        await self.await_on_peer(text)
        return chat_page

    def peer_message_ids(self) -> set[str]:
        """Ids the peer already holds for this 1:1."""
        return {m.get("id") for m in self.peer.chat_messages(self.phone_key)}

    async def await_new_message_on_peer(self, known_ids: set[str]) -> dict:
        """The peer's copy of the next message from the phone, whatever its text."""
        return await self.peer.await_new_message_from(
            self.phone_key, known_ids, timeout=self.CROSS_DEVICE_TIMEOUT,
        )

    def send_from_peer(self, text: str) -> str:
        """Have the peer send into the shared 1:1; returns the message id."""
        return self.peer.send_dm(self.phone_key, text)

    async def await_on_peer(self, text: str) -> dict:
        """The peer's copy of the phone's message, once it has arrived."""
        return await self.peer.await_chat_message(
            self.phone_key, text, timeout=self.CROSS_DEVICE_TIMEOUT,
        )

    async def await_on_phone(
        self, chat_page: ChatPage, text: str, *, probe=None, describe: str | None = None,
    ) -> None:
        """Wait for something the peer did to render, giving up early if the peer died."""
        check = probe or (lambda timeout: chat_page.message_exists(text, timeout=timeout))
        what = describe or f"Message {text!r} from the peer"
        deadline = time.monotonic() + self.CROSS_DEVICE_TIMEOUT
        while True:
            self.peer.check_alive()
            try:
                _ = self.driver.orientation
            except SESSION_FATAL as exc:
                raise RuntimeError(f"Appium session gone while waiting for {what}: {exc}") from exc
            if check(self.LIVENESS_SLICE_SECONDS):
                return
            if time.monotonic() >= deadline:
                raise AssertionError(
                    f"{what} never arrived on the phone within {self.CROSS_DEVICE_TIMEOUT}s"
                )

    def open_chat_list(self) -> ChatPage:
        """Leave whatever screen is open for the Messages list."""
        chat_page = ChatPage(self.driver)
        chat_page.dismiss_backup_prompt(timeout=3)
        assert App(self.driver).click_messages_button(), "Failed to open the Messages tab"
        chat_page.dismiss_backup_prompt(timeout=2)
        return chat_page
