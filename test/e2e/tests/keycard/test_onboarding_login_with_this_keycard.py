import allure
import pytest

from constants import (
    DEFAULT_PIN,
    DEFAULT_PUK,
    KEYCARD_EMPTY_TITLE,
    KEYCARD_PROFILE_DETAILS_TITLE,
    KEYCARD_STORES_KEY_PAIR_TITLE,
)
from driver.aut import AUT
from gui.screens.onboarding import OnboardingWelcomeToStatusView
from helpers.keycard_helper import (
    assert_status_account_matches_seed,
    read_keycard_details,
)
from helpers.aut_helper import launch_fresh_aut
from helpers.onboarding_helper import (
    open_create_profile_view,
    skip_post_login_popups_if_visible,
    wait_until_logged_in,
)
from scripts.utils.generators import keycard_card_id


@pytest.mark.keycard
@pytest.mark.timeout(400)
@allure.title('Onboarding — Login with this Keycard (existing card, no local profile)')
@allure.description(
    'Provision Keycard via create profile + import new keypair, then simulate a new device '
    '(fresh datadir). Log in → Use Keycard → PIN → KeycardDetailsPage → Login with this Keycard '
    '→ PIN → land in app with the same profile.'
)
def test_onboarding_login_with_this_keycard(keycard_simulator, main_window, aut: AUT):
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

    aut.stop()
    fresh_aut, main_window = launch_fresh_aut(keycard_simulator)
    keycard_simulator.create_card_with_seed(
        card_id, ' '.join(seed_words), DEFAULT_PIN, DEFAULT_PUK
    )
    keycard_simulator.plug_reader()
    keycard_simulator.select_card(card_id).insert_card()

    login_page = OnboardingWelcomeToStatusView().wait_until_appears().open_login_page()
    keycard_mng_popup = login_page.open_login_with_keycard()
    keycard_dtls_view = keycard_mng_popup.enter_keycard_pin(pin=DEFAULT_PIN)
    assert keycard_dtls_view.keycard_view_title.text == KEYCARD_STORES_KEY_PAIR_TITLE

    keycard_mng_popup = keycard_dtls_view.login_with_this_keycard()
    keycard_mng_popup.enter_keycard_pin_and_continue(pin=DEFAULT_PIN)
    wait_until_logged_in(main_window)
    skip_post_login_popups_if_visible()

    assert_status_account_matches_seed(main_window, seed_words)
    read_keycard_details(main_window, DEFAULT_PIN, KEYCARD_PROFILE_DETAILS_TITLE)
    fresh_aut.stop()
