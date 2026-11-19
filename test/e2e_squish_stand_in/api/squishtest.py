"""The part of Squish's ``squishtest`` module that the desktop suite (test/e2e) uses,
served by the Qt inspector plugin instead of Squish.

Function and class names are Squish's, so the suite runs unchanged.
"""

import builtins
import json
import os
import re
import shutil
import subprocess
import tempfile
import time

import lookup
from inspector_client import Inspector, InspectorError
from typing_steps import typing_steps

STATE_DIR = os.environ.get("SQUISH_STAND_IN_STATE", os.path.join(tempfile.gettempdir(), "squish-stand-in"))
# Optional file that receives, for each lookup that found nothing, which rule removed the candidates.
LOOKUP_LOG = os.environ.get("SQUISH_STAND_IN_LOOKUP_LOG")


# --- application contexts ---

class _ApplicationContext:
    def __init__(self, name, port, attach_timeout=60):
        self.name = name
        self.port = port
        deadline = time.monotonic() + attach_timeout
        while True:
            try:
                self.inspector = Inspector(port)
                break
            except OSError:
                if time.monotonic() > deadline:
                    raise RuntimeError(f"AUT {name} is not reachable on port {port}") from None
                time.sleep(0.3)
        self.attached = True

    @property
    def isRunning(self):
        if not self.attached:
            return False
        try:
            self.inspector.send("getTree", depth=0)
            return True
        except (InspectorError, OSError, ValueError):
            return False

    def isFrozen(self, _timeout):
        return False

    def detach(self):
        global _current
        self.attached = False
        try:
            self.inspector.close()
        except OSError:
            pass
        if self in _contexts:
            _contexts.remove(self)
        if _current is self:
            _current = _contexts[-1] if _contexts else None

    def __str__(self):
        return self.name


_contexts = []
_current = None


def attachToApplication(aut_id, _host=None, _port=None):
    # bin/squishserver stored the port when the suite registered the AUT.
    with open(os.path.join(STATE_DIR, aut_id)) as port_file:
        port = int(port_file.read())
    context = _ApplicationContext(aut_id, port)
    _contexts.append(context)
    setApplicationContext(context)
    return context


def applicationContextList():
    return list(_contexts)


def currentApplicationContext():
    return _current


def setApplicationContext(context):
    global _current
    _current = context


def _inspector():
    if _current is None:
        raise RuntimeError("no application context")
    return _current.inspector


class _TestSettings:
    waitForObjectTimeout = 20000

    def setWrappersForApplication(self, *_):
        pass


testSettings = _TestSettings()


def setHookSubprocesses(_):
    pass


# --- values and object proxies ---

class _Colour(str):
    """A colour the plugin sent as ``#AARRGGBB``; ``name`` is ``#rrggbb`` as in Squish."""

    @property
    def name(self):
        return "#" + self[3:].lower()


class _Record(dict):
    """A value with fields, such as a point or a rectangle."""

    def __init__(self, fields, inspector):
        super().__init__(fields)
        self._inspector = inspector

    def __getattr__(self, key):
        try:
            return _wrap(self[key], self._inspector)
        except KeyError:
            raise AttributeError(key) from None

    def center(self):
        return UiTypes.ScreenPoint(self["x"] + self["width"] / 2, self["y"] + self["height"] / 2)


def _wrap(value, inspector):
    """A value from the application as the suite expects it. ``inspector`` is the
    connection it came from: an object reference is only valid in that application."""
    if isinstance(value, dict) and "objectRef" in value:
        return Obj(inspector, {"id": value["objectRef"], "type": value.get("type", "")})
    if isinstance(value, list):
        return [_wrap(item, inspector) for item in value]
    if isinstance(value, dict):
        return _Record(value, inspector)
    if isinstance(value, str) and re.fullmatch(r"#[0-9a-fA-F]{8}", value):
        return _Colour(value)
    return value


class _Method:
    def __init__(self, obj, name):
        self._obj = obj
        self._name = name

    def __call__(self, *args):
        arguments = ", ".join(json.dumps(a) for a in args)
        return _wrap(self._obj._eval(f"{self._name}({arguments})"), self._obj._insp)


