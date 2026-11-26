from unittest.mock import Mock, PropertyMock

import pytest

from pages.settings.wallet_settings_page import WalletSettingsPage

pytestmark = pytest.mark.component


def _viewport(*switches: tuple[str, str]) -> str:
    nodes = "".join(
        f'<node resource-id="wallet.isActiveSwitch_{name}" checkable="true" '
        f'checked="{state}" displayed="true"/>'
        for name, state in switches
    )
    return (
        '<hierarchy><node resource-id="wallet.testnetModeSwitch" checkable="true" '
        f'checked="false"/>{nodes}</hierarchy>'
    )


def test_get_network_states_reads_switches_across_viewports(monkeypatch):
    first = _viewport(("Ethereum", "true"), ("Base", "false"))
    bottom = _viewport(("Base", "false"), ("Linea", "true"))
    driver = Mock()
    type(driver).page_source = PropertyMock(side_effect=(first, bottom, bottom))
    page = WalletSettingsPage(driver)
    swipe = Mock()
    monkeypatch.setattr(page, "_swipe_networks", swipe)
    visible = Mock(side_effect=(True, False, True))
    monkeypatch.setattr(page, "is_element_visible", visible)

    assert page.get_network_states() == {
        "Ethereum": True,
        "Base": False,
        "Linea": True,
    }
    assert [call.kwargs for call in swipe.call_args_list] == [{}, {}, {"down": True}]


@pytest.mark.parametrize(
    ("source", "message"),
    [
        (_viewport(), "No network switches visible"),
        (_viewport(("Ethereum", "")), "has no checked state"),
    ],
)
def test_get_network_states_rejects_missing_switches_or_state(monkeypatch, source, message):
    page = WalletSettingsPage(Mock(page_source=source))
    monkeypatch.setattr(page, "is_element_visible", Mock(return_value=True))
    with pytest.raises(ValueError, match=message):
        page.get_network_states()
