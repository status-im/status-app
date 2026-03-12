import allure
import pytest
from allure_commons._allure import step

from constants import RandomWalletAccount
from helpers.wallet_helper import authenticate_with_password
from scripts.utils.generators import random_wallet_acc_keypair_name

import constants
import driver
from gui.main_window import MainWindow


@pytest.mark.case(703029)
@pytest.mark.parametrize('address_pair', [constants.wallet.private_key_address_pair_1])
def test_plus_button_manage_account_from_private_key(main_screen: MainWindow, user_account, address_pair):
    wallet_account = RandomWalletAccount()
    new_name = random_wallet_acc_keypair_name()

    with step('Import an account within private key'):
        wallet = main_screen.left_panel.open_wallet()
        account_popup = wallet.left_panel.open_add_account_popup()
        account_popup.set_name(wallet_account.name).set_origin_private_key(
            address_pair.private_key, address_pair.private_key[:5]).save_changes()
        with step('Authenticate with password'):
            authenticate_with_password(user_account)
            account_popup.wait_until_hidden()

    with step('Verify toast message notification when adding account'):
        messages = main_screen.wait_for_toast_notifications()
        assert f'"{wallet_account.name}" successfully added' in messages

    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: wallet_account.name in [account.name for account in wallet.left_panel.accounts],
                              10000), \
            f'Account with {wallet_account.name} is not displayed even it should be'

    with step('Verify that importing private key reveals correct wallet address'):
        account_index = 0
        settings_acc_view = (
            main_screen.left_panel.open_settings().left_panel.open_wallet_settings().open_account_in_settings(
                wallet_account.name,
                account_index))
        address = settings_acc_view.get_account_address_value()
        assert address == address_pair.wallet_address, \
            f"Recovered account should have address {address_pair.wallet_address}, but has {address}"

    with step('Edit wallet account'):
        main_screen.left_panel.open_wallet()
        account_popup = wallet.left_panel.open_edit_account_popup_from_context_menu(wallet_account.name)
        account_popup.set_name(new_name).save_changes()

    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: new_name in [account.name for account in wallet.left_panel.accounts],
                              10000), \
            f'Account with {new_name} is not displayed even it should be'

    with step('Delete wallet account'):
        auth_modal = wallet.left_panel.delete_account_from_context_menu(new_name).remove_account_with_confirmation()
        auth_modal.authenticate(user_account.password)


    with step('Verify toast message notification when removing account'):
        messages = main_screen.wait_for_toast_notifications()
        assert f'"{new_name}" successfully removed' in messages, \
            f"Toast message about account removal is not correct or not present. Current list of messages: {messages}"

    with step('Verify that the account is not displayed in accounts list'):
        assert driver.waitFor(lambda: new_name not in [account.name for account in wallet.left_panel.accounts], 10000), \
            f'Account with {new_name} is still displayed even it should not be'
