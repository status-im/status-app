import squish
import toplevelwindow

import configs
from configs.system import get_platform


def _toplevel(object_name):
    return toplevelwindow.ToplevelWindow.byName(object_name)


def maximize(object_name):
    def _maximize() -> bool:
        try:
            window = _toplevel(object_name).window
            squish.setWindowState(window, squish.WindowState.Maximize)
            return True
        except RuntimeError:
            return False

    return squish.waitFor(lambda: _maximize(), configs.timeouts.UI_LOAD_TIMEOUT_MSEC)


def minimize(object_name):
    def _minimize() -> bool:
        try:
            window = _toplevel(object_name).window
            squish.setWindowState(window, squish.WindowState.Minimize)
            return True
        except RuntimeError:
            return False

    return squish.waitFor(lambda: _minimize(), configs.timeouts.UI_LOAD_TIMEOUT_MSEC)


def set_focus(object_name):
    def _set_focus() -> bool:
        try:
            top = _toplevel(object_name)
        except RuntimeError:
            return False
        try:
            top.setFocus()
            return True
        except RuntimeError:
            if get_platform() != 'Darwin':
                return False
        try:
            top.setForeground()
            return True
        except RuntimeError:
            return False

    return squish.waitFor(lambda: _set_focus(), configs.timeouts.UI_LOAD_TIMEOUT_MSEC)


def on_top_level(object_name):
    def _on_top() -> bool:
        try:
            _toplevel(object_name).setForeground()
            return True
        except RuntimeError:
            return False

    return squish.waitFor(lambda: _on_top(), configs.timeouts.UI_LOAD_TIMEOUT_MSEC)


def close(object_name):
    squish.sendEvent("QCloseEvent", squish.waitForObjectExists(object_name))
