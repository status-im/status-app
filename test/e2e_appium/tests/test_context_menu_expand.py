"""Device-free contract for the context-menu expand step.

The message context menu opens collapsed, and some actions exist only in
the expanded state, so a test asserting the full action set against the
collapsed menu fails on a correct product. These tests pin the expand
step's contract: it probes and taps the expand button specifically, treats
an already-expanded menu as success, expands on demand when a tapped
action is missing, and refuses to call a dismissed or still-collapsed
menu expanded.
"""

from unittest.mock import MagicMock

import pytest

from locators.messaging.message_context_menu_locators import (
    MessageContextMenuLocators,
)
from pages.messaging.message_context_menu_page import MessageContextMenuPage

pytestmark = [pytest.mark.gate, pytest.mark.component]

EXPAND = MessageContextMenuLocators.EXPAND_BUTTON
DELETE = MessageContextMenuLocators.DELETE_MESSAGE


def _menu(monkeypatch, displayed=True, visible=(), click_ok=True,
          expands=True, dismisses=False):
    """Build a page whose probes read scripted state.

    ``visible`` lists the locators currently in the tree; a click on the
    expand button mutates that state per ``expands``/``dismisses``.
    """
    page = MessageContextMenuPage(MagicMock())
    state = {"displayed": displayed, "visible": set(visible)}
    probes, clicks = [], []

    monkeypatch.setattr(
        page, "is_displayed", lambda timeout=2: state["displayed"]
    )

    def fake_visible(locator, timeout=None):
        probes.append(locator)
        return locator in state["visible"]

    def fake_click(locator, *, timeout=None, **kwargs):
        clicks.append(locator)
        if locator == EXPAND and click_ok:
            if dismisses:
                state["displayed"] = False
            if expands:
                state["visible"].discard(EXPAND)
        return click_ok

    monkeypatch.setattr(page, "is_element_visible", fake_visible)
    monkeypatch.setattr(page, "try_click", fake_click)
    return page, probes, clicks


def test_expand_taps_the_expand_button(monkeypatch):
    page, probes, clicks = _menu(monkeypatch, visible=[EXPAND])
    assert page.tap_expand() is True
    assert clicks == [EXPAND]
    assert EXPAND in probes


def test_expand_skips_the_tap_when_already_expanded(monkeypatch):
    page, probes, clicks = _menu(monkeypatch, visible=[])
    assert page.tap_expand() is True
    assert clicks == []
    assert EXPAND in probes


def test_expand_fails_when_menu_is_closed(monkeypatch):
    page, _, clicks = _menu(monkeypatch, displayed=False)
    assert page.tap_expand() is False
    assert clicks == []


def test_expand_fails_when_the_tap_dismisses_the_menu(monkeypatch):
    """A mis-landed tap that closes the menu must not read as expanded."""
    page, _, clicks = _menu(monkeypatch, visible=[EXPAND], dismisses=True)
    assert page.tap_expand(timeout=1) is False
    assert clicks == [EXPAND]


def test_expand_fails_when_menu_stays_collapsed(monkeypatch):
    page, _, _ = _menu(monkeypatch, visible=[EXPAND], expands=False)
    assert page.tap_expand(timeout=1) is False


def test_expand_fails_when_tap_fails(monkeypatch):
    page, _, clicks = _menu(monkeypatch, visible=[EXPAND], click_ok=False)
    assert page.tap_expand(timeout=1) is False
    assert clicks == [EXPAND]


def test_tap_delete_expands_first_when_collapsed(monkeypatch):
    page, _, clicks = _menu(monkeypatch, visible=[EXPAND])
    assert page.tap_delete() is True
    assert clicks == [EXPAND, DELETE]


def test_tap_delete_skips_expand_when_action_is_visible(monkeypatch):
    page, _, clicks = _menu(monkeypatch, visible=[DELETE])
    assert page.tap_delete() is True
    assert clicks == [DELETE]


def test_is_expanded_requires_an_open_menu(monkeypatch):
    expanded, probes, _ = _menu(monkeypatch, visible=[])
    collapsed, _, _ = _menu(monkeypatch, visible=[EXPAND])
    closed, _, _ = _menu(monkeypatch, displayed=False)
    assert expanded.is_expanded() is True
    assert EXPAND in probes
    assert collapsed.is_expanded() is False
    assert closed.is_expanded() is False
