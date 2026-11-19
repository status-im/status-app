"""Splits the text given to Squish's ``type()`` into text and key presses."""

import re

_KEYS = {
    "Return": "Return", "Enter": "Enter", "Escape": "Escape", "Esc": "Escape",
    "Tab": "Tab", "Backtab": "Backtab", "Backspace": "Backspace",
    "Delete": "Delete", "Del": "Delete", "Insert": "Insert", "Space": "Space",
    "Up": "Up", "Down": "Down", "Left": "Left", "Right": "Right",
    "Home": "Home", "End": "End",
    "PageUp": "PgUp", "PageDown": "PgDown", "PgUp": "PgUp", "PgDown": "PgDown",
    **{f"F{n}": f"F{n}" for n in range(1, 13)},
}
_MODIFIERS = ("Ctrl", "Shift", "Alt", "Meta")


def key_of(token):
    """The Qt key sequence that ``<token>`` names, or None when it names no key.

    The suite types random passwords, and those can contain text such as ``<7>``.
    """
    *modifiers, last = token.split("+") if len(token) > 1 else [token]
    if any(m not in _MODIFIERS for m in modifiers):
        return None
    if last in _KEYS:
        return "+".join([*modifiers, _KEYS[last]])
    if modifiers and len(last) == 1:
        return "+".join([*modifiers, last.upper()])
    return None


def typing_steps(text):
    """``"ab<Return>"`` -> ``[("text", "ab"), ("key", "Return")]``."""
    steps = []
    for part in re.split(r"(<[^<>]+>)", str(text)):
        if not part:
            continue
        is_token = len(part) > 2 and part.startswith("<") and part.endswith(">")
        key = key_of(part[1:-1]) if is_token else None
        if key:
            steps.append(("key", key))
        elif steps and steps[-1][0] == "text":
            steps[-1] = ("text", steps[-1][1] + part)
        else:
            steps.append(("text", part))
    return steps
