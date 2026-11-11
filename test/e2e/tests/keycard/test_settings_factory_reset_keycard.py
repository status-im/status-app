import allure
import pytest

import configs
from constants import (
    DEFAULT_PIN,
    KEYCARD_EMPTY_TITLE,
    KEYCARD_RESET_SUCCESS_TITLE,
    KEYCARD_STORES_KEY_PAIR_TITLE,
    NEW_PIN,
    KEYCARD_APPLET_VERSIONS,
)
from helpers.keycard_helper import open_keycard_settings_for_password_profile
from scripts.utils.generators import keycard_card_id, random_mnemonic, random_wallet_acc_keypair_name


@pytest.mark.keycard
@pytest.mark.timeout(300)
@pytest.mark.parametrize('keycard_simulator', KEYCARD_APPLET_VERSIONS, indirect=True)
@allure.title('Settings — Factory reset keycard')
@allure.description(
    'Password profile → Settings → Read Keycard → import seed onto empty card → '
    'Read Keycard shows key pair → Factory reset with checkbox confirmation → '
    'success → Read Keycard shows empty card again → 4.x can be set up with a new key pair'
)
def test_settings_factory_reset_keycard(keycard_simulator, main_window, user_account):
    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id)
    keycard_simulator.plug_reader()

    keycard_settings = open_keycard_settings_for_password_profile(main_window, user_account)

    keycard_mng_popup = keycard_settings.open_read_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_mng_popup.skip_pin_and_close()
    keycard_settings.wait_until_details_appears(KEYCARD_EMPTY_TITLE)

    _import_and_read_keypair(keycard_settings, DEFAULT_PIN)
    original_key_uid = keycard_settings.key_uid if keycard_simulator.applet_40 else None

    keycard_mng_popup = keycard_settings.factory_reset()
    keycard_mng_popup.confirm_factory_reset()
    keycard_mng_popup.close_after_factory_reset_success(
        KEYCARD_RESET_SUCCESS_TITLE,
        configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
    )

    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(DEFAULT_PIN)
    keycard_settings.wait_until_details_appears(KEYCARD_EMPTY_TITLE)

    if keycard_simulator.applet_40:
        assert not keycard_settings.pairing_supported
        assert not keycard_settings.key_uid, 'Reset card still exposes the previous key pair'
        _import_and_read_keypair(keycard_settings, NEW_PIN)
        assert keycard_settings.key_uid and keycard_settings.key_uid != original_key_uid


def _import_and_read_keypair(keycard_settings, pin):
    name = random_wallet_acc_keypair_name()[:20]
    popup = keycard_settings.import_from_recovery_phrase()
    popup.enter_new_pin_and_confirm(pin=pin, expect_reveal_seed=False)
    popup.enter_recovery_phrase(random_mnemonic().split())
    popup.enter_key_pair_name(name)
    popup.enter_account_name(name)
    popup.close_after_success(configs.timeouts.LOADING_LIST_TIMEOUT_MSEC)

    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(pin)
    keycard_settings.wait_until_details_appears(KEYCARD_STORES_KEY_PAIR_TITLE)
