import allure
import pytest
from web3 import Web3

from constants import DEFAULT_PIN, KEYCARD_EMPTY_TITLE
from constants.wallet import WalletNetworkSettings
from helpers.onboarding_helper import (
    open_create_profile_view,
    wait_until_logged_in,
    skip_biometrics_popup_if_visible,
    skip_education_popup_if_visible,
)
from helpers.settings_helper import open_wallet_settings
from scripts.utils.generators import keycard_card_id, random_mnemonic, get_wallet_address_from_mnemonic


@pytest.mark.keycard
@pytest.mark.timeout(300)
@allure.title('Onboarding — Import existing seed onto card + create profile')
@allure.description(
    'Empty card → Create profile → Use Keycard → PIN → Import from recovery phrase → '
    'Create PIN → Enter generated seed → Continue on success → land in app → '
    'Keycard settings → Read Keycard → details appear → Wallet settings address matches seed'
)
def test_onboarding_import_seed_onto_empty_keycard(keycard_simulator, main_window):
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
    skip_biometrics_popup_if_visible()
    skip_education_popup_if_visible()

    status_acc_view = open_wallet_settings(main_window).open_account_in_settings(
        WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value,
        0,
    )
    address = status_acc_view.get_account_address_value()
    expected_address = Web3.to_checksum_address(get_wallet_address_from_mnemonic(seed_phrase))
    assert address == expected_address, (
        f'Recovered account should have address {expected_address}, but has {address}'
    )

    keycard_settings = main_window.left_panel.open_settings().left_panel.open_keycard_settings()
    assert keycard_settings.is_read_keycard_button_visible
    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(DEFAULT_PIN)
    keycard_settings.wait_until_details_appears()
