import allure
import pytest
from web3 import Web3

from constants import DEFAULT_PIN, KEYCARD_EMPTY_TITLE
from helpers.keycard_helper import (
    assert_status_account_matches_seed,
    sign_with_keycard_pin,
)
from helpers.onboarding_helper import (
    open_create_profile_view,
    wait_until_logged_in,
)
from helpers.wallet_connect_helper import WalletConnectDapp
from helpers.wallet_helper import open_wallet_account
from scripts.utils.generators import get_wallet_address_from_mnemonic, keycard_card_id, random_mnemonic


@pytest.mark.keycard
@pytest.mark.timeout(400)
@allure.title('WalletConnect — personal_sign with Keycard PIN')
@allure.description(
    'Create keycard profile by importing a seed, connect a WalletConnect test dApp, '
    'approve connection and sign request, then sign the message with Keycard PIN.'
)
def test_wallet_connect_personal_sign_keycard(keycard_simulator, main_window):
    seed_phrase = random_mnemonic()
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

    assert_status_account_matches_seed(main_window, seed_phrase)
    account_address = Web3.to_checksum_address(get_wallet_address_from_mnemonic(seed_phrase))

    dapp = WalletConnectDapp()
    try:
        wallet_account = open_wallet_account(main_window)
        dapps_workflow = wallet_account.open_dapps_connect_flow()
        dapp.start(account_address)
        dapps_workflow.pair_with_uri(dapp.wait_for_uri()).approve_connection()
        dapp.wait_for_phase('session_approved')

        dapps_workflow.approve_sign_request()
        sign_with_keycard_pin(DEFAULT_PIN)

        signature = dapp.wait_for_signature()
        assert len(signature) > 10
    finally:
        dapp.stop()
