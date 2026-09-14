"""Guards for longest-first module scheduling. No device, no network."""

from pathlib import Path

import pytest

from core.collection_order import (
    MODULE_SECONDS,
    UNKNOWN_MODULE_SECONDS,
    heaviest_first,
    module_cost,
)

pytestmark = pytest.mark.gate

E2E_ROOT = Path(__file__).resolve().parents[1]


class _Item:
    def __init__(self, nodeid):
        self.nodeid = nodeid

    def __repr__(self):
        return self.nodeid


def _order(items):
    return [i.nodeid for i in heaviest_first(items)]


def test_the_longest_module_is_handed_out_first():
    light = "tests/test_settings_password_change_password.py"
    heavy = "tests/messaging/test_z_chat_management_backend.py"
    items = [_Item(f"{light}::a"), _Item(f"{heavy}::b")]
    assert _order(items)[0].startswith(heavy)


def test_order_inside_a_module_is_left_alone():
    m = "tests/messaging/test_group_chat.py"
    items = [_Item(f"{m}::test_0{n}") for n in range(1, 5)]
    assert _order(items) == [i.nodeid for i in items]


def test_an_unlisted_module_is_assumed_heavy():
    # A new module must not silently become the tail.
    known_light = min(MODULE_SECONDS.values())
    assert UNKNOWN_MODULE_SECONDS > known_light
    items = [
        _Item("tests/test_settings_password_change_password.py::a"),
        _Item("tests/test_brand_new_module.py::b"),
    ]
    assert _order(items)[0].startswith("tests/test_brand_new_module.py")


def test_every_costed_module_still_exists():
    # A renamed file leaves a dead entry, and the module silently falls back to
    # the default. Nothing else would notice.
    missing = [m for m in MODULE_SECONDS if not (E2E_ROOT / m).is_file()]
    assert not missing, f"cost table names modules that no longer exist: {missing}"


def test_cost_is_read_from_the_module_not_the_test():
    m = "tests/messaging/test_z_chat_management_backend.py"
    assert module_cost(f"{m}::TestX::test_y") == MODULE_SECONDS[m]