class Obj:
    """One object in the application. Attribute reads, writes and method calls go to
    the object, as on a Squish object reference."""

    def __init__(self, inspector, match):
        # __setattr__ writes to the application, so own fields are set on the base class.
        builtins.object.__setattr__(self, "_insp", inspector)
        builtins.object.__setattr__(self, "_id", match["id"])
        builtins.object.__setattr__(self, "_type", match.get("type", ""))
        builtins.object.__setattr__(self, "_qml_id", match.get("qmlId"))

    def _call(self, command, **params):
        try:
            return self._insp.send(command, objectId=self._id, **params)
        except InspectorError as error:
            raise RuntimeError(str(error)) from None

    def _eval(self, expression):
        return self._call("evaluate", expression=expression)["result"]

    def _props(self):
        return {p["name"]: p["value"] for p in self._call("getProperties")["properties"]}

    def __getattr__(self, name):
        if name.startswith("_"):
            raise AttributeError(name)
        if name == "id":
            # Squish offers the QML id as a property.
            if self._qml_id is None:
                tree = self._call("getTree", depth=0)["tree"]
                builtins.object.__setattr__(self, "_qml_id", tree.get("qmlId", ""))
            return self._qml_id
        properties = self._props()
        if name in properties:
            return _wrap(properties[name], self._insp)
        kind = self._eval(f"typeof {name}")
        if kind == "function":
            return _Method(self, name)
        if kind == "undefined":
            raise AttributeError(name)
        return _wrap(self._eval(name), self._insp)

    def __setattr__(self, name, value):
        self._call("setProperty", property=name, value=value)

    def __eq__(self, other):
        return isinstance(other, Obj) and other._id == self._id and other._insp is self._insp

    def __hash__(self):
        return hash((id(self._insp), self._id))

    def __repr__(self):
        return f"<{lookup.base_name(self._type)} #{self._id}>"


# --- lookup and waits ---

def _resolve(real_name):
    if isinstance(real_name, Obj):
        return [real_name]
    inspector = _inspector()
    root = None
    container = real_name.get("container")
    if container is not None:
        containers = _resolve(container)
        if not containers:
            return []
        root = containers[0]._id
    return [Obj(inspector, match) for match in lookup.find(inspector, real_name, root)]


def _resolve_or_none(real_name):
    try:
        return _resolve(real_name)
    except InspectorError:
        return []


_logged_lookups = set()


def _log_failed_lookup(what, real_name):
    if not LOOKUP_LOG or isinstance(real_name, Obj):
        return
    try:
        text = lookup.explain(_inspector(), real_name)
    except (InspectorError, RuntimeError) as error:
        text = f"  (no explanation: {error})"
    if (what, text) in _logged_lookups:
        return
    _logged_lookups.add((what, text))
    test = os.environ.get("PYTEST_CURRENT_TEST", "?").split(" ")[0].split("::")[-1]
    with open(LOOKUP_LOG, "a") as log:
        log.write(f"[{test}] {what}\n{text}\n")


def findAllObjects(real_name):
    found = _resolve_or_none(real_name)
    if not found:
        _log_failed_lookup("findAllObjects found nothing", real_name)
    return found


def findObject(real_name):
    found = _resolve_or_none(real_name)
    if not found:
        raise LookupError(f"Object {real_name} not found")
    return found[0]


def _wait(real_name, timeout_msec, ready):
    if timeout_msec is None:
        timeout_msec = testSettings.waitForObjectTimeout
    timeout = timeout_msec / 1000
    deadline = time.monotonic() + timeout
    while True:
        for obj in _resolve_or_none(real_name):
            try:
                if ready(obj):
                    return obj
            except RuntimeError:
                # The object went away between the lookup and the check.
                pass
        if time.monotonic() >= deadline:
            # The suite probes with very short timeouts to ask "is it there?"; those are not failures.
            if timeout >= 1:
                _log_failed_lookup(f"waitForObject timed out after {timeout:g}s", real_name)
            raise LookupError(f"Object {real_name} not found or not ready in {timeout}s")
        time.sleep(0.1)


def waitForObjectExists(real_name, timeout_msec=None):
    return _wait(real_name, timeout_msec, lambda obj: True)


def waitForObject(real_name, timeout_msec=None):
    def visible_and_enabled(obj):
        properties = obj._props()
        return properties.get("visible", True) is not False and properties.get("enabled", True) is not False

    return _wait(real_name, timeout_msec, visible_and_enabled)


def waitFor(condition, timeout_msec=None):
    if timeout_msec is None:
        timeout_msec = 20000
    deadline = time.monotonic() + timeout_msec / 1000
    while True:
        if condition():
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.1)


class _ObjectMap:
    @staticmethod
    def realName(obj):
        return obj


objectMap = _ObjectMap()


# --- input ---

class Qt:
    LeftButton, RightButton, MiddleButton = "left", "right", "middle"
    NoModifier = 0


