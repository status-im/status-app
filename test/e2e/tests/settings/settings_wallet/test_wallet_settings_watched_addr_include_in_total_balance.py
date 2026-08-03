import random
import string

import allure
import pytest
from allure_commons._allure import step
from web3 import Web3


import configs
import driver
from constants.wallet import WalletAccountSettings
from gui.main_window import MainWindow
from gui.screens.settings_wallet import WalletSettingsView


@pytest.mark.case(703508)
@pytest.mark.parametrize('watched_address, name', [
    pytest.param('0x7f1502605A2f2Cc01f9f4E7dd55e549954A8cD0C', ''.join(random.choices(string.ascii_letters +
                                                                                      string.digits, k=20)))
])
@pytest.mark.skip(reason="https://github.com/status-im/status-desktop/issues/14862, https://github.com/status-im/status-desktop/issues/14509")
def test_settings_include_in_total_balance(main_screen: MainWindow, name, watched_address):
    with (step('Open wallet on main screen and check the total balance for new account is 0')):
        wallet_main_screen = main_screen.left_panel.open_wallet()
        total_balance_before = float(wallet_main_screen.left_panel.get_total_balance_value().replace("\xa0", ""
                                                                                                     ).replace(",",
                                                                                                               ""))
        assert total_balance_before == 0.0, \
            f"Balance for new account should be 0.0 but current balance is {total_balance_before}"

    with step('Open wallet settings screen and add watched address using "+" button'):
        add_account_popup = \
            main_screen.left_panel.open_settings().left_panel.open_wallet_settings().open_add_account_pop_up()
        add_account_popup.set_name(name).set_origin_watched_address(watched_address).save_changes()
        add_account_popup.wait_until_hidden()

    with step('Open wallet settings and verify the keypair for the watched address is present with default title'):
        wallet_settings_view = main_screen.left_panel.open_settings().left_panel.open_wallet_settings()
        keypairs_names = wallet_settings_view.get_keypairs_names()
        assert WalletAccountSettings.WATCHED_ADDRESSES_KEYPAIR_LABEL.value in keypairs_names, \
            f"Watched addresses keypair name must be present when watched address is added \
            but currently the list is {keypairs_names}"

    with step('Open account details view for the watched address'):
        account_index = 0
        acc_view = WalletSettingsView().open_account_in_settings(name, account_index)

    with step('Verify details view for the watched address'):
        assert driver.waitFor(
            lambda: acc_view.get_account_balance_value() != '0,00', configs.timeouts.UI_LOAD_TIMEOUT_MSEC), \
            f"Watched address {watched_address} should have positive balance in account view"

        assert acc_view.get_account_name_value() == name, \
            f"Watched address name is incorrect, current name is {acc_view.get_account_name_value()}, expected {name}"

        assert acc_view.get_account_address_value() == Web3.to_checksum_address(watched_address), \
            f"Watched address in details view does not match {watched_address}"

        assert acc_view.get_account_origin_value() == WalletAccountSettings.WATCHED_ADDRESS_ORIGIN.value, \
            f"Watched address origin must be {WalletAccountSettings.WATCHED_ADDRESS_ORIGIN.value}"

        assert acc_view.is_derivation_path_visible() is False, \
            f"Watched address should not have derivation path value"

        assert acc_view.is_account_storage_visible() is False, \
            f"Watched address should not have storage value"

        assert acc_view.wallet_settings_total_balance_item.is_visible, \
            f"Include in total balance option must be present for watched addresses"

    with step('Enable the "Include in total balance" toggle in account view'):
        acc_view.toggle_total_balance(True)

    with step('Open wallet main screen and make sure total balance is not 0 anymore'):
        main_screen.left_panel.open_wallet()

        assert driver.waitFor(
            lambda: float(wallet_main_screen.left_panel.get_total_balance_value().replace("\xa0", "")
                          .replace(",", "")) > 0, 10000), \
            f"Balance after adding watched address can't be 0"

    with step('Right click the watched address and select Exclude from total balance option'):
        main_screen.left_panel.open_wallet().left_panel.hide_include_in_total_balance_from_context_menu(name)

    with step('Check the balance is back to 0 again'):
        assert driver.waitFor(
            lambda: float(wallet_main_screen.left_panel.get_total_balance_value().replace("\xa0", "")
                          .replace(",", "")) == 0, configs.timeouts.UI_LOAD_TIMEOUT_MSEC), \
            f"Balance after removing watched address should be back to 0"
