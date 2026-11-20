import random

import pytest
from allure_commons._allure import step

from constants.onboarding import LanguageCodes
from driver.aut import AUT
from gui.main_window import MainWindow
from gui.screens.onboarding import ReturningLoginView
from helpers.onboarding_helper import wait_until_login_screen, wait_until_logged_in


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

    with step('Log in again in the same process'):
        wait_until_login_screen()
        ReturningLoginView().log_in_with_password(user_account.password)
        wait_until_logged_in(main_screen)

    with step(f'Language is {new_language} after logging in again'):
        language_settings = main_screen.left_panel.open_settings().left_panel.open_language_settings()
        assert language_settings.language_selector.text == new_language, \
            'Language was not applied after logging in again'

    with step('Restart application'):
        aut.restart()
        main_screen.prepare()
        wait_until_login_screen()
        ReturningLoginView().log_in_with_password(user_account.password)
        wait_until_logged_in(main_screen)

    with step(f'Language is still {new_language}'):
        language_settings = main_screen.left_panel.open_settings().left_panel.open_language_settings()
        assert language_settings.language_selector.text == new_language, \
            'Language was not kept after restart'
