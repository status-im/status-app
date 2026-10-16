"""The share tests pair one phone with the messaging suite's headless peer."""

import asyncio
import uuid

import pytest
import pytest_asyncio

from pages.onboarding.welcome_back_page import WelcomeBackPage
from pages.share_picker_page import SharePickerPage
from support import share_intents
from support.screen_identity import dismiss_backup_modal
from tests.messaging.conftest import (  # noqa: F401
    PeerChatContext,
    _prepare_peer_chat,
    peer_chat,
    pytest_runtest_makereport,
)


def _close_share_screen(page: SharePickerPage) -> None:
    dismiss_backup_modal(page, timeout=2)
    if page.is_open(timeout=2):
        page.tap_cancel()
        page.wait_closed(timeout=15)
        page.driver.activate_app(share_intents.package_of(page.driver))


@pytest.fixture
def peer_chat_ready(request, peer_chat) -> PeerChatContext:  # noqa: F811
    """The messaging fixture, after clearing what a failed share test leaves
    up: the share screen, which has its own composer and so passes the chat
    check, and the login screen of a test that stopped after a relaunch."""
    device = peer_chat.device
    page = SharePickerPage(device.driver)
    _close_share_screen(page)
    welcome = WelcomeBackPage(device.driver)
    if welcome.is_welcome_back_screen_displayed(timeout=3):
        assert welcome.perform_login(device.user.password), "Login failed while recovering"
        page.is_open(timeout=20)
        _close_share_screen(page)
    _prepare_peer_chat(getattr(request, "instance", None), peer_chat)
    return peer_chat


@pytest_asyncio.fixture(scope="module")
async def share_groups(peer_chat) -> list[tuple[str, str]]:  # noqa: F811
    """Five group chats the peer opened with the phone in them. With the 1:1
    that is six destinations, one more than Send allows."""
    groups = []
    for index in range(5):
        name = f"share-group-{index + 1}-{uuid.uuid4().hex[:6]}"
        chat_id = await asyncio.to_thread(peer_chat.peer.create_group_with, peer_chat.phone_key, name)
        groups.append((chat_id, name))
    return groups
