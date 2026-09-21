import allure
import pytest
from web3 import Web3

import configs
import driver
from constants import (
    DEFAULT_PIN,
    KEYCARD_ON_KEYCARD_LABEL,
    KEYCARD_STORES_KEY_PAIR_TITLE,
    RandomWalletAccount,
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
@allure.title('Wallet settings — Move wallet key pair to Keycard')
@allure.description(
    'Password profile → import seed key pair in wallet settings → keypair menu → '
    'Move key pair to a Keycard → confirm → Create PIN → enter seed → password → Done → '
    'keypair shows On Keycard → Read Keycard shows the key pair'
)
def test_settings_move_wallet_keypair_to_empty_keycard(keycard_simulator, main_window, user_account):
    seed_phrase = random_mnemonic()
    keypair_name = random_wallet_acc_keypair_name()[:20]
    wallet_account = RandomWalletAccount()
    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id)
    keycard_simulator.plug_reader()

    main_window.create_profile(user_account)
    skip_biometrics_popup_if_visible()

    wallet_settings = open_wallet_settings(main_window)
    account_popup = wallet_settings.open_add_account_pop_up()
    add_new_account = account_popup.set_name(wallet_account.name).open_add_new_account_popup()
    add_new_account.enter_new_seed_phrase(seed_phrase.split())
    add_new_account.enter_seed_phrase_name(keypair_name)
    add_new_account.click_continue()
    account_popup.save_changes()
    authenticate_with_password(user_account)
    account_popup.wait_until_hidden()

    assert driver.waitFor(
        lambda: keypair_name in wallet_settings.get_keypairs_names(),
        configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
    ), f'Expected key pair {keypair_name!r} in wallet settings'

    keycard_mng_popup = wallet_settings.open_keypair_keycard_menu(keypair_name)
    keycard_simulator.select_card(card_id).insert_card()
    keycard_mng_popup.confirm_selected_key_pair()
    keycard_mng_popup.enter_new_pin_and_confirm(pin=DEFAULT_PIN, expect_reveal_seed=False)
    keycard_mng_popup.enter_recovery_phrase(seed_phrase.split())
    authenticate_with_password(user_account)
    keycard_mng_popup.close_after_success(configs.timeouts.APP_LOAD_TIMEOUT_MSEC)

    assert driver.waitFor(
        lambda: KEYCARD_ON_KEYCARD_LABEL in wallet_settings.get_keypair_location(keypair_name),
        configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
    ), (
        f'Expected {KEYCARD_ON_KEYCARD_LABEL!r} for {keypair_name!r}, '
        f'got {wallet_settings.get_keypair_location(keypair_name)!r}'
    )
    imported_acc_view = wallet_settings.open_account_in_settings(wallet_account.name, 0)
    address = imported_acc_view.get_account_address_value()
    expected_address = Web3.to_checksum_address(get_wallet_address_from_mnemonic(seed_phrase))
    assert address == expected_address, (
        f'Imported account should have address {expected_address}, but has {address}'
    )

    keycard_settings = main_window.left_panel.open_settings().left_panel.open_keycard_settings()
    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(DEFAULT_PIN)
    keycard_settings.wait_until_details_appears(KEYCARD_STORES_KEY_PAIR_TITLE)
