import time

import allure
import pytest
from allure import step

import configs
import driver
from constants import ColorCodes
from constants.images_paths import PLUG_IN_KEYCARD_IMAGE_PATH, INSERT_KEYCARD_IMAGE_PATH, KEYCARD_SUCCESS_IMAGE_PATH
from constants.keycard import Keycard
from gui.main_window import MainWindow
from gui.mocked_keycard_controller import MockedKeycardController
from scripts.utils.generators import random_mnemonic


pytestmark = pytest.mark.skip(reason="skipped due to migration to status-keycard-qt, need to rewrite tests against the new lib and approach")

@pytest.mark.case(703625)
@pytest.mark.keycard
def test_import_restore_keycard_via_seed_phrase(main_screen: MainWindow):
    timeout = configs.timeouts.UI_LOAD_TIMEOUT_MSEC
    pin = Keycard.KEYCARD_PIN.value
    keycard_name = Keycard.KEYCARD_NAME.value
    account_name = Keycard.ACCOUNT_NAME.value

    with step('Choose option Import or restore account via seed phrase in settings'):
        main_screen.prepare()
        keycard_settings = main_screen.left_panel.open_settings().left_panel.open_keycard_settings()
        keycard_popup = keycard_settings.click_import_restore_via_seed_phrase()

    with step('Verify that header, instructions and image path are correct'):
        actual_keycard_header = keycard_popup.keycard_header
        actual_instructions = keycard_popup.keycard_instructions
        actual_image_path = keycard_popup.keycard_image_source_path
        assert actual_keycard_header == Keycard.KEYCARD_POPUP_HEADER_IMPORT_SEED.value, f"The header is incorrect {actual_keycard_header}"
        assert Keycard.KEYCARD_INSTRUCTIONS_PLUG_IN.value in actual_instructions, f"There is no correct keycard instruction in {actual_instructions}"
        assert PLUG_IN_KEYCARD_IMAGE_PATH == actual_image_path

    with step('Plug in reader'):
        keycard_controller = MockedKeycardController().wait_until_appears(10000)
        keycard_controller.plugin_reader()
        main_screen.show()

    with step('Verify displayed keycard popup instructions and image path are correct'):
        assert driver.waitFor(
            lambda: Keycard.KEYCARD_INSTRUCTIONS_INSERT_KEYCARD.value in keycard_popup.keycard_instructions,
            timeout), "There is no correct keycard instruction"
        time.sleep(2)
        assert INSERT_KEYCARD_IMAGE_PATH == keycard_popup.keycard_image_source_path

    with step('Register and insert keycard'):
        keycard_controller.register_keycard().insert_keycard_1()
        main_screen.show()

    with step('Verify displayed keycard popup instructions are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_RECOGNIZED.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

    with step('Import keycard via seed phrase'):
        keycard_popup.import_keycard_via_seed_phrase(random_mnemonic().split(), pin, keycard_name, account_name)

    with step('Verify that preview shows correct keycard and account name and color and instructions are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_READY.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

        assert keycard_popup.keypair_name == keycard_name, "Keycard name in preview is incorrect"
        assert keycard_popup.keypair_account_name == account_name, "Account name in preview is incorrect"
        assert keycard_popup.keypair_account_color == ColorCodes.BLUE.value, "Color in preview is incorrect"

    with step('Keycard image source path is correct'):
        time.sleep(2)
        assert KEYCARD_SUCCESS_IMAGE_PATH == keycard_popup.keycard_image_source_path
