import time

import allure
import pytest
from allure import step

import configs
import driver
from constants.images_paths import PLUG_IN_KEYCARD_IMAGE_PATH, INSERT_KEYCARD_IMAGE_PATH, CHOOSE_KEYCARD_PIN_IMAGE_PATH
from constants.keycard import Keycard
from gui.main_window import MainWindow
from gui.mocked_keycard_controller import MockedKeycardController


pytestmark = pytest.mark.skip(reason="skipped due to migration to status-keycard-qt, need to rewrite tests against the new lib and approach")

@pytest.mark.case(703624)
@pytest.mark.keycard
@pytest.mark.parametrize(
    'name, color, emoji_name, emoji, name1, color1, emoji1_name, emoji1, name2, color2, emoji2_name, emoji2',
    [pytest.param('Test Account', '#216266', 'sunglasses', '😎 ', 'Test Account2', '#2a4af5',
                  'thumbsup', '👍 ', 'Test Account3', '#ff7d46', 'cool', '🆒 ')
     ])
def test_create_keycard_account_with_new_seed_phrase(main_screen: MainWindow, name, color, emoji_name, emoji, name1,
                                                     color1, emoji1_name, emoji1, name2, color2, emoji2_name, emoji2):
    timeout = configs.timeouts.UI_LOAD_TIMEOUT_MSEC
    pin = Keycard.KEYCARD_PIN.value
    keycard_name = Keycard.KEYCARD_NAME.value
    with step('Choose option Create a new Keycard account with a new seed phrase in settings'):
        main_screen.prepare()
        keycard_settings = main_screen.left_panel.open_settings().left_panel.open_keycard_settings()
        keycard_popup = keycard_settings.click_create_new_account_with_new_seed_phrase()

    with step('Verify displayed header, popup instructions and image source path are correct'):
        actual_instructions = keycard_popup.keycard_instructions
        actual_image_path = keycard_popup.keycard_image_source_path
        actual_header_title = keycard_popup.keycard_header
        assert actual_header_title == Keycard.KEYCARD_POPUP_HEADER_CREATE_SEED.value, f"The header {actual_header_title} is incorrect"
        assert Keycard.KEYCARD_INSTRUCTIONS_PLUG_IN.value in actual_instructions, f"There is no correct keycard instruction in {actual_instructions}"
        assert PLUG_IN_KEYCARD_IMAGE_PATH == actual_image_path, f"Image path {actual_image_path} is wrong"

    with step('Plug in reader'):
        keycard_controller = MockedKeycardController().wait_until_appears().plugin_reader()
        main_screen.show()

    with step('Verify displayed keycard popup instructions and image source path are correct'):
        assert driver.waitFor(
            lambda: Keycard.KEYCARD_INSTRUCTIONS_INSERT_KEYCARD.value in keycard_popup.keycard_instructions,
            timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        time.sleep(2)
        actual_image_path = keycard_popup.keycard_image_source_path
        assert INSERT_KEYCARD_IMAGE_PATH == actual_image_path, f"Image path {actual_image_path} is wrong"

    with step('Register and insert keycard'):
        keycard_controller.register_keycard().insert_keycard_1()
        main_screen.show()

    with step('Verify displayed keycard popup instructions and image are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_RECOGNIZED.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert driver.waitFor(lambda: Keycard.KEYCARD_CHOOSE_PIN.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert Keycard.KEYCARD_PIN_NOTE.value in keycard_popup.keycard_instructions
        actual_image_path = keycard_popup.keycard_image_source_path
        assert CHOOSE_KEYCARD_PIN_IMAGE_PATH == actual_image_path, f"Image path {actual_image_path} is wrong"

    with step('Enter and repeat PIN and verify keycard popup instructions are correct'):
        keycard_popup.input_pin_or_puk(pin)
        assert driver.waitFor(lambda: Keycard.KEYCARD_REPEAT_PIN.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        keycard_popup.input_pin_or_puk(pin)
        assert driver.waitFor(lambda: Keycard.KEYCARD_PIN_SET.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

    with step('Create keycard and first keycard account using new seed phrase'):
        keycard_popup.confirm_seed_phrase().name_keycard(keycard_name).name_account(name).set_color(color).set_emoji(
            emoji_name)

    with step('Verify keycard name and first account details on account tags are correct'):
        assert keycard_name == keycard_popup.keypair_name
        assert keycard_popup.account_tags[0].name == name
        assert keycard_popup.account_tags[0].icon_color == color
        assert keycard_popup.account_tags[0].icon_emoji == emoji

    with step('Add second keycard account and verify account details on account tags are correct'):
        keycard_popup.add_account().name_account(name1).set_emoji(emoji1_name).set_color(color1)
        assert keycard_popup.account_tags[1].name == name1
        assert keycard_popup.account_tags[1].icon_color == color1
        assert keycard_popup.account_tags[1].icon_emoji == emoji1

    with step('Add third keycard account and verify third account details on account tags are correct'):
        keycard_popup.add_account().name_account(name2).set_emoji(emoji2_name).set_color(color2)
        assert keycard_popup.account_tags[2].name == name2
        assert keycard_popup.account_tags[2].icon_color == color2
        assert keycard_popup.account_tags[2].icon_emoji == emoji2

    with step('Finalise keycard'):
        keycard_popup.click_next()

    with step('Verify that keycard instructions are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_NEW_ACCOUNT_CREATED.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

    with step('Go to wallet settings and verify accounts and account details are correct'):
        account_order = main_screen.left_panel.open_settings().left_panel.open_wallet_settings().open_account_order()
        with step('First account details are correct'):
            assert account_order.accounts[1].name == name
            assert account_order.accounts[1].icon_color == color
            assert account_order.accounts[1].icon_emoji == emoji
        with step('Second account details are correct'):
            assert account_order.accounts[2].name == name1
            assert account_order.accounts[2].icon_color == color1
            assert account_order.accounts[2].icon_emoji == emoji1
        with step('Third account details are correct'):
            assert account_order.accounts[3].name == name2
            assert account_order.accounts[3].icon_color == color2
            assert account_order.accounts[3].icon_emoji == emoji2
