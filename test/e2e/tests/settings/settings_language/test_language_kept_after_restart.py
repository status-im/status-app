import random

import pytest
from allure_commons._allure import step

from constants.onboarding import LanguageCodes
from driver.aut import AUT
from gui.main_window import MainWindow

@pytest.mark.settings_language
@pytest.mark.settings_all
def test_language_kept_after_settings_restart(aut: AUT, main_screen: MainWindow, user_account):
    new_language = random.choice([LanguageCodes.KOREAN.value, LanguageCodes.CZECH.value])
    with step(f'Open language settings and select {new_language}'):
        language_settings = main_screen.left_panel.open_settings().left_panel.open_language_settings()
        assert language_settings.language_selector.text == LanguageCodes.ENGLISH.value, \
            'English should be the default language'
        language_settings.select_language(new_language.lower())
        language_settings.confirm_language_change()

    with step('Restart application'):
        aut.restart()
        main_screen.prepare()
        main_screen.authorize_user(user_account)

    with step(f'Language is still {new_language}'):
        language_settings = main_screen.left_panel.open_settings().left_panel.open_language_settings()
        assert language_settings.language_selector.text == new_language, \
            'Language was not kept after restart'
