import time

import allure
import pytest
from allure_commons._allure import step

import configs
from constants import DEFAULT_PIN
from constants.wallet import (
    WalletAddress,
    WalletHistoryTitles,
    WalletNetworkNaming,
)
from gui.components.wallet.send_popup import SendPopup
from helpers.keycard_helper import (
    assert_status_account_matches_seed,
    create_keycard_profile_from_seed,
    sign_with_keycard_pin,
)
from helpers.onboarding_helper import skip_post_login_popups_if_visible
from helpers.settings_helper import enable_testnet_mode
from helpers.wallet_helper import (
    open_wallet_account,
    wait_for_account_assets_loaded,
    wallet_send_returning_user,
)
from scripts.utils.generators import get_wallet_address_from_mnemonic

FUNDED_WALLET_ADDRESS = wallet_send_returning_user().status_address


@pytest.mark.keycard
@pytest.mark.transaction
@pytest.mark.timeout(600)
@allure.title('Wallet — send 0 ETH from keycard account (sign with PIN)')
@allure.description(
    'Create keycard profile by importing funded WALLET_TEST_USER_SEED, enable testnet, '
    'send 0 ETH on Sepolia and sign the transaction with Keycard PIN.'
)
@pytest.mark.parametrize('receiver_account_address, amount, network_name', [
    pytest.param(
        WalletAddress.RECEIVER_ADDRESS.value,
        '0',
        WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET.value,
    ),
])
def test_wallet_send_0_eth_from_keycard(
        keycard_simulator,
        main_window,
        receiver_account_address,
        amount,
        network_name,
):
    seed_phrase = (configs.WALLET_SEED or '').strip()
    if not seed_phrase:
        pytest.skip(
            'WALLET_TEST_USER_SEED not set — requires the seed phrase of the '
            f'funded test profile ({FUNDED_WALLET_ADDRESS})'
        )

    derived_address = get_wallet_address_from_mnemonic(seed_phrase)
    assert derived_address.lower() == FUNDED_WALLET_ADDRESS.lower(), (
        f'WALLET_TEST_USER_SEED derives {derived_address!r}, expected funded test address '
        f'{FUNDED_WALLET_ADDRESS!r}'
    )

    create_keycard_profile_from_seed(keycard_simulator, main_window, seed_phrase)

    assert_status_account_matches_seed(main_window, seed_phrase)

    enable_testnet_mode(main_window)
    skip_post_login_popups_if_visible()

    wallet_account = open_wallet_account(main_window)
    wait_for_account_assets_loaded(wallet_account)
    send_popup = wallet_account.open_send_popup()

    with step('Select network'):
        send_popup.select_network(network_name)

    with step('Sign and send ETH transaction to blockchain'):
        sent_at = time.time()
        send_popup.sign_and_send(receiver_account_address, amount, 'ETH')

    with step('Sign with Keycard PIN'):
        sign_with_keycard_pin(DEFAULT_PIN)

    with step('Verify send flow completed'):
        SendPopup().wait_until_hidden()

    with step('Verify ETH transaction appears in History'):
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.SEND,
            network_name=network_name,
            sent_at=sent_at,
            to_address=receiver_account_address,
            amount=amount,
        )
