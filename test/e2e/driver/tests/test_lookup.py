import re

from driver import lookup
from driver.inspector import InspectorError


class FakeInspector:
    """Answers find commands from a list of objects: dicts with id, type, objectName,
    optionally inherits, qmlId, props (properties) and context (QML context values)."""

    def __init__(self, objects):
        self.objects = objects

    def send(self, command, **params):
        if command == "findByType":
            wanted = params["typeName"]
            found = [o for o in self.objects
                     if any(wanted in name for name in [o["type"], *o.get("inherits", [])])]
        elif "value" in params:
            found = [o for o in self.objects if o.get("objectName") == params["value"]]
        else:
            found = [o for o in self.objects if o.get("objectName")]
        return {"matches": found}

    def properties(self, object_id):
        return self._object(object_id).get("props", {})

    def evaluate(self, expression, object_id):
        context = self._object(object_id).get("context", {})
        if expression not in context:
            raise InspectorError("ReferenceError")
        return context[expression]

    def _object(self, object_id):
        return next(o for o in self.objects if o["id"] == object_id)


def ids(inspector, locator):
    return [match["id"] for match in lookup.find(inspector, locator)]


def test_a_type_matches_the_generated_qml_class():
    inspector = FakeInspector([{"id": "1", "type": "StatusButton_QMLTYPE_42", "objectName": "ok"}])
    assert ids(inspector, {"objectName": "ok", "type": "StatusButton"}) == ["1"]


def test_a_type_matches_a_base_type_and_the_qquick_class():
    inspector = FakeInspector([
        {"id": "1", "type": "SendButton_QMLTYPE_7", "inherits": ["StatusButton_QMLTYPE_42", "QQuickButton"]},
        {"id": "2", "type": "QQuickRectangle"},
    ])
    assert ids(inspector, {"type": "StatusButton"}) == ["1"]
    assert ids(inspector, {"type": "Button"}) == ["1"]
    assert ids(inspector, {"type": "Rectangle"}) == ["2"]


def test_a_type_does_not_match_a_longer_name():
    inspector = FakeInspector([{"id": "1", "type": "StatusButtonRow_QMLTYPE_3"}])
    assert ids(inspector, {"type": "StatusButton"}) == []


def test_a_pattern_matches_anywhere_in_the_name():
    inspector = FakeInspector([
        {"id": "1", "type": "Item", "objectName": "chatListItem_7"},
        {"id": "2", "type": "Item", "objectName": "other"},
    ])
    assert ids(inspector, {"objectName": re.compile("ListItem")}) == ["1"]
    assert ids(inspector, {"objectName": re.compile("chat.*_7")}) == ["1"]


def test_name_is_the_same_as_object_name():
    inspector = FakeInspector([{"id": "1", "type": "Item", "objectName": "mainWindow"}])
    assert ids(inspector, {"name": "mainWindow"}) == ["1"]


def test_other_keys_are_compared_with_properties():
    inspector = FakeInspector([
        {"id": "1", "type": "Item", "objectName": "row", "props": {"visible": True}},
        {"id": "2", "type": "Item", "objectName": "row", "props": {"visible": False}},
    ])
    assert ids(inspector, {"objectName": "row", "visible": True}) == ["1"]


def test_a_key_that_is_no_property_is_read_from_the_qml_context():
    inspector = FakeInspector([
        {"id": "1", "type": "Item", "objectName": "row", "context": {"index": 0}},
        {"id": "2", "type": "Item", "objectName": "row", "context": {"index": 1}},
        {"id": "3", "type": "Item", "objectName": "row"},
    ])
    assert ids(inspector, {"objectName": "row", "index": 1}) == ["2"]


def test_id_is_the_qml_id_and_unnamed_excludes_named_objects():
    inspector = FakeInspector([
        {"id": "1", "type": "Item", "qmlId": "header"},
        {"id": "2", "type": "Item", "qmlId": "footer"},
        {"id": "3", "type": "Item", "qmlId": "header", "objectName": "named"},
    ])
    assert ids(inspector, {"type": "Item", "id": "header", "unnamed": 1}) == ["1"]


def test_occurrence_counts_from_one():
    inspector = FakeInspector([{"id": str(n), "type": "Item"} for n in (1, 2, 3)])
    assert ids(inspector, {"type": "Item", "occurrence": 2}) == ["2"]
    assert ids(inspector, {"type": "Item", "occurrence": 4}) == []


def test_the_trace_names_the_rule_that_removed_the_candidates():
    inspector = FakeInspector([{"id": "1", "type": "Item", "objectName": "row", "props": {"visible": False}}])
    trace = []
    lookup.find(inspector, {"objectName": "row", "type": "Item", "visible": True}, trace=trace)
    assert "1 by name -> 1 after type Item -> 0 after visible=True" in trace[0]
