"""How one entry of the suite's object map is matched against the application.

An entry is a dict such as ``{"container": ..., "objectName": "x", "type": "Button",
"visible": True}``. The rules below are what Squish does with it, as far as the
suite depends on them.
"""

from inspector_client import InspectorError

# Keys with a meaning of their own. Every other key is a property to compare.
RESERVED = ("container", "objectName", "name", "type", "id", "unnamed", "occurrence")


def base_name(class_name):
    """``StatusButton_QMLTYPE_42`` -> ``StatusButton``."""
    return class_name.split("_QMLTYPE_")[0].split("_QML_")[0]


def type_matches(wanted, match):
    """The object's type or any of its base types, with or without Qt's ``QQuick`` prefix."""
    names = [match["type"], *match.get("inherits", [])]
    return any(base_name(n) in (wanted, "QQuick" + wanted) for n in names)


def value_matches(expected, actual):
    pattern = getattr(expected, "pattern", None)
    if pattern is not None:
        # Squish matches a pattern anywhere in the value.
        return actual is not None and pattern.search(str(actual)) is not None
    return expected == actual


def _candidates(inspector, entry, root):
    def ask(command, **params):
        if root:
            params["objectId"] = root
        return inspector.send(command, **params)["matches"]

    name = entry.get("objectName", entry.get("name"))
    if isinstance(name, str):
        return ask("findByProperty", property="objectName", value=name), "by name"
    if "type" in entry:
        found = ask("findByType", typeName=entry["type"])
        return found + ask("findByType", typeName="QQuick" + entry["type"]), "by type"
    return ask("findByProperty", property="objectName"), "with a name"


def _filters(inspector, entry):
    """(label, predicate) for each rule of the entry, cheapest first."""
    properties = {}

    def read(match, key):
        object_id = match["id"]
        if object_id not in properties:
            properties[object_id] = inspector.properties(object_id)
        if key in properties[object_id]:
            return properties[object_id][key]
        # Not a property of the object: a value of its QML context, such as a delegate's `index`.
        try:
            return inspector.evaluate(key, object_id)
        except InspectorError:
            return None

    name = entry.get("objectName", entry.get("name"))
    filters = []
    if "type" in entry:
        filters.append((f"type {entry['type']}", lambda m: type_matches(entry["type"], m)))
    if "id" in entry:
        filters.append((f"id {entry['id']}", lambda m: m.get("qmlId") == entry["id"]))
    if entry.get("unnamed"):
        filters.append(("unnamed", lambda m: not m.get("objectName")))
    if name is not None and not isinstance(name, str):
        filters.append(("name pattern", lambda m: value_matches(name, m.get("objectName"))))
    for key, expected in entry.items():
        if key not in RESERVED:
            filters.append((
                f"{key}={expected!r}",
                lambda m, key=key, expected=expected: value_matches(expected, read(m, key)),
            ))
    return filters


def find(inspector, entry, root=None, trace=None):
    """The objects under ``root`` that one entry matches, without its container.

    ``trace``, when given, receives how many candidates each rule left.
    """
    found, how = _candidates(inspector, entry, root)
    matches = list({m["id"]: m for m in found}.values())
    if trace is not None:
        trace.append(f"{len(matches)} {how}")
    for label, keep in _filters(inspector, entry):
        matches = [m for m in matches if keep(m)]
        if trace is not None:
            trace.append(f"{len(matches)} after {label}")
    if "occurrence" in entry:
        matches = matches[entry["occurrence"] - 1:entry["occurrence"]]
    return matches


def explain(inspector, entry):
    """For a lookup that found nothing: which rule removed the candidates, per container level."""
    chain = []
    while isinstance(entry, dict):
        chain.append(entry)
        entry = entry.get("container")
    lines, root = [], None
    for level in reversed(chain):
        trace = []
        matches = find(inspector, level, root, trace)
        shown = {k: getattr(v, "pattern", v) for k, v in level.items() if k != "container"}
        lines.append(f"  {shown}: " + " -> ".join(trace))
        if not matches:
            break
        root = matches[0]["id"]
    return "\n".join(lines)
