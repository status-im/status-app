import allure
import pytest
from allure_commons._allure import step


import configs
import driver
from constants.images_paths import KEYCARD_ERROR_IMAGE_PATH
from constants.keycard import Keycard
from gui.main_window import MainWindow
from gui.mocked_keycard_controller import MockedKeycardController


pytestmark = pytest.mark.skip(reason="skipped due to migration to status-keycard-qt, need to rewrite tests against the new lib and approach")

@pytest.mark.case(703628)
@pytest.mark.keycard
def test_factory_reset_keycard(main_screen: MainWindow, user_account):
    main_screen.prepare()
    timeout = configs.timeouts.UI_LOAD_TIMEOUT_MSEC
    pin = Keycard.KEYCARD_PIN.value
    keycard_name = 'Card-1 Name'

    with step('Choose option Factory reset a keycard in keycard settings'):
        keycard_settings = main_screen.left_panel.open_settings().left_panel.open_keycard_settings()
        keycard_popup = keycard_settings.click_factory_reset_keycard()

    with step('Insert keycard with accounts on it'):
        keycard_controller = MockedKeycardController().wait_until_appears()
        keycard_controller.plugin_reader().choose_mnemonic_metadata_keycard().register_keycard().insert_keycard_1()
        main_screen.show()

    with step('Enter PIN and verify keycard popup instructions are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_ENTER_PIN.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        keycard_popup.input_pin_or_puk(pin)
        assert driver.waitFor(lambda: Keycard.KEYCARD_PIN_VERIFIED.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

    with step('Close keycard popup'):
        keycard_popup.click_next()

    with step('Verify that preview shows correct keycard and instructions are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_ACCOUNTS.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        actual_keycard_name = keycard_popup.keypair_on_keycard_name
        assert actual_keycard_name == keycard_name, f"Keycard name {actual_keycard_name} in preview is incorrect"
        keycard_popup.click_next()

    with step('Verify keycard factory reset title'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_FACTORY_RESET_TITLE.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

    with step('Confirm that keypair will be deleted in checkbox'):
        keycard_popup.confirm_keypair_will_be_deleted(True)
        keycard_popup.click_next()

    with step('Verify keycard factory reset was successful'):
        assert driver.waitFor(
            lambda: Keycard.KEYCARD_FACTORY_RESET_SUCCESSFUL.value in keycard_popup.keycard_instructions,
            timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert driver.waitFor(lambda: Keycard.KEYCARD_YOU_CAN_USE_AS_EMPTY.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"


@pytest.mark.case(704606)
@pytest.mark.keycard
def test_factory_reset_keycard_incorrect_pin(main_screen: MainWindow, user_account):
    main_screen.prepare()
    incorrect_pin = Keycard.KEYCARD_INCORRECT_PIN.value
    timeout = configs.timeouts.UI_LOAD_TIMEOUT_MSEC

    with step('Choose option Factory reset a keycard in keycard settings'):
        keycard_settings = main_screen.left_panel.open_settings().left_panel.open_keycard_settings()
        keycard_popup = keycard_settings.click_factory_reset_keycard()

    with step('Insert keycard with accounts on it'):
        keycard_controller = MockedKeycardController().wait_until_appears()
        keycard_controller.plugin_reader().choose_mnemonic_metadata_keycard().register_keycard().insert_keycard_1()
        main_screen.show()

    with step('Enter incorrect PIN and verify keycard popup instructions are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_ENTER_PIN.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        keycard_popup.input_pin_or_puk(incorrect_pin)
        assert driver.waitFor(
            lambda: Keycard.KEYCARD_INCORRECT_PIN_MESSAGE.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert driver.waitFor(
            lambda: Keycard.KEYCARD_2_ATTEMPTS_REMAINING.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert KEYCARD_ERROR_IMAGE_PATH == keycard_popup.keycard_image_source_path

    with step('Enter incorrect PIN again and verify keycard popup instructions are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_ENTER_PIN_2.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        keycard_popup.input_pin_or_puk(incorrect_pin)

        assert driver.waitFor(
            lambda: Keycard.KEYCARD_INCORRECT_PIN_MESSAGE.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert driver.waitFor(
            lambda: Keycard.KEYCARD_1_ATTEMPT_REMAINING.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert KEYCARD_ERROR_IMAGE_PATH == keycard_popup.keycard_image_source_path

    with step('Enter incorrect PIN again and verify keycard popup instructions are correct'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_ENTER_PIN_2.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        keycard_popup.input_pin_or_puk(incorrect_pin)
        assert driver.waitFor(
            lambda: Keycard.KEYCARD_LOCKED.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert driver.waitFor(
            lambda: Keycard.KEYCARD_LOCKED_INCORRECT_PIN.value in keycard_popup.keycard_instructions), \
            f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

    with step('Close keycard popup'):
        keycard_popup.cancel()

    with step('Choose option Factory reset a keycard'):
        keycard_popup = keycard_settings.click_factory_reset_keycard()

    with step('Verify keycard factory reset title'):
        assert driver.waitFor(lambda: Keycard.KEYCARD_FACTORY_RESET_TITLE.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"

    with step('Confirm that keypair will be deleted in checkbox'):
        keycard_popup.confirm_keypair_will_be_deleted(True)
        keycard_popup.click_next()

    with step('Verify keycard factory successful'):
        assert driver.waitFor(
            lambda: Keycard.KEYCARD_FACTORY_RESET_SUCCESSFUL.value in keycard_popup.keycard_instructions,
            timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
        assert driver.waitFor(lambda: Keycard.KEYCARD_YOU_CAN_USE_AS_EMPTY.value in keycard_popup.keycard_instructions,
                              timeout), f"There is no correct keycard instruction in {keycard_popup.keycard_instructions}"
