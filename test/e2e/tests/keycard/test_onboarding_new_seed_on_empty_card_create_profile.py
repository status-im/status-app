import allure
import pytest

from constants import DEFAULT_PIN, KEYCARD_EMPTY_TITLE
from helpers.onboarding_helper import (
    open_create_profile_view,
    wait_until_logged_in,
    skip_biometrics_popup_if_visible,
    skip_education_popup_if_visible,
)
from scripts.utils.generators import keycard_card_id


@pytest.mark.keycard
@pytest.mark.timeout(300)
@allure.title('Onboarding — create profile with new key pair on empty Keycard')
@allure.description(
    'Empty card → Create profile → Use Keycard → PIN → Import new key pair → '
    'Reveal and confirm seed → Continue on success → land in app → Keycard settings → '
    'Read Keycard → PIN → Keycard stores Status profile key pair with On Keycard label'
)
def test_onboarding_empty_keycard_log_in(keycard_simulator, main_window):
    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id)
    keycard_simulator.plug_reader()
    keycard_mng_popup = open_create_profile_view().open_create_profile_with_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_dtls_view = keycard_mng_popup.enter_keycard_pin(pin=DEFAULT_PIN)
    assert keycard_dtls_view.keycard_view_title.text == KEYCARD_EMPTY_TITLE

    keycard_mng_popup = keycard_dtls_view.import_a_new_keypair()
    keycard_mng_popup.enter_new_pin_and_confirm(pin=DEFAULT_PIN)
    keycard_mng_popup.back_up_seed_phrase_and_confirm()
    keycard_mng_popup.continue_after_key_pair_imported()
    wait_until_logged_in(main_window)
    skip_biometrics_popup_if_visible()
    skip_education_popup_if_visible()

    keycard_settings = main_window.left_panel.open_settings().left_panel.open_keycard_settings()
    assert keycard_settings.is_read_keycard_button_visible
    keycard_settings.open_read_keycard().enter_keycard_pin_and_close(DEFAULT_PIN)
    keycard_settings.wait_until_details_appears()
