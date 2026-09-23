import allure
import pytest
from allure import step

import driver
from constants import RandomWalletAccount
from helpers.wallet_helper import authenticate_with_password
from scripts.utils.generators import random_wallet_acc_keypair_name

from gui.main_window import MainWindow



@pytest.mark.case(703036)
def test_plus_button_manage_account_added_for_new_seed(main_screen: MainWindow, user_account):
    wallet_account = RandomWalletAccount()
    keypair_name = random_wallet_acc_keypair_name()

    with step('Create generated seed phrase wallet account'):
        wallet = main_screen.left_panel.open_wallet()
        account_popup = wallet.left_panel.open_add_account_popup()
        account_popup.set_name(wallet_account.name).set_origin_new_seed_phrase(
            keypair_name).save_changes()
        with step('Authenticate with password'):
            authenticate_with_password(user_account)
            account_popup.wait_until_hidden()


    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: wallet_account.name in [account.name for account in wallet.left_panel.accounts],
                              10000), \
            f'Account with {wallet_account.name} is not displayed even it should be'

