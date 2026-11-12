import allure
import pytest

from constants import KEYCARD_APPLET_4_0_1, KEYCARD_EMPTY_TITLE, KEYCARD_NOT_CERTIFIED_SNIPPET
from helpers.keycard_helper import open_keycard_settings_for_password_profile
from scripts.utils.generators import keycard_card_id


@pytest.mark.keycard
@pytest.mark.timeout(180)
@pytest.mark.parametrize('keycard_simulator', [KEYCARD_APPLET_4_0_1], indirect=True)
@allure.title('Settings — uncertified Keycard can be read and shows a warning')
@allure.description(
    'Applet 4.0.1 empty card whose identity certificate no trusted CA signed → '
    'Settings → Read Keycard → details stay "Keycard is empty" and show the not-certified warning'
)
def test_uncertified_keycard_can_be_read_and_shows_warning(keycard_simulator, main_window, user_account):
    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id, untrusted_ca=True)
    keycard_simulator.plug_reader()

    keycard_settings = open_keycard_settings_for_password_profile(main_window, user_account)
    keycard_mng_popup = keycard_settings.open_read_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_mng_popup.skip_pin_and_close()
    keycard_settings.wait_until_details_appears(KEYCARD_EMPTY_TITLE)
    assert not keycard_settings.pairing_supported
    assert KEYCARD_NOT_CERTIFIED_SNIPPET in keycard_settings.certificate_warning_text
