import allure
import pytest

import configs
from constants import DEFAULT_PIN, KEYCARD_EMPTY_TITLE, KEYCARD_PROFILE_DETAILS_TITLE, KEYCARD_APPLET_VERSIONS
from gui.screens.onboarding import KeycardLoginView
from helpers.keycard_helper import open_keycard_settings_for_password_profile, read_keycard_details
from helpers.wallet_helper import authenticate_with_password
from scripts.utils.generators import keycard_card_id


@pytest.mark.keycard
@pytest.mark.timeout(300)
@pytest.mark.parametrize('keycard_simulator', KEYCARD_APPLET_VERSIONS, indirect=True)
@allure.title('Settings — Move profile key pair to Keycard')
@allure.description(
    'Password profile → Settings → Read Keycard → empty card → Move profile key pair → '
    'confirm → Create PIN → reveal and confirm seed → password → Done → '
    'Read Keycard shows Status profile key pair → for 4.x, restart and see Keycard login'
)
def test_settings_move_profile_keypair_to_empty_keycard(keycard_simulator, main_window, user_account, aut):
    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id)
    keycard_simulator.plug_reader()

    keycard_settings = open_keycard_settings_for_password_profile(main_window, user_account)

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

    keycard_settings = read_keycard_details(main_window, DEFAULT_PIN, KEYCARD_PROFILE_DETAILS_TITLE)
    if keycard_simulator.applet_40:
        assert not keycard_settings.pairing_supported
        aut.restart()
        main_window.prepare()
        KeycardLoginView().wait_until_appears(configs.timeouts.APP_LOAD_TIMEOUT_MSEC)
