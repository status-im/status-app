import pytest
from allure_commons._allure import step

import driver
from constants import RandomWalletAccount
from tests.wallet_main_screen import marks

from gui.main_window import MainWindow

pytestmark = marks


@pytest.mark.case(703026, 738788, 738815)
@pytest.mark.smoke
# TODO: to add a step of account removal
@pytest.mark.parametrize('address', [
    pytest.param('0xea123F7beFF45E3C9fdF54B324c29DBdA14a639A')
])
def test_plus_button_add_watched_address(main_screen: MainWindow, address: str):

    wallet_account = RandomWalletAccount()

    with step('Add watched address with plus action button'):
        wallet = main_screen.left_panel.open_wallet()
        account_popup = wallet.left_panel.open_add_account_popup()
        account_popup\
            .set_name(wallet_account.name)\
            .set_emoji(wallet_account.emoji[0])\
            .set_color(wallet_account.color).set_origin_watched_address(address).save_changes()
        account_popup.wait_until_hidden()

    with step('Verify toast message notification when adding account'):
        messages = main_screen.wait_for_toast_notifications()
        assert f'"{wallet_account.name}" successfully added'in messages

    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: wallet_account.name in [account.name for account in wallet.left_panel.accounts], 10000), \
            f'Account with {wallet_account.name} is not displayed even it should be'
