from unittest.mock import Mock

import pytest

from pages.app import App
from pages.settings.settings_page import SettingsPage
from tests.test_settings_accessibility import (
    EXPECTED_MENU_ITEMS,
    MAX_RECOVERY_ROUNDS,
    MAX_SWIPES_PER_SWEEP,
    _assert_accessible_settings_menu,
)


@pytest.mark.parametrize("recoverable", [True, False], ids=["recovered", "still-missing"])
def test_settings_recovers_missing_rows_with_bounded_reverse_and_forward_swipes(caplog, recoverable):
    app = Mock(spec=App)
    settings = Mock(spec=SettingsPage)
    settings.wait_for_condition.side_effect = lambda check, **_: check()

    def visible_rows():
        if not settings.swipe_toward_start_of_menu.called:
            return EXPECTED_MENU_ITEMS.keys() - {"7-MenuItem", "8-MenuItem"}
        if settings.swipe_toward_end_of_menu.call_count == MAX_SWIPES_PER_SWEEP:
            return {"7-MenuItem"}
        return {"8-MenuItem"} if recoverable else set()

    settings.visible_menu_item_ids.side_effect = visible_rows

    if recoverable:
        _assert_accessible_settings_menu(app, settings)
        assert settings.swipe_toward_start_of_menu.call_count == MAX_SWIPES_PER_SWEEP
        assert settings.swipe_toward_end_of_menu.call_count == MAX_SWIPES_PER_SWEEP + 1
    else:
        with pytest.raises(AssertionError) as error:
            _assert_accessible_settings_menu(app, settings)
        assert str(error.value).splitlines()[0] == (
            "Settings rows missing from the on-screen accessibility tree: Notifications (8-MenuItem)"
        )
        assert settings.swipe_toward_start_of_menu.call_count == MAX_SWIPES_PER_SWEEP * MAX_RECOVERY_ROUNDS
        assert settings.swipe_toward_end_of_menu.call_count == MAX_SWIPES_PER_SWEEP * (MAX_RECOVERY_ROUNDS + 1)

    assert (
        "Retrying Settings rows missing after the first sweep: "
        "Notifications (8-MenuItem), Language & Currency (7-MenuItem)"
    ) in caplog.messages
