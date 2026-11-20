from types import SimpleNamespace

import squishtest


class FakeInspector:
    def __init__(self, properties=()):
        self.properties = list(properties)
        self.sent = []

    def send(self, command, **params):
        self.sent.append((command, params))
        return {"properties": self.properties}


def test_wheel_degrees_are_sent_as_eighths_of_a_degree():
    inspector = FakeInspector()
    squishtest.mouseWheel(squishtest.Obj(inspector, {"id": "7"}), 1, 2, 0, -30)
    assert inspector.sent == [("wheel", {"objectId": "7", "x": 1, "y": 2, "dx": 0, "dy": -240})]


def test_an_object_valued_property_stays_in_the_application_it_came_from(monkeypatch):
    first = FakeInspector([{"name": "parent", "value": {"objectRef": "9", "type": "Item"}}])
    second = FakeInspector()
    obj = squishtest.Obj(first, {"id": "1"})
    # The suite has switched to the other application since it looked `obj` up.
    monkeypatch.setattr(squishtest, "_current", SimpleNamespace(inspector=second))

    parent = obj.parent

    assert parent == squishtest.Obj(first, {"id": "9"})
    assert parent != squishtest.Obj(second, {"id": "9"})