class MouseButton:
    LeftButton, RightButton, MiddleButton = "left", "right", "middle"


class UiTypes:
    class ScreenPoint:
        def __init__(self, x, y):
            self.x = x
            self.y = y

    class ScreenRectangle:
        def __init__(self, x, y, width, height):
            self.x = x
            self.y = y
            self.width = width
            self.height = height

        def center(self):
            return UiTypes.ScreenPoint(self.x + self.width / 2, self.y + self.height / 2)


def _wait_until_still(obj, tries=40):
    """A click sent to an item that is still sliding into place lands somewhere else."""
    def place():
        geometry = obj._call("geometry")
        return [geometry[key] for key in ("sceneX", "sceneY", "width", "height")]

    last = place()
    for _ in range(tries):
        time.sleep(0.05)
        now = place()
        if now == last:
            return
        last = now


def _mouse(obj, action, x=None, y=None, button="left"):
    params = {"action": action, "button": button}
    if x is not None and y is not None:
        params.update(x=x, y=y)
    obj._call("mouse", **params)


def mouseClick(obj, *args):
    """Squish's signatures: (obj), (obj, button), (obj, x, y, button), (obj, x, y, modifier, button)."""
    obj = waitForObject(obj)
    button = next((a for a in args if a in ("left", "right", "middle")), "left")
    numbers = [a for a in args if isinstance(a, (int, float)) and not isinstance(a, bool)]
    x, y = (numbers[0], numbers[1]) if len(numbers) >= 2 else (None, None)
    _wait_until_still(obj)
    _mouse(obj, "click", x, y, button)
    time.sleep(0.05)


# mouseRelease() takes no position in Squish: it releases where the last press or move was.
_pointer = {}


def mouseMove(obj, x=None, y=None):
    obj = waitForObject(obj)
    _pointer.update(obj=obj, x=x, y=y)
    _mouse(obj, "move", x, y)


def mousePress(obj, x=None, y=None, button="left"):
    obj = waitForObject(obj)
    _pointer.update(obj=obj, x=x, y=y)
    _mouse(obj, "press", x, y, button)


def mouseRelease(button="left"):
    _mouse(_pointer["obj"], "release", _pointer.get("x"), _pointer.get("y"), button)


def mouseWheel(obj, x, y, dx, dy, _modifier=0):
    # Squish takes degrees; Qt's wheel delta is in eighths of a degree.
    obj._call("wheel", x=x, y=y, dx=dx * 8, dy=dy * 8)


def nativeMouseClick(x, y, button="left"):
    """A click by the operating system at screen coordinates. Linux only."""
    xdotool = shutil.which("xdotool")
    if xdotool is None:
        raise NotImplementedError("nativeMouseClick needs xdotool")
    for window in _resolve_or_none({"name": "mainWindow", "type": "QQuickWindowQmlImpl"}):
        window._eval("raise()")
        window._eval("requestActivate()")
    time.sleep(0.2)
    number = {"left": "1", "middle": "2", "right": "3"}[button]
    subprocess.run([xdotool, "mousemove", str(int(x)), str(int(y)), "click", number], check=True, timeout=10)
    time.sleep(0.2)


def type(obj, text):
    obj = waitForObject(obj)
    if not obj._props().get("activeFocus"):
        try:
            obj._eval("forceActiveFocus()")
        except RuntimeError:
            # Not an item that takes focus; the keys go to the window.
            pass
    for kind, value in typing_steps(text):
        obj._call("sendKeys", **{kind: value})
    time.sleep(0.05)


# --- windows ---

class WindowState:
    Maximize, Minimize, Normal = "Maximize", "Minimize", "Normal"


def setWindowState(window, state):
    calls = {"Maximize": "showMaximized()", "Minimize": "showMinimized()"}
    window._eval(calls.get(state, "showNormal()"))
    if state != "Maximize":
        return
    screen_width = int(window._eval("screen.width"))
    screen_height = int(window._eval("screen.height"))
    deadline = time.monotonic() + 2
    while time.monotonic() < deadline:
        if int(window.width) >= 0.9 * screen_width:
            return
        time.sleep(0.1)
    # No window manager on this display, so nothing acted on the request.
    for name, value in (("x", 0), ("y", 0), ("width", screen_width), ("height", screen_height)):
        setattr(window, name, value)


def sendEvent(kind, obj):
    if kind != "QCloseEvent":
        raise NotImplementedError(kind)
    obj._eval("close()")


# The suite reaches Squish's `object` module as `squishtest.object`. It imports this
# module, so it is imported last.
import object  # noqa: F401
