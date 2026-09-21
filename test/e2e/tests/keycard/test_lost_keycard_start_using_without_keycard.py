import allure
import pytest

from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from constants import (
    DEFAULT_PIN,
    KEYCARD_CONVERT_SUCCESS_TITLE,
    KEYCARD_EMPTY_TITLE,
)
from driver.aut import AUT
from gui.screens.onboarding import (
    ConvertKeycardAccountView,
    KeycardLoginView,
    ReturningLoginView,
)
from helpers.keycard_helper import assert_status_account_matches_seed
from helpers.onboarding_helper import (
    open_create_profile_view,
    skip_post_login_popups_if_visible,
    wait_until_logged_in,
)
from scripts.utils.generators import keycard_card_id

NEW_PASSWORD = 'StatusPass1!'


@pytest.mark.keycard
@pytest.mark.timeout(500)
@allure.title('Lost Keycard — start using profile without Keycard')
@allure.description(
    'Provision profile on Keycard, restart (local profile on device), Lost Keycard → '
    'Start using profile without Keycard → recovery phrase → password → convert → '
    'restart → login with the new password without a Keycard → same profile.'
)
def test_lost_keycard_start_using_without_keycard(keycard_simulator, main_window, aut: AUT):
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
    keycard_login_view = KeycardLoginView().wait_until_appears(APP_LOAD_TIMEOUT_MSEC)

    lost_keycard_view = keycard_login_view.open_lost_keycard_page()
    keycard_mng_popup = lost_keycard_view.start_using_profile_without_keycard()
    keycard_mng_popup.enter_recovery_phrase(seed_words)
    keycard_mng_popup.create_and_confirm_password(NEW_PASSWORD)
    keycard_mng_popup.continue_after_key_pair_imported()
    keycard_mng_popup.wait_until_hidden()

    ConvertKeycardAccountView().wait_until_convert_succeeds(
        KEYCARD_CONVERT_SUCCESS_TITLE,
        APP_LOAD_TIMEOUT_MSEC * 3,
    )

    aut.restart()
    main_window.prepare()
    login_view = ReturningLoginView().wait_until_appears(APP_LOAD_TIMEOUT_MSEC)
    assert login_view.password_box.is_visible, 'Expected password login after converting off Keycard'
    login_view.log_in_with_password(NEW_PASSWORD)
    wait_until_logged_in(main_window)
    skip_post_login_popups_if_visible()

    assert_status_account_matches_seed(main_window, seed_words)
