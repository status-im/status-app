import random
import string

import allure
import pytest
from allure_commons._allure import step

from constants.wallet import WalletRenameKeypair, WalletAccountPopup
from helpers.settings_helper import skip_pcsc_error_popup_if_visible
from helpers.wallet_helper import authenticate_with_password
from scripts.utils.generators import random_wallet_acc_keypair_name

import constants
from gui.main_window import MainWindow


@pytest.mark.case(703420)
@pytest.mark.parametrize(
    'emoji',
    [pytest.param('sunglasses')])
@pytest.mark.parametrize('address_pair', [constants.wallet.private_key_address_pair_1])
def test_rename_keypair_test(main_screen: MainWindow, user_account, emoji: str, address_pair):

    with step('Get display name'):
        profile_display_name = \
            main_screen.left_panel.open_settings().left_panel.open_profile_settings().get_display_name

    with step('To import an account within private key open add account popup and set name, emoji and color'):
        wallet = main_screen.left_panel.open_wallet()
        account_popup = wallet.left_panel.open_add_account_popup()
        account_popup.set_name(random_wallet_acc_keypair_name()).set_emoji(emoji)

    with step('Enter private key name less than 5 characters and verify that error appears'):
        pk_name_short = ''.join(random.choices(string.ascii_letters + string.digits, k=4))
        new_account_popup = account_popup.open_add_new_account_popup()
        new_account_popup.import_and_enter_private_key(address_pair.private_key).enter_private_key_name(pk_name_short)
        assert new_account_popup.get_private_key_error_message() == WalletAccountPopup.WALLET_KEYPAIR_NAME_MIN.value

    with step('Enter private key name more than 5 characters and continue creating of import private key account'):
        pk_name = ''.join(random.choices(string.ascii_letters + string.digits, k=5))
        new_account_popup.enter_private_key_name(pk_name).click_continue()
        account_popup.save_changes()
        with step('Authenticate with password'):
            authenticate_with_password(user_account)
            account_popup.wait_until_hidden()

    with step('Open wallet settings and verify Status keypair title'):
        settings = main_screen.left_panel.open_settings().left_panel.open_wallet_settings()
        status_keypair_title = settings.get_keypairs_names()[0]
        assert profile_display_name == status_keypair_title, \
            f"Status keypair name should be equal to display name but currently it is {status_keypair_title}, \
                when display name is {profile_display_name}"

    with step('Click 3 dots menu on Status keypair and check that there is no option to rename keypair'):
        settings.click_open_menu_button(profile_display_name)
        assert not settings.rename_keypair_menu_item.is_visible
        settings.click()  # to close the menu

    with step('Click 3 dots menu on private key account, open rename keypair popup and verify it was renamed'):
        pk_new_name = ''.join(random.choices(string.ascii_letters + string.digits, k=5))
        settings.click_open_menu_button(pk_name)
        skip_pcsc_error_popup_if_visible()
        settings.click_open_menu_button(pk_name)
        rename_keypair_popup = settings.click_rename_keypair()
        rename_keypair_popup.rename_keypair(pk_new_name)
        assert pk_new_name in settings.get_keypairs_names()

    with step('Verify toast message with successful renaming appears'):
        messages = main_screen.wait_for_toast_notifications()
        assert WalletRenameKeypair.WALLET_SUCCESSFUL_RENAMING.value + 'from "' + pk_name + '" to "' + pk_new_name + '"' in messages, \
            f"Toast message have not appeared"
