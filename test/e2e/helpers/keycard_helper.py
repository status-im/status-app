import allure
from web3 import Web3

from constants.wallet import WalletNetworkSettings
from helpers.settings_helper import open_wallet_settings
from scripts.utils.generators import get_wallet_address_from_mnemonic


@allure.step('Read Keycard in settings and wait for {title}')
def read_keycard_details(main_window, pin: str, title: str):
    keycard_settings = main_window.left_panel.open_settings().left_panel.open_keycard_settings()
    assert keycard_settings.is_read_keycard_button_visible
    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(pin)
    keycard_settings.wait_until_details_appears(title)


@allure.step('Assert Status account address matches seed')
def assert_status_account_matches_seed(main_window, seed_phrase: str | list[str]):
    if not isinstance(seed_phrase, str):
        seed_phrase = ' '.join(seed_phrase)
    status_acc_view = open_wallet_settings(main_window).open_account_in_settings(
        WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value,
        0,
    )
    address = status_acc_view.get_account_address_value()
    expected_address = Web3.to_checksum_address(get_wallet_address_from_mnemonic(seed_phrase))
    assert address == expected_address, (
        f'Expected address {expected_address}, got {address}'
    )
