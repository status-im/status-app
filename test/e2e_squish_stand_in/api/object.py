"""Squish's ``object`` module."""
import squishtest


def exists(real_name):
    return bool(squishtest._resolve_or_none(real_name))


def globalBounds(obj):
    geometry = obj._call("geometry")
    return squishtest.UiTypes.ScreenRectangle(
        geometry["globalX"], geometry["globalY"], geometry["width"], geometry["height"])


def children(obj):
    tree = obj._call("getTree", depth=1)["tree"]
    return [squishtest.Obj(obj._insp, child) for child in tree.get("children", [])]


def parent(obj):
    raise NotImplementedError("object.parent")
