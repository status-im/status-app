import random

import allure
import pytest
from allure_commons._allure import step

from configs import WALLET_SEED
from constants import ReturningUser
from constants.wallet import WalletAddress, WalletNetworkSettings
from helpers.onboarding_helper import open_create_profile_view, import_seed_and_log_in
from helpers.settings_helper import enable_testnet_mode, open_network_settings
from helpers.wallet_helper import authenticate_with_password, open_send_modal_for_account
from scripts.utils.generators import random_network


@pytest.mark.case(704527, 738784)
@pytest.mark.transaction
@pytest.mark.smoke
@pytest.mark.parametrize('receiver_account_address, amount, asset, collectible', [
    pytest.param(WalletAddress.RECEIVER_ADDRESS.value, '0', 'ETH', '')
])
@pytest.mark.parametrize('network_name', [pytest.param(random_network())])
def test_wallet_send_0_eth(main_window, user_account, receiver_account_address, amount, asset, collectible, network_name):

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

    with step(f'Enable network {network_name}'):
        networks_screen = open_network_settings(main_window)
        networks_screen.toggle_network_state(network_name, True)

    with step('Open wallet send popup'):
        send_popup = open_send_modal_for_account(
            main_window, account_name=WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value)


    with step('Select network'):
        send_popup.select_network(network_name)

    with step('Sign and send transaction to blockchain'):
        send_popup.sign_and_send(receiver_account_address, amount, asset)

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    toast_messages = ' '.join(main_window.wait_for_toast_notifications()).replace('×', 'x')
    account_name = WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value
    address_start = receiver_account_address[:6]  # First 6 chars: 0x3286
    normalized_toast = ' '.join(toast_messages.split())
    
    # Check for key components: either "Sending" or "Sent", account name, and address start
    has_sending_or_sent = ('Sending' in normalized_toast or 'Sent' in normalized_toast)
    has_account_name = account_name in normalized_toast
    has_address = address_start in normalized_toast
    
    assert (has_sending_or_sent and has_account_name and has_address), \
        f'Expected toast message with "Sending" or "Sent", account "{account_name}", and address starting with "{address_start}", but got: {toast_messages}'
