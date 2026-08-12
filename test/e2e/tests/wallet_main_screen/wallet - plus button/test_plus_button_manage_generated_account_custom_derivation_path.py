import random

import allure
import pytest
from allure_commons._allure import step

import driver
from constants import RandomWalletAccount
from constants.wallet import DerivationPathName
from gui.main_window import MainWindow
from helpers.wallet_helper import assert_authenticate_popup_not_appears


@pytest.mark.case(703028)
@pytest.mark.parametrize('path_name', [pytest.param(DerivationPathName.select_random_path_name().value)])
def test_plus_button_manage_generated_account_custom_derivation_path(main_screen: MainWindow, user_account, path_name):
    with step('Create generated wallet account'):
        wallet_account = RandomWalletAccount()
        wallet = main_screen.left_panel.open_wallet()
        account_popup = wallet.left_panel.open_add_account_popup()
        account_popup.set_name(wallet_account.name).set_derivation_path(
            path_name, random.randrange(2, 100)).save_changes()

        with step('Verify authentication popup does not appear when adding account'):
            assert_authenticate_popup_not_appears()
            account_popup.wait_until_hidden()


    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: wallet_account.name in [account.name for account in wallet.left_panel.accounts],
                              10000), \
            f'Account with {wallet_account.name} is not displayed even it should be'
