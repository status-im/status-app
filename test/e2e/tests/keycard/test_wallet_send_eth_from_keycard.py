import time

import allure
import pytest
from allure_commons._allure import step

import configs
from constants import DEFAULT_PIN, KEYCARD_EMPTY_TITLE
from constants.wallet import (
    WalletAddress,
    WalletHistoryTitles,
    WalletNetworkNaming,
)
from gui.components.wallet.send_popup import SendPopup
from helpers.keycard_helper import (
    assert_status_account_matches_seed,
    sign_with_keycard_pin,
)
from helpers.onboarding_helper import (
    open_create_profile_view,
    skip_post_login_popups_if_visible,
    wait_until_logged_in,
)
from helpers.settings_helper import enable_testnet_mode
from helpers.wallet_helper import (
    open_wallet_account,
    wait_for_account_assets_loaded,
    wallet_send_returning_user,
)
from scripts.utils.generators import get_wallet_address_from_mnemonic, keycard_card_id

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

    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id)
    keycard_simulator.plug_reader()
    keycard_mng_popup = open_create_profile_view().open_create_profile_with_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_dtls_view = keycard_mng_popup.enter_keycard_pin(pin=DEFAULT_PIN)
    assert keycard_dtls_view.keycard_view_title.text == KEYCARD_EMPTY_TITLE

    keycard_mng_popup = keycard_dtls_view.import_from_recovery_phrase()
    keycard_mng_popup.enter_new_pin_and_confirm(pin=DEFAULT_PIN, expect_reveal_seed=False)
    keycard_mng_popup.enter_recovery_phrase(seed_phrase.split())
    keycard_mng_popup.continue_after_key_pair_imported()
    wait_until_logged_in(main_window)
    skip_post_login_popups_if_visible()

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
