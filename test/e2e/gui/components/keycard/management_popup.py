import time
import typing

import allure

import configs
from gui.components.confirm_recovery_phrase import ConfirmRecoveryPhrase
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import keycard_names
from gui.screens.keycard_details_view import KeycardDetailsView


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

    @allure.step('Enter new PIN {pin}')
    def enter_new_pin_and_confirm(self, pin: str, expect_reveal_seed: bool = True):
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
            self.seed_phrase_input.real_name['objectName'] = f'enterSeedPhraseInputField{index}'
            self.seed_phrase_input.text = word
            time.sleep(0.2)

        self.next_button.click()
        return self

    @allure.step('Continue after key pair imported to Keycard')
    def continue_after_key_pair_imported(self, timeout_msec: int = None):
        if timeout_msec is None:
            timeout_msec = configs.timeouts.APP_LOAD_TIMEOUT_MSEC
        self.continue_button.wait_until_appears(timeout_msec)
        self.continue_button.click()
        return self
