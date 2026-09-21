import allure
import pytest
from web3 import Web3

import configs
from constants import (
    DEFAULT_PIN,
    KEYCARD_EMPTY_TITLE,
    KEYCARD_KEYPAIR_MOVED_TO_STATUS_TITLE,
    KEYCARD_ON_DEVICE_LABEL,
    KEYCARD_ON_KEYCARD_LABEL,
)
from helpers.onboarding_helper import skip_biometrics_popup_if_visible
from helpers.settings_helper import open_wallet_settings
from helpers.wallet_helper import authenticate_with_password
from scripts.utils.generators import (
    get_wallet_address_from_mnemonic,
    keycard_card_id,
    random_mnemonic,
    random_wallet_acc_keypair_name,
)


@pytest.mark.keycard
@pytest.mark.timeout(300)
@allure.title('Wallet settings — Stop using Keycard for wallet key pair')
@allure.description(
    'Password profile → import seed onto empty card → Wallet settings → keypair menu → '
    'Stop using Keycard → confirm → seed → password → Done → keypair shows On device '
    'and account address matches the seed'
)
def test_settings_stop_using_keycard_for_wallet_keypair(
        keycard_simulator, main_window, user_account
):
    seed_phrase = random_mnemonic()
    name = random_wallet_acc_keypair_name()[:20]
    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id)
    keycard_simulator.plug_reader()

    main_window.create_profile(user_account)
    skip_biometrics_popup_if_visible()

    keycard_settings = main_window.left_panel.open_settings().left_panel.open_keycard_settings()
    keycard_mng_popup = keycard_settings.open_read_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_mng_popup.skip_pin_and_close()
    keycard_settings.wait_until_details_appears(KEYCARD_EMPTY_TITLE)

    keycard_mng_popup = keycard_settings.import_from_recovery_phrase()
    keycard_mng_popup.enter_new_pin_and_confirm(pin=DEFAULT_PIN, expect_reveal_seed=False)
    keycard_mng_popup.enter_recovery_phrase(seed_phrase.split())
    keycard_mng_popup.enter_key_pair_name(name)
    keycard_mng_popup.enter_account_name(name)
    keycard_mng_popup.close_after_success(configs.timeouts.LOADING_LIST_TIMEOUT_MSEC)

    wallet_settings = open_wallet_settings(main_window)
    assert name in wallet_settings.get_keypairs_names()
    assert KEYCARD_ON_KEYCARD_LABEL in wallet_settings.get_keypair_location(name)

    keycard_mng_popup = wallet_settings.open_keypair_keycard_menu(name)
    keycard_mng_popup.confirm_selected_key_pair()
    keycard_mng_popup.enter_recovery_phrase(seed_phrase.split())
    authenticate_with_password(user_account)
    keycard_mng_popup.wait_until_success(KEYCARD_KEYPAIR_MOVED_TO_STATUS_TITLE)
    keycard_mng_popup.close_after_success(configs.timeouts.APP_LOAD_TIMEOUT_MSEC)

    assert KEYCARD_ON_DEVICE_LABEL in wallet_settings.get_keypair_location(name)
    imported_acc_view = wallet_settings.open_account_in_settings(name, 0)
    address = imported_acc_view.get_account_address_value()
    expected_address = Web3.to_checksum_address(get_wallet_address_from_mnemonic(seed_phrase))
    assert address == expected_address, (
        f'Imported account should have address {expected_address}, but has {address}'
    )
