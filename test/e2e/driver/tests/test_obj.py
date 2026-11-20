from types import SimpleNamespace

from driver import actions, query, session
from driver.obj import Obj


class FakeInspector:
    def __init__(self, properties=None):
        self._properties = properties or {}
        self.sent = []

    def send(self, command, **params):
        self.sent.append((command, params))
        return {}

    def properties(self, object_id):
        return self._properties


def test_wheel_degrees_are_sent_as_eighths_of_a_degree():
    inspector = FakeInspector()
    actions.wheel(Obj(inspector, {"id": "7"}), 1, 2, 0, -30)
    assert inspector.sent == [("wheel", {"objectId": "7", "x": 1, "y": 2, "dx": 0, "dy": -240})]


def test_an_object_valued_property_stays_in_the_app_it_came_from(monkeypatch):
    first = FakeInspector({"parent": {"objectRef": "9", "type": "Item"}})
    second = FakeInspector()
    obj = Obj(first, {"id": "1"})
    # The test has switched to the other app since it looked `obj` up.
    monkeypatch.setattr(session, "_current", SimpleNamespace(inspector=second))

    parent = obj.parent

    assert parent == Obj(first, {"id": "9"})
    assert parent != Obj(second, {"id": "9"})


def test_a_found_object_is_its_own_match():
    obj = Obj(FakeInspector(), {"id": "3"})
    assert query.find(obj) is obj
