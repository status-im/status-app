"""Mouse and keyboard input. The plugin gives it to Qt where input from the system arrives,
so hover, focus and shortcuts behave as for a user."""

import contextlib
import re
import time

from . import query

_ALIASES = {"Esc": "Escape", "Del": "Delete", "PageUp": "PgUp", "PageDown": "PgDown"}
_KEYS = {
    "Return", "Enter", "Escape", "Tab", "Backtab", "Backspace", "Delete", "Insert", "Space",
    "Up", "Down", "Left", "Right", "Home", "End", "PgUp", "PgDown",
    *(f"F{n}" for n in range(1, 13)),
}
_MODIFIERS = {"Ctrl", "Shift", "Alt", "Meta"}


def key_of(token):
    """The Qt key sequence that ``<token>`` names, or None when it names no key.

    Random passwords in the tests can contain text such as ``<7>``.
    """
    *modifiers, last = token.split("+") if len(token) > 1 else [token]
    if not _MODIFIERS.issuperset(modifiers):
        return None
    last = _ALIASES.get(last, last)
    if last in _KEYS:
        return "+".join([*modifiers, last])
    if modifiers and len(last) == 1:
        return "+".join([*modifiers, last.upper()])
    return None


def typing_steps(text):
    """``"ab<Return>"`` -> ``[("text", "ab"), ("key", "Return")]``."""
    steps = []
    for part in re.split(r"(<[^<>]+>)", str(text)):
        key = key_of(part[1:-1]) if part.startswith("<") and part.endswith(">") and len(part) > 2 else None
        if key:
            steps.append(("key", key))
        elif steps and steps[-1][0] == "text":
            steps[-1] = ("text", steps[-1][1] + part)
        elif part:
            steps.append(("text", part))
    return steps


def _place(obj):
    geometry = obj._send("geometry")
    return [geometry[key] for key in ("sceneX", "sceneY", "width", "height")]


def _wait_until_still(obj, tries=40):
    """A click on an item that is still sliding into place lands somewhere else."""
    last = _place(obj)
    for _ in range(tries):
        time.sleep(0.05)
        if (now := _place(obj)) == last:
            return
        last = now


_IN_PAGE_TRANSITION = """(function (item) {
    for (var p = item; p; p = p.parent)
        if (p.busy === true && p.depth !== undefined)
            return true;
    return false;
})(this)"""


def _wait_until_page_settled(obj, tries=40):
    for _ in range(tries):
        try:
            if not obj._inspector.evaluate(_IN_PAGE_TRANSITION, obj._id):
                return
        except RuntimeError:
            return
        time.sleep(0.05)


def _mouse(obj, action, x=None, y=None, button="left"):
    params = {"action": action, "button": button}
    if x is not None and y is not None:
        params.update(x=x, y=y)
    obj._send("mouse", **params)


def click(target, x=None, y=None, button="left"):
    """Clicks at (x, y) in the object's coordinates, or in its middle. ``button``: left, right or middle."""
    obj = query.wait(target)
    _wait_until_still(obj)
    _wait_until_page_settled(obj)
    _mouse(obj, "click", x, y, button)
    time.sleep(0.05)


# release() takes no position: it releases where the last press or move was.
_pointer = {}


def move(target, x=None, y=None):
    obj = query.wait(target)
    _pointer.update(obj=obj, x=x, y=y)
    _mouse(obj, "move", x, y)


def press(target, x=None, y=None, button="left"):
    obj = query.wait(target)
    _pointer.update(obj=obj, x=x, y=y)
    _mouse(obj, "press", x, y, button)


def release(button="left"):
    _mouse(_pointer["obj"], "release", _pointer["x"], _pointer["y"], button)


def wheel(obj, x, y, dx, dy):
    """Turns the wheel by ``dx`` and ``dy`` degrees; Qt's wheel delta is in eighths of a degree."""
    obj._send("wheel", x=x, y=y, dx=dx * 8, dy=dy * 8)


def type_text(target, text):
    """Types ``text``. Key names in angle brackets, such as ``<Return>`` or ``<Ctrl+A>``, are key presses."""
    obj = query.wait(target)
    if not obj._properties().get("activeFocus"):
        # An object that takes no focus leaves the keys to the window.
        with contextlib.suppress(RuntimeError):
            obj._eval("forceActiveFocus()")
    for kind, value in typing_steps(text):
        obj._send("sendKeys", **{kind: value})
    time.sleep(0.05)
