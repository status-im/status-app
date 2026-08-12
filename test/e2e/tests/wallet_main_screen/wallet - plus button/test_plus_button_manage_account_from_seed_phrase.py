import allure
import pyperclip
import pytest
from allure_commons._allure import step

import driver
from constants import RandomWalletAccount
from constants.wallet import WalletSeedPhrase
from helpers.wallet_helper import authenticate_with_password
from scripts.utils.generators import random_mnemonic, random_wallet_acc_keypair_name

from gui.main_window import MainWindow
from scripts.utils.generators import get_wallet_address_from_mnemonic
from web3 import Web3


@pytest.mark.case(703030)
def test_plus_button_manage_account_from_seed_phrase(main_screen: MainWindow, user_account):

    wallet_account = RandomWalletAccount()
    new_name = random_wallet_acc_keypair_name()

    with step('Create imported seed phrase wallet account'):
        mnemonic_data = random_mnemonic()
        wallet = main_screen.left_panel.open_wallet()
        account_popup = wallet.left_panel.open_add_account_popup()
        account_popup.set_name(wallet_account.name).open_add_new_account_popup().import_new_seed_phrase(mnemonic_data.split())
        account_popup.save_changes()
        with step('Authenticate with password'):
            authenticate_with_password(user_account)
            account_popup.wait_until_hidden()


    with step('Verify that the account is correctly displayed in accounts list'):
        assert driver.waitFor(lambda: wallet_account.name in [account.name for account in wallet.left_panel.accounts],
                              10000), \
            f'Account with {wallet_account.name} is not displayed even it should be'

    with step('Verify account address from UI is correct for derived account '):
        address_in_ui = wallet.left_panel.copy_account_address_in_context_menu(wallet_account.name).split(':')[-1]
        assert Web3.is_checksum_address(address_in_ui), f'Address in wallet is not checksummed'
        address_from_mnemonic = get_wallet_address_from_mnemonic(mnemonic_data)
        assert address_in_ui == Web3.to_checksum_address(address_from_mnemonic), \
            f'Expected to recover {address_from_mnemonic} but got {address_in_ui}'

    with step('Try to re-import seed phrase and verify that correct error appears'):
        account_popup = wallet.left_panel.open_add_account_popup()
        add_new_account = account_popup.set_name(new_name).open_add_new_account_popup()
        add_new_account.enter_new_seed_phrase(mnemonic_data.split())
        assert add_new_account.get_already_added_error() == WalletSeedPhrase.WALLET_SEED_PHRASE_ALREADY_ADDED.value

    with step('Delete account'):
        with step('Delete wallet account'):
            auth_modal = wallet.left_panel.delete_account_from_context_menu(wallet_account.name).remove_account_with_confirmation()
            auth_modal.authenticate(user_account.password)

    with step('Add the same account again and check derivation path'):
        add_new_account_popup = wallet.left_panel.open_add_account_popup()
        add_same_account = add_new_account_popup.set_name(wallet_account.name).open_add_new_account_popup()
        add_same_account.import_new_seed_phrase(mnemonic_data.split())
        add_new_account_popup.save_changes()

        with step('Authenticate with password'):
            authenticate_with_password(user_account)
            add_new_account_popup.wait_until_hidden()

    with step('Verify derivation path'):
        wallet.left_panel.click()
        edit_account_popup = wallet.left_panel.open_edit_account_popup_from_context_menu(wallet_account.name)
        edit_account_popup.copy_derivation_path_button.click()
        derivation_path = pyperclip.paste()
        assert derivation_path.endswith('0')

