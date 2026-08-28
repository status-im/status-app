"""Device-free contract for dismissing stacked onboarding overlays.

Qt renders these dialogs as sibling nodes and only the top one takes
focus. A dialog underneath stays in the tree and still reports itself as
visible, so a tap aimed at it lands on the dialog above and the dismissal
quietly does nothing. The page sources below copy device dumps taken
before and after closing the top dialog.
"""

import logging

import pytest

from utils.screen_identity import dismiss_stacked_overlays, topmost_overlay

pytestmark = [pytest.mark.gate, pytest.mark.component]


POPUP = "EnablePushNotificationsPopup"
NAV_EDU = "NavigationEducationDialog"
DECLARATION = "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>"


def _dialog(object_name, focused, child_focused="false"):
    return (
        f'<android.app.AlertDialog class="android.app.AlertDialog" '
        f'resource-id="QGuiApplication.mainWindow.{object_name}" '
        f'focused="{focused}" bounds="[0,1323][1079,2399]" displayed="true">'
        f'<android.widget.Button class="android.widget.Button" '
        f'resource-id="QGuiApplication.mainWindow.{object_name}.footer.btnLater" '
        f'focused="{child_focused}" bounds="[40,2168][362,2265]" displayed="true" />'
        f"</android.app.AlertDialog>"
    )


def _source(*nodes):
    return f'{DECLARATION}<hierarchy rotation="0">{"".join(nodes)}</hierarchy>'


BOTH_NAV_EDU_ON_TOP = _source(_dialog(POPUP, "false"), _dialog(NAV_EDU, "true"))
POPUP_ON_TOP = _source(_dialog(POPUP, "true"))
POPUP_CHILD_FOCUSED = _source(_dialog(POPUP, "false", child_focused="true"))
NOTHING_FOCUSED = _source(_dialog(POPUP, "false"))
CLEAR = f'{DECLARATION}<hierarchy rotation="0" />'


class StubDriver:
    def __init__(self, sources):
        self._sources = list(sources)

    @property
    def page_source(self):
        # Hold the last state so extra reads in one round stay consistent.
        return self._sources.pop(0) if len(self._sources) > 1 else self._sources[0]


class BrokenDriver:
    @property
    def page_source(self):
        raise RuntimeError("session gone")


class StubPage:
    def __init__(self, driver):
        self.driver = driver
        self.logger = logging.getLogger("stub")


def _page(*sources):
    return StubPage(StubDriver(sources))


def test_names_the_dialog_that_holds_focus():
    assert topmost_overlay(_page(BOTH_NAV_EDU_ON_TOP), (POPUP, NAV_EDU)) == NAV_EDU


def test_names_the_popup_once_it_is_uncovered():
    assert topmost_overlay(_page(POPUP_ON_TOP), (POPUP, NAV_EDU)) == POPUP


def test_a_focused_child_identifies_its_own_dialog():
    assert topmost_overlay(_page(POPUP_CHILD_FOCUSED), (POPUP, NAV_EDU)) == POPUP


def test_names_nothing_when_no_overlay_holds_focus():
    assert topmost_overlay(_page(NOTHING_FOCUSED), (POPUP, NAV_EDU)) is None


def test_names_nothing_when_the_page_source_cannot_be_read():
    assert topmost_overlay(StubPage(BrokenDriver()), (POPUP, NAV_EDU)) is None


def test_dismisses_from_the_top_down():
    """The popup is only tappable after the dialog above it is gone, so the
    order is decided by focus and not by the order of the overlay list."""
    order = []

    def _close(name):
        def _do():
            order.append(name)
            return True

        return _do

    page = _page(BOTH_NAV_EDU_ON_TOP, POPUP_ON_TOP, CLEAR)
    overlays = [
        ("push_notifications", POPUP, _close("popup")),
        ("nav_education", NAV_EDU, _close("nav_edu")),
    ]

    actions, error = dismiss_stacked_overlays(page, overlays)

    assert order == ["nav_edu", "popup"]
    assert actions == ["nav_education:dismissed", "push_notifications:dismissed"]
    assert error is None


def test_reports_the_overlay_that_refuses_to_close():
    page = _page(POPUP_ON_TOP)
    overlays = [("push_notifications", POPUP, lambda: False)]

    actions, error = dismiss_stacked_overlays(page, overlays)

    assert actions == ["push_notifications:dismiss_failed"]
    assert "push_notifications" in error


def test_reports_an_overlay_that_keeps_coming_back():
    """A dismisser that claims success while its dialog stays on top stops
    at the round limit and reports an error."""
    page = _page(POPUP_ON_TOP)
    overlays = [("push_notifications", POPUP, lambda: True)]

    actions, error = dismiss_stacked_overlays(page, overlays, max_rounds=3)

    assert len(actions) == 3
    assert "3 rounds" in error


def test_does_nothing_when_no_overlay_is_on_top():
    page = _page(CLEAR)
    overlays = [("push_notifications", POPUP, lambda: pytest.fail("should not tap"))]

    assert dismiss_stacked_overlays(page, overlays) == ([], None)
