import allure
import pytest

from constants import (
    DEFAULT_PIN,
    DEFAULT_PUK,
    KEYCARD_APPLET_4_0_1,
    KEYCARD_NOT_VERIFIED_SNIPPET,
    KEYCARD_NOT_VERIFIED_TITLE,
)
from driver.aut import AUT
from gui.screens.onboarding import KeycardLoginView
from helpers.keycard_helper import (
    create_keycard_profile_from_seed,
    open_keycard_settings_for_password_profile,
)
from scripts.utils.generators import keycard_card_id, random_mnemonic


pytestmark = [
    pytest.mark.keycard,
    pytest.mark.spec('SC-APLT-17'),
]


@pytest.mark.timeout(180)
@pytest.mark.parametrize('keycard_simulator', [KEYCARD_APPLET_4_0_1], indirect=True)
@allure.title('Settings — counterfeit Keycard is refused after PIN')
@allure.description(
    'Applet 4.0.1: seed on card → counterfeit in simulator → Settings → Read Keycard → '
    'enter PIN → must show "Keycard not verified" (PIN must not complete the read flow). '
    'Skip-PIN path: same outcome; login UI covered by e2e login test and tst_LoginKeycardBox.'
)
def test_counterfeit_keycard_is_refused_in_settings(
        keycard_simulator, main_window, user_account,
):
    card_id = keycard_card_id()
    keycard_simulator.create_card_with_seed(card_id, random_mnemonic(), DEFAULT_PIN, DEFAULT_PUK)
    keycard_simulator.make_counterfeit(card_id)
    keycard_simulator.plug_reader()

    keycard_settings = open_keycard_settings_for_password_profile(main_window, user_account)
    keycard_mng_popup = keycard_settings.open_read_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_mng_popup.enter_pin(DEFAULT_PIN)
    keycard_mng_popup.wait_until_progress_title(KEYCARD_NOT_VERIFIED_TITLE)
    assert KEYCARD_NOT_VERIFIED_SNIPPET in keycard_mng_popup.progress_message


@pytest.mark.timeout(300)
@pytest.mark.parametrize('keycard_simulator', [KEYCARD_APPLET_4_0_1], indirect=True)
@allure.title('Login — counterfeit Keycard refused after PIN entry')
@allure.description(
    'Keycard profile on 4.0.1 → restart → provision card → insert at login → '
    'remove in simulator → select → Make counterfeit (only when not inserted) → '
    'insert again → enter PIN → login shows not verified (PIN cleared)'
)
def test_counterfeit_keycard_login_hides_pin(keycard_simulator, main_window, aut: AUT):
    seed_phrase = random_mnemonic()
    card_id = create_keycard_profile_from_seed(keycard_simulator, main_window, seed_phrase)

    aut.restart()
    main_window.prepare()
    KeycardLoginView().wait_until_appears()

    keycard_simulator.wait_until_appears().start_simulator()
    keycard_simulator.create_card_with_seed(
        card_id, seed_phrase, DEFAULT_PIN, DEFAULT_PUK,
    )
    keycard_simulator.plug_reader()
    keycard_simulator.insert_card()
    keycard_simulator.remove_card()
    keycard_simulator.select_card(card_id)
    keycard_simulator.make_counterfeit(card_id)
    keycard_simulator.insert_card()

    login_view = KeycardLoginView()
    login_view.log_in_with_pin(DEFAULT_PIN)
    login_view.wait_until_untrusted_keycard_no_pin()
    assert KEYCARD_NOT_VERIFIED_SNIPPET in login_view.info_text