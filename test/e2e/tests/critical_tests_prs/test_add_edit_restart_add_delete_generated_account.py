import allure
import pyperclip
import pytest
from allure_commons._allure import step

from constants.dock_buttons import DockButtons
from constants.wallet import WalletNetworkSettings
from driver.aut import AUT
from helpers.wallet_helper import assert_authenticate_popup_not_appears
from scripts.utils.generators import random_wallet_acc_keypair_name

import driver
from gui.main_window import MainWindow
from helpers.settings_helper import open_wallet_settings


@pytest.mark.case(703033)
@pytest.mark.critical
def test_add_edit_restart_add_delete_generated_account(aut: AUT, main_screen: MainWindow, user_account, ):
    name1 = random_wallet_acc_keypair_name()
    name2 = random_wallet_acc_keypair_name()

    with step('Open wallet and choose default account'):
        default_name = WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value
        wallet = main_screen.left_panel.open_wallet()
        wallet_account = wallet.left_panel.select_account(default_name)
        wallet.left_panel.copy_account_address_in_context_menu(default_name)
        wallet_address = pyperclip.paste()

    with step('Check QR code and address in Receive modal from footer'):
        receive_popup = wallet_account.open_receive_popup()
        assert receive_popup.qr_code.is_visible, f'QR code is not present in Receive modal'
        assert wallet_address == receive_popup.copy_address(), f'Addresses do not match'

    with step('Create generated wallet account'):

        wallet = main_screen.left_panel.open_wallet()
        account_popup = wallet.left_panel.open_add_account_popup()
        account_popup.set_name(name1).save_changes()

        with step('Verify authentication popup does not appear when adding account'):
            assert_authenticate_popup_not_appears()
            account_popup.wait_until_hidden()


    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: name1 in [account.name for account in wallet.left_panel.accounts], 10000), \
            f'Account with {name1} is not found in {wallet.left_panel.accounts}'

    with step('Edit wallet account'):
        new_name = random_wallet_acc_keypair_name()
        account_popup = wallet.left_panel.open_edit_account_popup_from_context_menu(name1)
        account_popup.set_name(new_name).save_changes()

    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: new_name in [account.name for account in wallet.left_panel.accounts], 10000), \
            f'Account with {new_name} is not found in {wallet.left_panel.accounts}'

    with step('Restart application'):
        aut.restart()
        main_screen.prepare()
        main_screen.authorize_user(user_account)

    with step('Add second generated wallet account'):
        wallet = main_screen.left_panel.open_wallet()
        account_popup = wallet.left_panel.open_add_account_popup()
        account_popup.set_name(name2).save_changes()

        with step('Verify authentication popup does not appear when adding account'):
            assert_authenticate_popup_not_appears()
            account_popup.wait_until_hidden()


    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: name2 in [account.name for account in wallet.left_panel.accounts], 10000), \
            f'Account with {name2} is not displayed even it should be'

    with step('Delete wallet account with agreement'):
        auth_modal = wallet.left_panel.delete_account_from_context_menu(new_name).remove_account_with_confirmation()
        auth_modal.authenticate(user_account.password)


    with step('Verify that the account is not displayed in accounts list'):
        assert driver.waitFor(lambda: new_name not in [account.name for account in wallet.left_panel.accounts], 10000), \
            f'Account with {new_name} is found in {wallet.left_panel.accounts} after removal'
