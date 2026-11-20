"""The newest message is read by position, never by tree order or viewport.

The chat log runs bottom to top, so the newest message is the body with the
lowest bottom edge. A body the list caches under the composer is newer than
the ones on screen, not older. These tests pin the rule without a device.
"""

from unittest.mock import MagicMock

import pytest

from pages.messaging.chat_page import ChatPage

THUMBS_UP = "\U0001f44d"
THUMBS_DOWN = "\U0001f44e"

# A portrait phone's chat: composer top at y=1983 on a 2400 px display.
OLDER = {"x": 138, "y": 1713, "width": 924, "height": 54}
ON_SCREEN = {"x": 138, "y": 1885, "width": 924, "height": 77}
UNDER_COMPOSER = {"x": 138, "y": 2092, "width": 924, "height": 57}
OFF_DISPLAY = {"x": 0, "y": 0, "width": 0, "height": 0}


class _Body:
    def __init__(self, text: str, rect: dict):
        self.rect = dict(rect)
        self._text = text

    def get_attribute(self, name: str):
        return self._text if name == "content-desc" else None


def _page(*bodies: _Body) -> ChatPage:
    driver = MagicMock()
    driver.find_elements.return_value = list(bodies)
    return ChatPage(driver)


@pytest.mark.gate
@pytest.mark.component
def test_lowest_body_wins_whatever_the_tree_order():
    assert _page(_Body(THUMBS_UP, ON_SCREEN), _Body(THUMBS_DOWN, OLDER)).newest_message_body() == THUMBS_UP
    assert _page(_Body(THUMBS_DOWN, OLDER), _Body(THUMBS_UP, ON_SCREEN)).newest_message_body() == THUMBS_UP


@pytest.mark.gate
@pytest.mark.component
def test_body_under_the_composer_is_the_newest():
    page = _page(_Body(THUMBS_UP, ON_SCREEN), _Body(THUMBS_DOWN, UNDER_COMPOSER))
    assert page.newest_message_body() == THUMBS_DOWN


@pytest.mark.gate
@pytest.mark.component
def test_zero_rects_are_skipped():
    assert _page(_Body(THUMBS_UP, OFF_DISPLAY)).newest_message_body() is None
    page = _page(_Body(THUMBS_DOWN, OFF_DISPLAY), _Body(THUMBS_UP, OLDER))
    assert page.newest_message_body() == THUMBS_UP


@pytest.mark.gate
@pytest.mark.component
def test_empty_chat_has_no_newest_message():
    assert _page().newest_message_body() is None


@pytest.mark.gate
@pytest.mark.component
def test_picker_text_reads_as_the_bare_emoji():
    assert _page(_Body("\U0001f44d️ ", ON_SCREEN)).newest_message_body() == THUMBS_UP
    assert ChatPage.normalise_body(None) == ""
