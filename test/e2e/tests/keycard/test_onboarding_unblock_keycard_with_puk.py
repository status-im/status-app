import allure
import pytest

import configs
from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from constants import (
    DEFAULT_PIN,
    DEFAULT_PUK,
    KEYCARD_BLOCKED_TITLE,
    KEYCARD_EMPTY_TITLE,
    KEYCARD_LOGIN_BLOCKED_MESSAGE,
    KEYCARD_PROFILE_DETAILS_TITLE,
    KEYCARD_UNBLOCK_SUCCESS_TITLE,
    NEW_PIN,
    WRONG_PIN_NOT_FACTORY,
)
from driver.aut import AUT
from gui.screens.onboarding import KeycardLoginView
from helpers.keycard_helper import (
    assert_status_account_matches_seed,
    read_keycard_details,
)
from helpers.onboarding_helper import (
    open_create_profile_view,
    skip_post_login_popups_if_visible,
    wait_until_logged_in,
)
from scripts.utils.generators import keycard_card_id


@pytest.mark.keycard
@pytest.mark.timeout(400)
@allure.title('Onboarding — Unblock keycard with PUK')
@allure.description(
    'Create Keycard profile → restart (local profile) → new simulator card with the same seed → '
    'wrong PIN x3 on login → Unblock → KeycardDetailsPage → Unblock with PUK and set new PIN → '
    'login with new PIN lands in the same profile'
)
def test_onboarding_unblock_keycard_with_puk(keycard_simulator, main_window, aut: AUT):
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

    aut.restart()
    main_window.prepare()
    KeycardLoginView().wait_until_appears(APP_LOAD_TIMEOUT_MSEC)

    new_card_id = keycard_card_id()
    keycard_simulator.wait_until_appears(APP_LOAD_TIMEOUT_MSEC).start_simulator()
    keycard_simulator.create_card_with_seed(
        new_card_id, ' '.join(seed_words), DEFAULT_PIN, DEFAULT_PUK
    )
    keycard_simulator.plug_reader().select_card(new_card_id)
    keycard_simulator.insert_card()
    keycard_login_view = KeycardLoginView().wait_until_appears(APP_LOAD_TIMEOUT_MSEC)
    keycard_login_view.enter_wrong_pin_until_blocked(WRONG_PIN_NOT_FACTORY)
    assert keycard_login_view.info_text == KEYCARD_LOGIN_BLOCKED_MESSAGE

    keycard_dtls_view = keycard_login_view.open_unblock_details()
    assert keycard_dtls_view.keycard_view_title.text == KEYCARD_BLOCKED_TITLE
    assert keycard_dtls_view.is_unblock_puk_visible

    keycard_mng_popup = keycard_dtls_view.unblock_with_puk()
    keycard_mng_popup.unblock_with_puk(NEW_PIN, DEFAULT_PUK)
    keycard_mng_popup.close_after_unblock_success(
        KEYCARD_UNBLOCK_SUCCESS_TITLE,
        configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
    )
    keycard_dtls_view.wait_until_hidden()

    KeycardLoginView().wait_until_appears(APP_LOAD_TIMEOUT_MSEC).log_in_with_pin(NEW_PIN)
    wait_until_logged_in(main_window)
    skip_post_login_popups_if_visible()

    assert_status_account_matches_seed(main_window, seed_words)
    read_keycard_details(main_window, NEW_PIN, KEYCARD_PROFILE_DETAILS_TITLE)
