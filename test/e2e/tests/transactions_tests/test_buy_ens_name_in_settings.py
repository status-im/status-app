import time

import pytest
from allure_commons._allure import step

import driver
from configs.timeouts import UI_LOAD_TIMEOUT_SEC
from helpers.wallet_helper import (
    authenticate_with_password,
    open_wallet_account,
    wallet_send_import_user,
    wallet_send_returning_user,
)
from scripts.utils.generators import random_ens_string
from constants.wallet import WalletHistoryTitles, WalletNetworkNaming
from gui.screens.settings_ens_usernames import ENSRegisteredView


@pytest.mark.case(704597)
@pytest.mark.transaction
@pytest.mark.parametrize('ens_name', [pytest.param(random_ens_string())])
def test_ens_name_purchase(main_window, user_account, ens_name):
    user_account = wallet_send_returning_user()
    wallet_send_import_user(main_window, user_account)

    with step('Open ENS usernames settings and enter user name'):
        settings = main_window.left_panel.open_settings()
        ens_settings = settings.left_panel.open_ens_usernames_settings().start()
        ens_settings.enter_user_name(ens_name)
        if driver.waitFor(lambda: 'Username already taken :(' in ens_settings.ens_text_notes(), UI_LOAD_TIMEOUT_SEC):
            ens_settings.enter_user_name(ens_name)

    with step('Verify that user name is available'):
        assert driver.waitFor(lambda: '✓ Username available!' in ens_settings.ens_text_notes(), UI_LOAD_TIMEOUT_SEC)

    with step('Register ens username'):
        register_ens = ens_settings.click_next_button().register_ens_name()

    with step('Confirm sending amount for purchasing ens username in send popup'):
        send_popup = register_ens
        send_popup.wait_for_review_send_ready()

    with step('Sign and send transaction to blockchain'):
        sent_at = time.time()
        sign_send_modal = send_popup.open_sign_send_modal()
        sign_send_modal.sign_send_modal_sign_button.click()

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    with step('Verify username registered view appears'):
        ENSRegisteredView().wait_until_appears()

    with step('Verify ENS transaction appears in History'):
        wallet_account = open_wallet_account(main_window)
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.ENS,
            network_name=WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET.value,
            sent_at=sent_at,
        )
