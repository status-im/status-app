import typing

import allure

import configs
import driver
from gui.components.confirm_recovery_phrase import ConfirmRecoveryPhrase
from gui.elements.button import Button
from gui.elements.object import QObject, set_text_property_on_object
from gui.elements.scroll import Scroll
from gui.elements.text_edit import TextEdit
from gui.elements.text_label import TextLabel
from gui.objects_map import keycard_names, onboarding_names


class KeycardManagementPopup(QObject):

    def __init__(self):
        super().__init__(keycard_names.keycardManagementPopup)
        self.pin_input = QObject(keycard_names.keycardManagementPinInput)
        self.reveal_recovery_phrase_button = Button(keycard_names.keycardManagementRevealSeedPhraseButton)
        self.next_button = Button(keycard_names.keycardManagementNextButton)
        self.continue_button = Button(keycard_names.keycardManagementContinueButton)
        self.seed_phrase_word = QObject(keycard_names.keycardManagementSeedPhraseWord)
        self.seed_phrase_switch_bar = QObject(keycard_names.keycardManagementSeedPhraseSwitchBar)
        self.tab_12_words_button = Button(keycard_names.keycardManagementSeedPhrase12Button)
        self.tab_18_words_button = Button(keycard_names.keycardManagementSeedPhrase18Button)
        self.tab_24_words_button = Button(keycard_names.keycardManagementSeedPhrase24Button)
        self.seed_phrase_input = TextEdit(keycard_names.keycardManagementSeedPhraseInputField)
        self._seed_phrase_scroll = Scroll(keycard_names.keycardManagementSeedPhraseScrollView)
        self.unknown_pin_button = Button(keycard_names.keycardManagementUnknownPinButton)
        self.done_button = Button(keycard_names.keycardManagementDoneButton)
        self.key_pair_name_input = QObject(keycard_names.keycardKeyPairNameInput)
        self.account_name_input = QObject(keycard_names.keycardManageAccountNameInput)

    @allure.step('Enter Keycard PIN {pin}')
    def enter_keycard_pin(self, pin: str, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.pin_input.wait_until_appears(timeout_msec)
        self.pin_input.object.setPin(pin)
        return KeycardDetailsView().wait_until_appears()

    @allure.step('Enter Keycard PIN {pin} and wait until popup closes')
    def enter_keycard_pin_and_close(self, pin: str, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.pin_input.wait_until_appears(timeout_msec)
        self.pin_input.object.setPin(pin)
        self.wait_until_hidden(timeout_msec)
        return self

    @allure.step('Skip PIN and wait until popup closes')
    def skip_pin_and_close(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.unknown_pin_button.wait_until_appears(timeout_msec)
        self.unknown_pin_button.click()
        self.wait_until_hidden(timeout_msec)
        return self

    @allure.step('Enter new PIN {pin}')
    def enter_new_pin_and_confirm(self, pin: str, expect_reveal_seed: bool = True):
        self.pin_input.wait_until_appears()
        self.pin_input.object.setPin(pin)
        self.pin_input.object.setPin(pin)
        if expect_reveal_seed:
            assert self.reveal_recovery_phrase_button.is_visible
        else:
            self.seed_phrase_switch_bar.wait_until_appears()
        return self

    @allure.step('Reveal recovery phrase')
    def reveal_recovery_phrase(self):
        self.reveal_recovery_phrase_button.click()
        return self

    @allure.step('Write down recovery phrase')
    def write_down_recovery_phrase(self):
        words = []
        for word_n in range(1, 13):
            self.seed_phrase_word.real_name['objectName'] = 'SeedPhraseWordAtIndex-' + str(word_n)
            words.append(str(self.seed_phrase_word.object.textEdit.input.edit.text))
        return words

    @allure.step('Open confirm recovery phrase')
    def open_confirm_recovery_phrase(self) -> ConfirmRecoveryPhrase:
        self.next_button.click()
        return ConfirmRecoveryPhrase(
            continue_button_real_name=keycard_names.keycardManagementNextButton,
        )

    @allure.step('Back up recovery seed phrase and confirm')
    def back_up_seed_phrase_and_confirm(self):
        self.reveal_recovery_phrase()
        words = self.write_down_recovery_phrase()
        self.open_confirm_recovery_phrase().fill_the_grid_and_continue(words)
        return self

    @allure.step('Enter recovery phrase')
    def enter_recovery_phrase(self, seed_phrase_words: typing.List[str]):
        self.seed_phrase_switch_bar.wait_until_appears()
        if len(seed_phrase_words) == 12:
            if not self.tab_12_words_button.is_checked:
                self.tab_12_words_button.click()
        elif len(seed_phrase_words) == 18:
            if not self.tab_18_words_button.is_checked:
                self.tab_18_words_button.click()
        elif len(seed_phrase_words) == 24:
            if not self.tab_24_words_button.is_checked:
                self.tab_24_words_button.click()
        else:
            raise RuntimeError('Wrong amount of seed words', len(seed_phrase_words))

        for index, word in enumerate(seed_phrase_words, start=1):
            self.seed_phrase_input.real_name = dict(
                keycard_names.keycardManagementSeedPhraseInputField)
            self.seed_phrase_input.real_name['objectName'] = f'enterSeedPhraseInputField{index}'
            try:
                self._seed_phrase_scroll.vertical_scroll_down(self.seed_phrase_input)
            except LookupError:
                pass
            field = driver.waitForObjectExists(
                self.seed_phrase_input.real_name, configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
            set_text_property_on_object(field, word)
            field.focus = False

        assert driver.waitFor(
            lambda: getattr(
                driver.waitForObjectExists(self.next_button.real_name, 200),
                'enabled', False),
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Next did not enable after entering the recovery phrase'
        self.next_button.click()
        return self

    def _fill_and_next(self, field: QObject, name: str):
        field.wait_until_appears()
        field.set_text_property(name)
        self.next_button.click()
        return self

    @allure.step('Enter key pair name {name}')
    def enter_key_pair_name(self, name: str):
        return self._fill_and_next(self.key_pair_name_input, name)

    @allure.step('Enter account name {name}')
    def enter_account_name(self, name: str):
        return self._fill_and_next(self.account_name_input, name)

    @allure.step('Close popup after successful import')
    def close_after_success(self, timeout_msec: int):
        self.done_button.wait_until_appears(timeout_msec)
        self.done_button.click()
        self.wait_until_hidden(timeout_msec)
        return self

    @allure.step('Continue after key pair imported to Keycard')
    def continue_after_key_pair_imported(self, timeout_msec: int = None):
        if timeout_msec is None:
            timeout_msec = configs.timeouts.APP_LOAD_TIMEOUT_MSEC
        self.continue_button.wait_until_appears(timeout_msec)
        self.continue_button.click()
        return self


class KeycardDetailsView(QObject):
    def __init__(self):
        super().__init__(onboarding_names.mainWindow_keycardDetailsPage)

        self.keycard_view_title = TextLabel(onboarding_names.keycardDetailsTitle)
        self.keycard_view_import_new_keypair = Button(onboarding_names.onboardingKeycardDetailsImportNewKeypair)
        self.keycard_view_import_seed_phrase = Button(onboarding_names.onboardingKeycardDetailsImportSeedPhrase)

    @allure.step('Import a new keypair to Keycard and create new profile')
    def import_a_new_keypair(self):
        self.keycard_view_import_new_keypair.click()
        return KeycardManagementPopup().wait_until_appears()

    @allure.step('Import a key pair from recovery phrase')
    def import_from_recovery_phrase(self):
        self.keycard_view_import_seed_phrase.click()
        return KeycardManagementPopup().wait_until_appears()
