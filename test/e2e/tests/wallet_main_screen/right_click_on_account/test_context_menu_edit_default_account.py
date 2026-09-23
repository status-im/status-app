import allure
import pytest
from allure_commons._allure import step

import driver
from constants.wallet import WalletNetworkSettings
from scripts.utils.generators import random_wallet_acc_keypair_name
from gui.main_window import MainWindow


@pytest.mark.case(703022)
def test_context_menu_edit_default_account(main_screen: MainWindow, user_account):
    name = WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value
    new_name = random_wallet_acc_keypair_name()

    with step('Select wallet account'):
        wallet = main_screen.left_panel.open_wallet()
        wallet.left_panel.select_account(name)

    with step("Verify default status account can't be deleted"):
        context_menu = wallet.left_panel._open_context_menu_for_account(name)
        assert not context_menu.delete_from_wallet_account_context.is_visible, \
            f"Delete option should not be present for Status account"

    with step('Edit wallet account'):
        account_popup = wallet.left_panel.open_edit_account_popup_from_context_menu(name)
        account_popup.set_name(new_name).save_changes()

    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: new_name in [account.name for account in wallet.left_panel.accounts],
                              10000), \
            f'Account with {name} is not displayed even it should be'
