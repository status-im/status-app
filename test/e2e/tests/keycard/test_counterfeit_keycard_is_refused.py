import allure
import pytest

from constants import (
    DEFAULT_PIN,
    DEFAULT_PUK,
    KEYCARD_APPLET_4_0_1,
    KEYCARD_NOT_VERIFIED_MESSAGE,
    KEYCARD_NOT_VERIFIED_TITLE,
)
from helpers.keycard_helper import open_keycard_settings_for_password_profile
from scripts.utils.generators import keycard_card_id, random_mnemonic


@pytest.mark.keycard
@pytest.mark.timeout(180)
@pytest.mark.parametrize('keycard_simulator', [KEYCARD_APPLET_4_0_1], indirect=True)
@allure.title('Settings — counterfeit Keycard is refused')
@allure.description(
    'Applet 4.0.1 card with a seed, then marked counterfeit → Settings → Read Keycard → '
    'popup says "Keycard not verified" and the read flow does not finish'
)
def test_counterfeit_keycard_is_refused(keycard_simulator, main_window, user_account):
    card_id = keycard_card_id()
    keycard_simulator.create_card_with_seed(card_id, random_mnemonic(), DEFAULT_PIN, DEFAULT_PUK)
    keycard_simulator.make_counterfeit(card_id)
    keycard_simulator.plug_reader()

    keycard_settings = open_keycard_settings_for_password_profile(main_window, user_account)
    keycard_mng_popup = keycard_settings.open_read_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_mng_popup.wait_until_progress_title(KEYCARD_NOT_VERIFIED_TITLE)
    assert KEYCARD_NOT_VERIFIED_MESSAGE in keycard_mng_popup.progress_message
    assert not keycard_mng_popup.pin_input.is_visible
    assert keycard_mng_popup.is_visible
