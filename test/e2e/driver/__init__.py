"""Drives the app under test through the inspector plugin loaded into it."""

import importlib

from .actions import click, move, press, release, type_text, wheel
from .inspector import InspectorError
from .obj import Obj, Point, Rect, bounds, children
from .query import exists, find, find_all, wait, wait_exists, wait_until

__all__ = [
    "click", "move", "press", "release", "type_text", "wheel",
    "InspectorError",
    "Obj", "Point", "Rect", "bounds", "children",
    "exists", "find", "find_all", "wait", "wait_exists", "wait_until",
]

# Imported on first use: they need the suite's configs, which the driver's unit tests do not have.
_LAZY_SUBMODULES = {"aut", "mouse", "objects_access", "window"}


def __getattr__(name):
    if name in _LAZY_SUBMODULES:
        return importlib.import_module(f"{__name__}.{name}")
    raise AttributeError(f'module "driver" has no attribute "{name}"')
