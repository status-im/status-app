import random
import string

import allure
import pytest
from allure_commons._allure import step

import driver
from constants import RandomWalletAccount
from helpers.wallet_helper import assert_authenticate_popup_not_appears
from constants.wallet import WalletAccountPopup

from gui.main_window import MainWindow


@pytest.mark.case(703598)
@pytest.mark.parametrize('account_name, color, emoji, emoji_unicode',
                         [
                             pytest.param(''.join(random.choices(string.ascii_letters +
                                                                 string.digits, k=15)), '#2a4af5', 'sunglasses',
                                          '1f60e')
                         ])
def test_add_new_account_from_wallet_settings(
        main_screen: MainWindow, user_account, account_name: str, color: str, emoji: str, emoji_unicode: str):

    wallet_account = RandomWalletAccount()

    with step('Open add account pop up from wallet settings'):
        add_account_popup = \
            main_screen.left_panel.open_settings().left_panel.open_wallet_settings().open_add_account_pop_up()

    with step('Add a new generated account from wallet settings screen'):

        with step('Verify that error appears when name consists of less then 5 characters'):
            add_account_popup.set_name(''.join(random.choices(string.ascii_letters +
                                                              string.digits, k=4)))
            assert add_account_popup.get_error_message() == WalletAccountPopup.WALLET_ACCOUNT_NAME_MIN.value

        add_account_popup.set_name(wallet_account.name).save_changes()
        with step('Verify authentication popup does not appear when adding account'):
            assert_authenticate_popup_not_appears()
            add_account_popup.wait_until_hidden()


    with step('Verify that the account is correctly displayed in accounts list'):
        wallet = main_screen.left_panel.open_wallet()
        assert driver.waitFor(lambda: wallet_account.name in [account.name for account in wallet.left_panel.accounts], 10000), \
            f'Account with {wallet_account.name} is not found in {wallet.left_panel.accounts}'
