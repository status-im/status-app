"""One object of the app, and the values read from it."""

import dataclasses
import json
import re

from .lookup import base_name

_COLOUR = re.compile(r"#[0-9a-fA-F]{8}")


@dataclasses.dataclass
class Point:
    x: float
    y: float


@dataclasses.dataclass
class Rect:
    x: float
    y: float
    width: float
    height: float

    def center(self):
        return Point(self.x + self.width / 2, self.y + self.height / 2)


class Colour(str):
    """A colour the plugin sent as ``#AARRGGBB``; ``name`` is ``#rrggbb``, as ``QColor.name()`` gives."""

    @property
    def name(self):
        return "#" + self[3:].lower()


class Record(dict):
    """A value with fields, such as a point or a rectangle. Fields read as attributes."""

    def __init__(self, fields, inspector):
        super().__init__(fields)
        self._inspector = inspector

    def __getattr__(self, key):
        try:
            return wrap(self[key], self._inspector)
        except KeyError:
            raise AttributeError(key) from None

    def center(self):
        return Rect(self["x"], self["y"], self["width"], self["height"]).center()


def wrap(value, inspector):
    """A value read from the app. ``inspector`` is the connection it came from:
    an object reference is only valid in that app."""
    if isinstance(value, dict):
        if "objectRef" in value:
            return Obj(inspector, {"id": value["objectRef"], "type": value.get("type", "")})
        return Record(value, inspector)
    if isinstance(value, list):
        return [wrap(item, inspector) for item in value]
    if isinstance(value, str) and _COLOUR.fullmatch(value):
        return Colour(value)
    return value


class Obj:
    """One object of the app. Attribute reads, writes and method calls go to the object in the app."""

    def __init__(self, inspector, match):
        # __setattr__ writes to the app, so the proxy's own fields go straight into __dict__.
        vars(self).update(
            _inspector=inspector, _id=match["id"], _type=match.get("type", ""), _qml_id=match.get("qmlId"))

    def _send(self, command, **params):
        return self._inspector.send(command, objectId=self._id, **params)

    def _eval(self, expression):
        return wrap(self._inspector.evaluate(expression, self._id), self._inspector)

    def _properties(self):
        return self._inspector.properties(self._id)

    def __getattr__(self, name):
        if name.startswith("_"):
            raise AttributeError(name)
        if name == "id":
            # The QML id is not a property of the object.
            if self._qml_id is None:
                vars(self)["_qml_id"] = self._send("getTree", depth=0)["tree"].get("qmlId", "")
            return self._qml_id
        properties = self._properties()
        if name in properties:
            return wrap(properties[name], self._inspector)
        kind = self._inspector.evaluate(f"typeof {name}", self._id)
        if kind == "function":
            return lambda *args: self._eval(f"{name}({', '.join(map(json.dumps, args))})")
        if kind == "undefined":
            raise AttributeError(name)
        return self._eval(name)

    def __setattr__(self, name, value):
        self._send("setProperty", property=name, value=value)

    def __eq__(self, other):
        return isinstance(other, Obj) and other._id == self._id and other._inspector is self._inspector

    def __hash__(self):
        return hash((id(self._inspector), self._id))

    def __repr__(self):
        return f"<{base_name(self._type)} #{self._id}>"


def bounds(obj):
    """The object's rectangle in screen coordinates."""
    geometry = obj._send("geometry")
    return Rect(geometry["globalX"], geometry["globalY"], geometry["width"], geometry["height"])


def children(obj):
    tree = obj._send("getTree", depth=1)["tree"]
    return [Obj(obj._inspector, child) for child in tree.get("children", [])]
