"""A message must be on screen before it is pressed or reported visible.

Appium's ``displayed`` flag is true for a chat delegate that Qt keeps in the
ListView's cache buffer but paints outside the viewport, so a presence wait
accepts a message the user cannot see and a long-press aimed at its reported
centre lands on whatever is painted there. These guards hold ``ChatPage.message_visible`` to the rect rule and
``MessageContextMenuPage.long_press_message`` to pressing only a visible
target. Device-free: the driver is a stub that reports rects the test chooses.
"""

import json

import pytest
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.remote.command import Command
from selenium.webdriver.remote.webelement import WebElement

from pages.messaging.chat_page import ChatPage
from pages.messaging.message_context_menu_page import MessageContextMenuPage


# A portrait phone's chat: the band between the toolbar's bottom and the composer's top.
SCREEN = {"width": 1080, "height": 2400}
TOOLBAR = {"x": 0, "y": 115, "width": 1080, "height": 142}
COMPOSER = {"x": 0, "y": 1983, "width": 1080, "height": 296}
TOOLBAR_BOTTOM = TOOLBAR["y"] + TOOLBAR["height"]
COMPOSER_TOP = COMPOSER["y"]


def _rect(y, height, x=138, width=924):
    return {"x": x, "y": y, "width": width, "height": height}


INSIDE = _rect(1500, 57)
BELOW_COMPOSER = _rect(2092, 57)


class _Node(WebElement):
    """A WebElement whose rect is whatever the test set, live."""

    def __init__(self, driver, rect, resource_id):
        super().__init__(driver, f"node-{resource_id}")
        self.rect_value = dict(rect)
        self.resource_id = resource_id

    @property
    def rect(self):
        return dict(self.rect_value)

    def is_displayed(self):
        return True

    def is_enabled(self):
        return True

    def get_attribute(self, name):
        return self.resource_id if name == "resource-id" else ""


class _ChatDriver:
    """Enough of an Appium session to hold one chat screen: a toolbar, a
    composer, and one message whose rect the test controls. Records swipes and
    presses in the order they happen."""

    capabilities = {"platformName": "android", "appPackage": "app.status.mobile.pr"}

    def __init__(self, message, rect, *, toolbar=True, also=()):
        self.toolbar = _Node(self, TOOLBAR, "QGuiApplication.mainWindow.BaseProxyPanel.statusToolBar") if toolbar else None
        self.composer = _Node(self, COMPOSER, "QGuiApplication.mainWindow.BaseProxyPanel.statusChatInput")
        self.message_text = message
        delegate = "QGuiApplication.mainWindow.BaseProxyPanel.chatMessageViewDelegate.StatusTextMessage_chatText"
        self.message = _Node(self, rect, f"{delegate}.d0")
        # Repeated sends and quoted replies put the same text on several
        # delegates; the tree order is not the on-screen order.
        self.messages = [self.message] + [
            _Node(self, extra, f"{delegate}.d{i}") for i, extra in enumerate(also, start=1)
        ]
        self.events = []
        self.on_swipe = lambda driver: None

    @property
    def swipes(self):
        return [e for e in self.events if e[0] == "swipe"]

    @property
    def presses(self):
        return [e for e in self.events if e[0] in ("w3c", "gesture")]

    def pressed_ids(self):
        """The element ids the recorded presses aimed at."""
        return [node.id for node in self.messages if any(node.id in str(e) for e in self.presses)]

    def get_window_size(self):
        return dict(SCREEN)

    def _matches(self, xpath):
        if "statusToolBar" in xpath:
            return [self.toolbar] if self.toolbar else []
        if "'.statusChatInput'" in xpath or "@resource-id='statusChatInput'" in xpath:
            return [self.composer]
        if self.message_text in xpath:
            return list(self.messages)
        return []

    def find_elements(self, by, value):
        return self._matches(value)

    def find_element(self, by, value):
        found = self._matches(value)
        if not found:
            raise NoSuchElementException(value)
        return found[0]

    def swipe(self, start_x, start_y, end_x, end_y, duration=0):
        self.events.append(("swipe", start_x, start_y, end_x, end_y))
        self.on_swipe(self)

    def execute(self, command, params=None):
        if command == Command.W3C_ACTIONS:
            self.events.append(("w3c", params))
        return {"value": None}

    def execute_script(self, script, *args):
        if "longClickGesture" in script:
            self.events.append(("gesture", args))
        return None

    def is_keyboard_shown(self):
        return False

    def hide_keyboard(self):
        return None

    def update_settings(self, settings):
        return None


def _cost_lines(tmp_path):
    """The cost file, wherever the suite's reports dir puts it under tmp_path."""
    paths = sorted(tmp_path.glob("**/visibility-cost.jsonl"))
    assert paths, "message_visible wrote no cost line"
    return [json.loads(line) for line in paths[-1].read_text().splitlines()]



