import allure
import pytest

from constants import (
    DEFAULT_PIN,
    DEFAULT_PUK,
    KEYCARD_APPLET_3_2,
    KEYCARD_APPLET_4_0_1,
    KEYCARD_EMPTY_TITLE,
    KEYCARD_NOT_CERTIFIED_SNIPPET,
    KEYCARD_STORES_KEY_PAIR_TITLE,
)
from helpers.keycard_helper import open_keycard_settings_for_password_profile
from scripts.utils.generators import keycard_card_id, random_mnemonic


pytestmark = [
    pytest.mark.keycard,
]


@pytest.mark.timeout(180)
@pytest.mark.parametrize(
    'keycard_simulator, expect_warning',
    [
        pytest.param(
            KEYCARD_APPLET_4_0_1, True,
            marks=[pytest.mark.spec('SC-APLT-15')],
            id='applet-4.0.1-empty',
        ),
        pytest.param(
            KEYCARD_APPLET_3_2, False,
            marks=[pytest.mark.spec('SC-APLT-16')],
            id='applet-3.2-empty',
        ),
    ],
    indirect=['keycard_simulator'],
)
@allure.title('Settings — empty Keycard certificate warning by applet version')
@allure.description(
    'Empty card with untrusted CA: 4.0.1 shows the not-certified warning; 3.2 shows no warning'
)
def test_uncertified_empty_keycard_certificate_warning(
        keycard_simulator, main_window, user_account, expect_warning: bool,
):
    card_id = keycard_card_id()
    keycard_simulator.create_empty_card(card_id=card_id, untrusted_ca=True)
    keycard_simulator.plug_reader()

    keycard_settings = open_keycard_settings_for_password_profile(main_window, user_account)
    keycard_mng_popup = keycard_settings.open_read_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_mng_popup.skip_pin_and_close()
    keycard_settings.wait_until_details_appears(KEYCARD_EMPTY_TITLE)

    if keycard_simulator.applet_40:
        assert not keycard_settings.pairing_supported
    if expect_warning:
        assert KEYCARD_NOT_CERTIFIED_SNIPPET in keycard_settings.certificate_warning_text
    else:
        keycard_settings.wait_until_certificate_warning_hidden()


@pytest.mark.timeout(180)
@pytest.mark.spec('SC-APLT-15')
@pytest.mark.parametrize('keycard_simulator', [KEYCARD_APPLET_3_2], indirect=True)
@allure.title('Settings — applet 3.2 key pair on uncertified card shows warning')
@allure.description(
    '3.2 card with a key pair and untrusted CA → Read Keycard → not-certified warning is shown'
)
def test_uncertified_keypair_on_32_shows_warning(keycard_simulator, main_window, user_account):
    card_id = keycard_card_id()
    keycard_simulator.create_card_with_seed(
        card_id, random_mnemonic(), DEFAULT_PIN, DEFAULT_PUK, untrusted_ca=True,
    )
    keycard_simulator.plug_reader()

    keycard_settings = open_keycard_settings_for_password_profile(main_window, user_account)
    keycard_mng_popup = keycard_settings.open_read_keycard()
    keycard_simulator.select_card(card_id).insert_card()
    keycard_mng_popup.skip_pin_and_close()
    keycard_settings.wait_until_details_appears(
        KEYCARD_STORES_KEY_PAIR_TITLE,
        wait_for_key_pair_item=False,
    )
    assert KEYCARD_NOT_CERTIFIED_SNIPPET in keycard_settings.certificate_warning_text