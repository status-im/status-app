"""The apps the tests are connected to, and the current one, which commands go to."""

import contextlib

from .inspector import Inspector, InspectorError
from .poll import poll

_sessions = []
_current = None


class Session:
    def __init__(self, name, inspector):
        self.name = name
        self.inspector = inspector
        self.connected = True

    @property
    def is_running(self):
        if not self.connected:
            return False
        try:
            self.inspector.send("getTree", depth=0)
            return True
        except (InspectorError, OSError, ValueError):
            return False

    def close(self):
        """Disconnects from the app. The app keeps running."""
        global _current
        self.connected = False
        with contextlib.suppress(OSError):
            self.inspector.close()
        if self in _sessions:
            _sessions.remove(self)
        if _current is self:
            _current = _sessions[-1] if _sessions else None

    def __str__(self):
        return self.name


def connect(name, port, timeout_sec):
    """Connects to the plugin of a starting app, and makes it the current app."""
    def attempt():
        try:
            return Inspector(port)
        except OSError:
            return None

    inspector = poll(attempt, timeout_sec * 1000, interval=0.3)
    if inspector is None:
        raise RuntimeError(f"App {name} is not reachable on port {port}")
    session = Session(name, inspector)
    _sessions.append(session)
    activate(session)
    return session


def activate(session):
    global _current
    _current = session


def current():
    return _current


def sessions():
    return list(_sessions)


def inspector():
    if _current is None:
        raise RuntimeError("not connected to an app")
    return _current.inspector
