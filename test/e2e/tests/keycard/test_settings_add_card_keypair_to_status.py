import allure
import pytest
from web3 import Web3

import configs
from constants import (
    DEFAULT_PIN,
    DEFAULT_PUK,
    KEYCARD_STORES_KEY_PAIR_TITLE,
)
from helpers.onboarding_helper import skip_biometrics_popup_if_visible
from helpers.settings_helper import open_wallet_settings
from scripts.utils.generators import (
    get_wallet_address_from_mnemonic,
    keycard_card_id,
    random_mnemonic,
    random_wallet_acc_keypair_name,
)


@pytest.mark.keycard
@pytest.mark.timeout(300)
@allure.title('Settings — Import card keypair into Status wallet')
@allure.description(
    'Password profile → Keycard with a foreign seed → Settings → Read Keycard → PIN → '
    'Add key pair to Status wallet → name key pair and account → Done → wallet settings '
    'list the key pair and account address matches the seed → Read Keycard shows the key pair'
)
def test_settings_add_card_keypair_to_status(keycard_simulator, main_window, user_account):
    seed_phrase = random_mnemonic()
    name = random_wallet_acc_keypair_name()[:20]
    card_id = keycard_card_id()
    keycard_simulator.create_card_with_seed(
        card_id, seed_phrase, DEFAULT_PIN, DEFAULT_PUK
    )
    keycard_simulator.plug_reader()

    main_window.create_profile(user_account)
    skip_biometrics_popup_if_visible()

    keycard_settings = main_window.left_panel.open_settings().left_panel.open_keycard_settings()

    keycard_mng_popup = keycard_settings.open_read_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_mng_popup.enter_keycard_pin_and_close(DEFAULT_PIN)
    keycard_settings.wait_until_keypair_not_in_wallet()

    keycard_mng_popup = keycard_settings.add_keypair_to_status()
    keycard_mng_popup.enter_pin(DEFAULT_PIN)
    keycard_mng_popup.enter_key_pair_name(name)
    keycard_mng_popup.enter_account_name(name)
    keycard_mng_popup.close_after_success(configs.timeouts.LOADING_LIST_TIMEOUT_MSEC)

    wallet_settings = open_wallet_settings(main_window)
    keypairs = wallet_settings.get_keypairs_names()
    assert name in keypairs, f'Expected key pair {name!r} in wallet settings, got {keypairs!r}'
    imported_acc_view = wallet_settings.open_account_in_settings(name, 0)
    address = imported_acc_view.get_account_address_value()
    expected_address = Web3.to_checksum_address(get_wallet_address_from_mnemonic(seed_phrase))
    assert address == expected_address, (
        f'Imported account should have address {expected_address}, but has {address}'
    )

    keycard_settings = main_window.left_panel.open_settings().left_panel.open_keycard_settings()
    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(DEFAULT_PIN)
    keycard_settings.wait_until_details_appears(KEYCARD_STORES_KEY_PAIR_TITLE)
