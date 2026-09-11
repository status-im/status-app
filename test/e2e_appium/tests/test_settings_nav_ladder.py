"""The Settings navigation ladder retries, and only taps an open menu.

Settings is reached through the profile sheet. These tests drive
``click_settings_button`` with stubs so the sequence is pinned without a
device: no tap before the sheet has arrived, a different tap on the next
attempt, and a page dump when every attempt fails.
"""

from unittest.mock import MagicMock

import pytest

import pages.app as app_module
from pages.app import App


def _app(monkeypatch, menu_outcomes, arrive_after_tap=True):
    app = App(MagicMock())
    calls = {"taps": [], "resets": 0, "dumps": [], "anchor_checks": 0}
    outcomes = list(menu_outcomes)

    def anchor_visible(locator, timeout=None):
        calls["anchor_checks"] += 1
        return arrive_after_tap and bool(calls["taps"])

    monkeypatch.setattr(app_module.time, "sleep", lambda *_: None)
    monkeypatch.setattr("utils.screen_identity.dismiss_backup_modal", lambda *a, **k: False)
    monkeypatch.setattr(app, "is_element_visible", anchor_visible)
    monkeypatch.setattr(app, "_ensure_main_nav_visible", lambda: True)
    monkeypatch.setattr(app, "try_click", lambda *a, **k: True)
    monkeypatch.setattr(app, "_wait_for_profile_menu", lambda timeout=5: outcomes.pop(0))
    monkeypatch.setattr(app, "_tap_element", lambda el, strategy: calls["taps"].append(strategy) or True)
    monkeypatch.setattr(app, "_reset_profile_menu_state", lambda: calls.__setitem__("resets", calls["resets"] + 1))
    monkeypatch.setattr(app, "dump_page_source", lambda name=None: calls["dumps"].append(name))
    return app, calls


@pytest.mark.gate
@pytest.mark.component
def test_menu_item_is_not_tapped_until_the_sheet_arrives(monkeypatch):
    app, calls = _app(monkeypatch, menu_outcomes=[None, MagicMock()])

    assert app.click_settings_button() is True
    assert calls["taps"] == ["native"], "the tap must wait for attempt 2, with the other strategy"
    assert calls["resets"] == 1
    assert calls["dumps"] == ["settings_menu_not_open_a1_w3c"]


@pytest.mark.gate
@pytest.mark.component
def test_every_attempt_failing_leaves_the_dump(monkeypatch):
    app, calls = _app(monkeypatch, menu_outcomes=[None, None, None])

    assert app.click_settings_button() is False
    assert calls["taps"] == []
    assert calls["resets"] == 2
    assert calls["dumps"][-1] == "settings_nav_failed"


@pytest.mark.gate
@pytest.mark.component
def test_tap_without_arrival_is_retried_with_another_strategy(monkeypatch):
    sheet = MagicMock()
    app, calls = _app(monkeypatch, menu_outcomes=[sheet, sheet, sheet], arrive_after_tap=False)

    assert app.click_settings_button() is False
    assert calls["taps"] == ["w3c", "native", "w3c"]
    assert calls["dumps"][-1] == "settings_nav_failed"
