import allure

from gui.components.onboarding.language_selector import LanguageSelector
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.text_label import TextLabel
from gui.objects_map import settings_names


class LanguageSettingsView(QObject):

    def __init__(self):
        super().__init__(settings_names.languageView)
        self.language_selector = TextLabel(settings_names.languageViewLanguageSelector)
        self._confirm_language_change_button = Button(settings_names.languageViewLanguageChangeConfirmButton)
        self.spell_check_enabled = CheckBox(settings_names.languageViewSpellCheckEnabled)

    @allure.step('Set spell check to {1}')
    def set_spell_check(self, value: bool):
        self.spell_check_enabled.set(value)

    @allure.step('Select language')
    def select_language(self, language_code: str):
        self.language_selector.click()
        LanguageSelector().wait_until_appears().select_language(language_code)

    @allure.step('Confirm language change (logs out and back in)')
    def confirm_language_change(self):
        self._confirm_language_change_button.click()
