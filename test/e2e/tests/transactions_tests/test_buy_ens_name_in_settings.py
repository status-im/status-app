import allure
import pytest
from allure_commons._allure import step

import configs
import driver
from configs import WALLET_SEED
from configs.timeouts import UI_LOAD_TIMEOUT_SEC
from constants import ReturningUser
from helpers.onboarding_helper import open_create_profile_view, import_seed_and_log_in
from helpers.settings_helper import enable_testnet_mode
from helpers.wallet_helper import authenticate_with_password
from scripts.utils.generators import random_ens_string
from constants.wallet import WalletTransactions
from gui.components.wallet.send_popup import SendPopup
from gui.screens.settings_ens_usernames import ENSRegisteredView


@pytest.mark.case(704597)
@pytest.mark.transaction
@pytest.mark.parametrize('ens_name', [pytest.param(random_ens_string())])
def test_ens_name_purchase(main_window, user_account, ens_name):
    user_account = ReturningUser(
        seed_phrase=WALLET_SEED,
        status_address='0x44ddd47a0c7681a5b0fa080a56cbb7701db4bb43')

    with step('Import seed and log in'):
        with step('Open Create your profile view'):
            create_your_profile_view = open_create_profile_view()
        with step('Import seed and log in'):
            import_seed_and_log_in(create_your_profile_view, user_account.seed_phrase, user_account)

    with step('Set testnet mode'):
        enable_testnet_mode(main_window)

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
        register_ens.send_button.click()
        send_popup = SendPopup().wait_until_appears()

    with step('Sign and send transaction to blockchain'):
        sign_send_modal = send_popup.open_sign_send_modal()
        sign_send_modal.sign_send_modal_sign_button.click()

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    with step('Verify toast message with Transaction pending appears'):
        assert WalletTransactions.ENS_TRANSACTION_REGISTERING_TOAST_MESSAGE.value in ' '.join(
            main_window.wait_for_toast_notifications())

    with step('Verify username registered view appears'):
        ENSRegisteredView().wait_until_appears()
