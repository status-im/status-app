"""How one level of a locator is matched against the objects of the app.

A locator is a dict such as ``{"container": ..., "objectName": "x", "type": "Button", "visible": True}``.
A value may be a compiled ``re`` pattern, which matches anywhere in the value.
"""

import functools
import re

from .inspector import InspectorError

# Keys with a meaning of their own. Every other key is a property to compare.
RESERVED = frozenset({"container", "objectName", "name", "type", "id", "unnamed", "occurrence"})


def base_name(class_name):
    """``StatusButton_QMLTYPE_42`` -> ``StatusButton``."""
    return class_name.split("_QMLTYPE_")[0].split("_QML_")[0]


def type_matches(wanted, match):
    """The object's type or any of its base types, with or without Qt's ``QQuick`` prefix."""
    names = [match["type"], *match.get("inherits", [])]
    return any(base_name(n) in (wanted, "QQuick" + wanted) for n in names)


def value_matches(expected, actual):
    if isinstance(expected, re.Pattern):
        return actual is not None and expected.search(str(actual)) is not None
    return expected == actual


def _name(locator):
    return locator.get("objectName", locator.get("name"))


def _candidates(inspector, locator, root):
    def ask(command, **params):
        if root:
            params["objectId"] = root
        return inspector.send(command, **params)["matches"]

    name = _name(locator)
    if isinstance(name, str):
        return ask("findByProperty", property="objectName", value=name), "by name"
    if "type" in locator:
        found = ask("findByType", typeName=locator["type"])
        return found + ask("findByType", typeName="QQuick" + locator["type"]), "by type"
    return ask("findByProperty", property="objectName"), "with a name"


def _rules(inspector, locator):
    """(label, predicate) for each rule of the locator, cheapest first."""

    @functools.cache
    def properties(object_id):
        return inspector.properties(object_id)

    def read(match, key):
        found = properties(match["id"])
        if key in found:
            return found[key]
        # Not a property of the object: a value of its QML context, such as a delegate's `index`.
        try:
            return inspector.evaluate(key, match["id"])
        except InspectorError:
            return None

    name = _name(locator)
    if "type" in locator:
        yield f"type {locator['type']}", lambda m: type_matches(locator["type"], m)
    if "id" in locator:
        yield f"id {locator['id']}", lambda m: m.get("qmlId") == locator["id"]
    if locator.get("unnamed"):
        yield "unnamed", lambda m: not m.get("objectName")
    if isinstance(name, re.Pattern):
        yield "name pattern", lambda m: value_matches(name, m.get("objectName"))
    for key, expected in locator.items():
        if key not in RESERVED:
            yield f"{key}={expected!r}", lambda m, key=key, expected=expected: value_matches(expected, read(m, key))


def find(inspector, locator, root=None, trace=None):
    """The objects under ``root`` that one level of a locator matches; its container is not looked at.

    ``trace``, when given, receives one line: how many candidates each rule left.
    """
    found, how = _candidates(inspector, locator, root)
    matches = list({m["id"]: m for m in found}.values())
    steps = [f"{len(matches)} {how}"]
    for label, keep in _rules(inspector, locator):
        matches = [m for m in matches if keep(m)]
        steps.append(f"{len(matches)} after {label}")
    if "occurrence" in locator:
        matches = matches[locator["occurrence"] - 1:locator["occurrence"]]
    if trace is not None:
        shown = {k: getattr(v, "pattern", v) for k, v in locator.items() if k != "container"}
        trace.append(f"  {shown}: " + " -> ".join(steps))
    return matches
