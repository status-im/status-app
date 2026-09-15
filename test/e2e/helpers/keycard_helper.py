import allure
from web3 import Web3

import configs
from constants import DEFAULT_PIN, KEYCARD_EMPTY_TITLE
from gui.components.sign_popup import SignPopup
from helpers.onboarding_helper import open_create_profile_view, wait_until_logged_in
from helpers.wallet_helper import get_status_account_address
from scripts.utils.generators import get_wallet_address_from_mnemonic, keycard_card_id


@allure.step('Sign with Keycard PIN')
def sign_with_keycard_pin(pin: str, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
    SignPopup().enter_pin(pin, timeout_msec)


@allure.step('Create Keycard profile from recovery phrase')
def create_keycard_profile_from_seed(
        keycard_simulator,
        main_window,
        seed_phrase: str,
        pin: str = DEFAULT_PIN,
):
    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id)
    keycard_simulator.plug_reader()
    management_popup = open_create_profile_view().open_create_profile_with_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    details_view = management_popup.enter_keycard_pin(pin=pin)
    assert details_view.keycard_view_title.text == KEYCARD_EMPTY_TITLE

    management_popup = details_view.import_from_recovery_phrase()
    management_popup.enter_new_pin_and_confirm(pin=pin, expect_reveal_seed=False)
    management_popup.enter_recovery_phrase(seed_phrase.split())
    management_popup.continue_after_key_pair_imported()
    wait_until_logged_in(main_window)


@allure.step('Read Keycard in settings and wait for {title}')
def read_keycard_details(main_window, pin: str, title: str):
    keycard_settings = main_window.left_panel.open_settings().left_panel.open_keycard_settings()
    assert keycard_settings.is_read_keycard_button_visible
    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(pin)
    keycard_settings.wait_until_details_appears(title)


@allure.step('Assert Status account address matches seed')
def assert_status_account_matches_seed(main_window, seed_phrase: str | list[str]) -> str:
    if not isinstance(seed_phrase, str):
        seed_phrase = ' '.join(seed_phrase)
    address = get_status_account_address(main_window)
    expected_address = Web3.to_checksum_address(get_wallet_address_from_mnemonic(seed_phrase))
    assert address == expected_address, (
        f'Expected address {expected_address}, got {address}'
    )
    return expected_address
