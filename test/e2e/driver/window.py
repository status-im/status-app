"""Top-level windows of the app, found by locator."""

from . import query
from .poll import poll


def maximize(locator):
    window = query.wait_exists(locator)
    window.showMaximized()
    width, height = int(window._eval("screen.width")), int(window._eval("screen.height"))
    if not poll(lambda: int(window.width) >= 0.9 * width, 2000):
        # Nothing acted on the request: the display has no window manager.
        window.x, window.y, window.width, window.height = 0, 0, width, height


def minimize(locator):
    query.wait_exists(locator).showMinimized()


def set_focus(locator):
    query.wait_exists(locator).requestActivate()


def raise_to_top(locator):
    query.wait_exists(locator)._eval("raise()")


def close(locator):
    query.wait_exists(locator).close()
