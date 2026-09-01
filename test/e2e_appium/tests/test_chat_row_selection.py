"""Chat rows are picked by identity, never by position.

Android names a chat row only in its resource-id, with the peer's generated
three-word name, so the fixture cannot match the row by chat key or display
name. The support bot's row is on every new profile. These tests pin the
selection rules without a device.
"""

from unittest.mock import MagicMock

import pytest

from constants.support_bot import SUPPORT_BOT_DISPLAY_NAME
from pages.messaging.chat_page import ChatPage

PREFIX = (
    "QGuiApplication.mainWindow.StatusSectionLayoutPortrait_QMLTYPE_267_QML_273."
    "BaseProxyPanel."
)


class _Row:
    def __init__(self, name: str, ordinal: int, content_desc: str = ""):
        self.resource_id = f"{PREFIX}{name}.StatusDraggableListItem_QMLTYPE_336_QML_{ordinal}"
        self._attrs = {
            "resource-id": self.resource_id,
            "content-desc": content_desc,
            "text": "",
        }

    def get_attribute(self, name: str):
        return self._attrs.get(name)


def _page(*rows: _Row) -> ChatPage:
    driver = MagicMock()
    driver.find_elements.return_value = list(rows)
    return ChatPage(driver)


BOT = _Row(SUPPORT_BOT_DISPLAY_NAME, 696)
PEER = _Row("Burlywood Valuable Tayra", 697)
OTHER = _Row("Feisty Oldfashioned Caterpillar", 698)


@pytest.mark.gate
@pytest.mark.component
def test_peer_is_the_one_row_that_is_not_the_bot():
    locator = _page(BOT, PEER)._find_chat_row("Lgrvz5", display_name="aVIVawpkfxhW")
    assert locator == ("xpath", f'//*[@resource-id="{PEER.resource_id}"]')


@pytest.mark.gate
@pytest.mark.component
def test_bot_alone_is_no_peer():
    assert _page(BOT)._find_chat_row("Lgrvz5", display_name="aVIVawpkfxhW") is None


@pytest.mark.gate
@pytest.mark.component
def test_two_unnamed_peers_is_no_answer():
    assert _page(BOT, PEER, OTHER)._find_chat_row("Lgrvz5") is None


@pytest.mark.gate
@pytest.mark.component
def test_a_row_named_after_the_peer_wins_over_exclusion():
    named = _Row("aVIVawpkfxhW", 699)
    locator = _page(BOT, PEER, named)._find_chat_row("Lgrvz5", display_name="aVIVawpkfxhW")
    assert locator == ("xpath", f'//*[@resource-id="{named.resource_id}"]')


@pytest.mark.gate
@pytest.mark.component
def test_peer_row_count_ignores_the_bot():
    page = _page(BOT, PEER, OTHER)
    assert page.wait_for_peer_rows(2, timeout=1) is True
    assert page.wait_for_peer_rows(3, timeout=1) is False
