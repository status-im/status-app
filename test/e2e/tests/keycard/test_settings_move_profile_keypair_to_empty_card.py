import allure
import pytest

import configs
from constants import DEFAULT_PIN, KEYCARD_EMPTY_TITLE, KEYCARD_PROFILE_DETAILS_TITLE
from helpers.onboarding_helper import skip_biometrics_popup_if_visible
from helpers.wallet_helper import authenticate_with_password
from scripts.utils.generators import keycard_card_id


@pytest.mark.keycard
@pytest.mark.timeout(300)
@allure.title('Settings — Move profile key pair to Keycard')
@allure.description(
    'Password profile → Settings → Read Keycard → empty card → Move profile key pair → '
    'confirm → Create PIN → reveal and confirm seed → password → Done → '
    'Read Keycard shows Status profile key pair'
)
def test_settings_move_profile_keypair_to_empty_keycard(keycard_simulator, main_window, user_account):
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

    keycard_mng_popup = keycard_settings.move_profile_keypair()
    keycard_mng_popup.confirm_selected_key_pair()
    keycard_mng_popup.enter_new_pin_and_confirm(pin=DEFAULT_PIN)
    keycard_mng_popup.reveal_recovery_phrase()
    seed_words = keycard_mng_popup.write_down_recovery_phrase()
    keycard_mng_popup.open_confirm_recovery_phrase().fill_the_grid_and_continue(seed_words)
    authenticate_with_password(user_account)
    keycard_mng_popup.close_after_success(configs.timeouts.APP_LOAD_TIMEOUT_MSEC)

    keycard_settings = main_window.left_panel.open_settings().left_panel.open_keycard_settings()
    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(DEFAULT_PIN)
    keycard_settings.wait_until_details_appears(KEYCARD_PROFILE_DETAILS_TITLE)
