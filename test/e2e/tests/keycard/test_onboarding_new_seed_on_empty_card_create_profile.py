import allure
import pytest

from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from constants import (
    DEFAULT_PIN,
    DEFAULT_PUK,
    KEYCARD_EMPTY_TITLE,
    KEYCARD_PROFILE_DETAILS_TITLE,
)
from driver.aut import AUT
from gui.screens.onboarding import KeycardLoginView
from helpers.keycard_helper import (
    assert_status_account_matches_seed,
    read_keycard_details,
)
from helpers.onboarding_helper import (
    open_create_profile_view,
    wait_until_logged_in,
    skip_post_login_popups_if_visible,
)
from scripts.utils.generators import keycard_card_id


@pytest.mark.keycard
@pytest.mark.timeout(400)
@allure.title('Onboarding — create profile on empty Keycard, restart, login with PIN')
@allure.description(
    'Empty card → Create profile → Use Keycard → PIN → Import new key pair → '
    'Reveal and confirm seed → Continue on success → land in app → Keycard settings → '
    'Read Keycard shows profile key pair → restart → provision the same card in simulator → '
    'login with PIN → land in the same profile (wallet address matches seed, Read Keycard still profile)'
)
def test_onboarding_empty_keycard_log_in(keycard_simulator, main_window, aut: AUT):
    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id)
    keycard_simulator.plug_reader()
    keycard_mng_popup = open_create_profile_view().open_create_profile_with_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_dtls_view = keycard_mng_popup.enter_keycard_pin(pin=DEFAULT_PIN)
    assert keycard_dtls_view.keycard_view_title.text == KEYCARD_EMPTY_TITLE

    keycard_mng_popup = keycard_dtls_view.import_a_new_keypair()
    keycard_mng_popup.enter_new_pin_and_confirm(pin=DEFAULT_PIN)
    keycard_mng_popup.reveal_recovery_phrase()
    seed_words = keycard_mng_popup.write_down_recovery_phrase()
    keycard_mng_popup.open_confirm_recovery_phrase().fill_the_grid_and_continue(seed_words)
    keycard_mng_popup.continue_after_key_pair_imported()
    wait_until_logged_in(main_window)
    skip_post_login_popups_if_visible()

    read_keycard_details(main_window, DEFAULT_PIN, KEYCARD_PROFILE_DETAILS_TITLE)

    aut.restart()
    main_window.prepare()
    KeycardLoginView().wait_until_appears(APP_LOAD_TIMEOUT_MSEC)

    keycard_simulator.wait_until_appears(APP_LOAD_TIMEOUT_MSEC).start_simulator()
    keycard_simulator.create_card_with_seed(
        card_id, ' '.join(seed_words), DEFAULT_PIN, DEFAULT_PUK
    )
    keycard_simulator.plug_reader()
    keycard_simulator.insert_card()
    KeycardLoginView().log_in_with_pin(DEFAULT_PIN)
    wait_until_logged_in(main_window)
    skip_post_login_popups_if_visible()

    assert_status_account_matches_seed(main_window, seed_words)
    read_keycard_details(main_window, DEFAULT_PIN, KEYCARD_PROFILE_DETAILS_TITLE)
