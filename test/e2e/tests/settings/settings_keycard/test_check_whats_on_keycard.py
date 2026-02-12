import time

import allure
import pytest
from allure import step

import configs
import driver
from constants.images_paths import PLUG_IN_KEYCARD_IMAGE_PATH, INSERT_KEYCARD_IMAGE_PATH, EMPTY_KEYCARD_IMAGE_PATH, \
    KEYCARD_SUCCESS_IMAGE_PATH, KEYCARD_INSERTED_IMAGE_PATH, KEYCARD_PIN_SUCCESS_IMAGE_PATH
from constants.keycard import Keycard
from gui.main_window import MainWindow
from gui.mocked_keycard_controller import MockedKeycardController


@pytest.mark.case(703627)
@pytest.mark.keycard
def test_check_whats_on_keycard(main_screen: MainWindow, user_account):
    main_screen.prepare()
    timeout = configs.timeouts.UI_LOAD_TIMEOUT_MSEC
    pin = Keycard.KEYCARD_PIN.value
    keycard_name = 'Card-1 Name'

    with step('Choose option Check whats on keycard in settings'):
        keycard_settings = main_screen.left_panel.open_settings().left_panel.open_keycard_settings()
        keycard_popup = keycard_settings.click_check_whats_on_keycard()

    with step('Verify displayed keycard popup instructions and welcome image source path are correct'):
        actual_instructions = keycard_popup.keycard_instructions
        actual_image_path = keycard_popup.keycard_image_source_path
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

    with step('Register and insert not status keycard'):
        keycard_controller.choose_not_status_keycard().register_keycard().insert_keycard_1()
        main_screen.show()

    with step('Verify keycard is not recognized'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_NOT.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert driver.waitFor(lambda: Keycard.KEYCARD_NOT_RECOGNIZED_NOTE.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

    with step('Close keycard popup'):
        keycard_popup.cancel()

    with step('Insert empty keycard'):
        keycard_controller.choose_empty_keycard().register_keycard().insert_keycard_1()
        main_screen.show()

    with step('Verify keycard is empty and image source path is correct'):
        keycard_popup = keycard_settings.click_check_whats_on_keycard()
        assert driver.waitFor(lambda: Keycard.KEYCARD_EMPTY.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert driver.waitFor(lambda: Keycard.KEYCARD_NO_KEYPAIR.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        actual_image_path = keycard_popup.keycard_image_source_path
        assert EMPTY_KEYCARD_IMAGE_PATH == actual_image_path, f"Image path {actual_image_path} is wrong"

    with step('Close keycard popup'):
        keycard_popup.click_next()

    with step('Insert locked keycard'):
        keycard_controller.choose_max_slots_reached_keycard().register_keycard().insert_keycard_1()
        main_screen.show()

    with step('Verify keycard is locked'):
        keycard_popup = keycard_settings.click_check_whats_on_keycard()
        assert driver.waitFor(lambda: Keycard.KEYCARD_LOCKED.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert driver.waitFor(lambda: Keycard.KEYCARD_LOCKED_NOTE.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

    with step('Close keycard popup'):
        keycard_popup.cancel()

    with (step('Remove keycard and insert keycard with accounts on it')):
        keycard_controller.remove_keycard()
        keycard_controller.choose_mnemonic_metadata_keycard().register_keycard().insert_keycard_1()
        main_screen.show()

    with step('Enter PIN and repeat PIN and verify keycard popup instructions and image source path are correct'):
        keycard_popup = keycard_settings.click_check_whats_on_keycard()
        assert driver.waitFor(lambda: Keycard.KEYCARD_ENTER_PIN.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        keycard_popup.input_pin_or_puk(pin)
        assert driver.waitFor(lambda: Keycard.KEYCARD_PIN_VERIFIED.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

        time.sleep(2)
        actual_image_path = keycard_popup.keycard_image_source_path
        assert KEYCARD_PIN_SUCCESS_IMAGE_PATH == actual_image_path, f"Image path {actual_image_path} is wrong"

    with step('Click next and verify keycard image source path is correct'):
        keycard_popup.click_next()
        actual_image_path = keycard_popup.keycard_image_source_path
        assert KEYCARD_INSERTED_IMAGE_PATH == actual_image_path, f"Image path {actual_image_path} is wrong"

    with step('Verify that preview shows correct keycard and instructions are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_ACCOUNTS.value in keycard_popup.keycard_instructions, timeout), \
            "There is no correct keycard instruction"
        keypair_on_keycard = keycard_popup.keypair_on_keycard_name
        assert keypair_on_keycard == keycard_name, f"Keycard name in preview {keypair_on_keycard} is incorrect"
