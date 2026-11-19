"""Squish's ``toplevelwindow`` module."""
import squishtest


class ToplevelWindow:
    def __init__(self, window):
        self.window = window

    @staticmethod
    def byName(real_name):
        found = squishtest._resolve_or_none(real_name)
        if not found:
            raise RuntimeError(f"no window {real_name}")
        return ToplevelWindow(found[0])

    def setFocus(self):
        self.window._eval("requestActivate()")

    def setForeground(self):
        self.window._eval("raise()")
