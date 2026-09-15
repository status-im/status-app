import allure
import pytest

from constants import DEFAULT_PIN
from helpers.keycard_helper import (
    assert_status_account_matches_seed,
    create_keycard_profile_from_seed,
    sign_with_keycard_pin,
)
from helpers.wallet_connect_helper import WalletConnectDapp, request_personal_sign
from scripts.utils.generators import random_mnemonic


@pytest.mark.keycard
@pytest.mark.timeout(400)
@allure.title('WalletConnect — personal_sign with Keycard PIN')
@allure.description(
    'Create keycard profile by importing a seed, connect a WalletConnect test dApp, '
    'approve connection and sign request, then sign the message with Keycard PIN.'
)
def test_wallet_connect_personal_sign_keycard(keycard_simulator, main_window):
    seed_phrase = random_mnemonic()
    create_keycard_profile_from_seed(keycard_simulator, main_window, seed_phrase)
    account_address = assert_status_account_matches_seed(main_window, seed_phrase)

    with WalletConnectDapp() as dapp:
        request_personal_sign(main_window, dapp, account_address)
        sign_with_keycard_pin(DEFAULT_PIN)
        dapp.assert_signed_by(account_address)
