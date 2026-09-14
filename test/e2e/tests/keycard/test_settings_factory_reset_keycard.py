import allure
import pytest

import configs
from constants import (
    DEFAULT_PIN,
    KEYCARD_EMPTY_TITLE,
    KEYCARD_RESET_SUCCESS_TITLE,
    KEYCARD_STORES_KEY_PAIR_TITLE,
)
from helpers.onboarding_helper import skip_biometrics_popup_if_visible
from scripts.utils.generators import keycard_card_id, random_mnemonic, random_wallet_acc_keypair_name


@pytest.mark.keycard
@pytest.mark.timeout(300)
@allure.title('Settings — Factory reset keycard')
@allure.description(
    'Password profile → Settings → Read Keycard → import seed onto empty card → '
    'Read Keycard shows key pair → Factory reset with checkbox confirmation → '
    'success → Read Keycard shows empty card again'
)
def test_settings_factory_reset_keycard(keycard_simulator, main_window, user_account):
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

    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(DEFAULT_PIN)
    keycard_settings.wait_until_details_appears(KEYCARD_STORES_KEY_PAIR_TITLE)

    keycard_mng_popup = keycard_settings.factory_reset()
    keycard_mng_popup.confirm_factory_reset()
    keycard_mng_popup.close_after_factory_reset_success(
        KEYCARD_RESET_SUCCESS_TITLE,
        configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
    )

    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(DEFAULT_PIN)
    keycard_settings.wait_until_details_appears(KEYCARD_EMPTY_TITLE)