def test_message_visible_accepts_a_rect_inside_the_list(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    driver = _ChatDriver("hello_inside", INSIDE)

    assert ChatPage(driver).message_visible("hello_inside", timeout=2) is True

    line = _cost_lines(tmp_path)[-1]
    assert line["outcome"] == "visible"
    assert line["scrolled"] is False
    assert line["polls"] >= 1
    assert line["elapsed_s"] >= 0


@pytest.mark.parametrize("rect, where", [
    (BELOW_COMPOSER, "below the composer top"),
    (_rect(0, 0, x=0, width=0), "zero rect, wholly off the display"),
])
def test_message_visible_rejects_a_present_rect_outside_the_list(rect, where, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    driver = _ChatDriver("hello_outside", rect)

    assert ChatPage(driver).message_visible("hello_outside", timeout=1) is False, where

    line = _cost_lines(tmp_path)[-1]
    assert line["outcome"] == "timeout"


@pytest.mark.parametrize("rect, visible, why", [
    (INSIDE, True, "inside the list"),
    (_rect(TOOLBAR_BOTTOM + 1, 57), True, "first row under the toolbar"),
    (_rect(COMPOSER_TOP - 58, 57), True, "last row above the composer"),
    (BELOW_COMPOSER, False, "below the composer top"),
    (_rect(125, 122), False, "under the toolbar"),
    (_rect(0, 0, x=0, width=0), False, "zero rect"),
    (_rect(0, 64), False, "pinned to the display top"),
    (_rect(SCREEN["height"] - 30, 30), False, "pinned to the display bottom"),
    (_rect(200, 100), False, "straddles the toolbar edge, centre above it"),
    (_rect(1950, 60), True, "straddles the composer edge, centre still above it"),
    (_rect(TOOLBAR_BOTTOM, 57), True, "touches the toolbar bottom, centre inside"),
    (_rect(COMPOSER_TOP - 57, 57), True, "touches the composer top, centre inside"),
    (_rect(300, 1500), True, "taller than the band, centre inside: the press lands on it"),
    (_rect(0, SCREEN["height"]), False, "spans the display: the clipped-delegate artefact"),
    (_rect(-100, 800), False, "clipped at the display top, centre in the band"),
    (_rect(1000, 1600), False, "runs past the display bottom, centre in the band"),
])
def test_the_rect_rule(rect, visible, why):
    assert ChatPage.rect_within_list(rect, TOOLBAR_BOTTOM, COMPOSER_TOP, SCREEN["height"]) is visible, why


def test_message_visible_fails_closed_when_the_list_bounds_are_missing(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    driver = _ChatDriver("hello_nobounds", INSIDE, toolbar=False)

    assert ChatPage(driver).message_visible("hello_nobounds", timeout=1) is False

    assert _cost_lines(tmp_path)[-1]["outcome"] == "timeout"



def test_long_press_does_not_press_a_present_target_that_is_off_screen(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    driver = _ChatDriver("peer-msg_0f5f993e", BELOW_COMPOSER)
    page = MessageContextMenuPage(driver)
    monkeypatch.setattr(page, "is_displayed", lambda timeout=5: True)

    result = page.long_press_message("peer-msg_0f5f993e", timeout=2)

    assert driver.presses == [], (
        f"pressed a message whose rect {BELOW_COMPOSER} lies below the composer top "
        f"{COMPOSER_TOP} and never came on screen: {driver.presses}"
    )
    assert result is False


def test_long_press_scrolls_an_off_screen_target_into_view_before_pressing(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    driver = _ChatDriver("peer-msg_0f5f993e", BELOW_COMPOSER)

    def list_scrolls_to_the_message(d):
        d.message.rect_value = dict(INSIDE)

    driver.on_swipe = list_scrolls_to_the_message
    page = MessageContextMenuPage(driver)
    monkeypatch.setattr(page, "is_displayed", lambda timeout=5: True)

    assert page.long_press_message("peer-msg_0f5f993e", timeout=2) is True

    kinds = [e[0] for e in driver.events]
    assert "swipe" in kinds, f"the off-screen target was pressed without a scroll: {kinds}"
    assert kinds[-1] in ("w3c", "gesture") and kinds.index("swipe") < len(kinds) - 1, kinds
    assert len(driver.presses) == 1
    assert _cost_lines(tmp_path)[-1]["scrolled"] is True


def test_long_press_presses_the_delegate_that_passed_the_gate(tmp_path, monkeypatch):
    """Two delegates carry the same text: the first in the tree is off screen,
    the second is the one on screen. The press must land on the second."""
    monkeypatch.chdir(tmp_path)
    driver = _ChatDriver("dup_send_7f21", BELOW_COMPOSER, also=[INSIDE])
    page = MessageContextMenuPage(driver)
    monkeypatch.setattr(page, "is_displayed", lambda timeout=5: True)

    assert page.long_press_message("dup_send_7f21", timeout=2) is True

    on_screen = driver.messages[1]
    assert driver.pressed_ids() == [on_screen.id], (
        "pressed a delegate that did not satisfy the visibility rule"
    )


def test_long_press_presses_a_visible_target_without_scrolling(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    driver = _ChatDriver("ctx_menu_test_3103bc46", INSIDE)
    page = MessageContextMenuPage(driver)
    monkeypatch.setattr(page, "is_displayed", lambda timeout=5: True)

    assert page.long_press_message("ctx_menu_test_3103bc46", timeout=2) is True

    assert driver.swipes == []
    assert len(driver.presses) == 1
