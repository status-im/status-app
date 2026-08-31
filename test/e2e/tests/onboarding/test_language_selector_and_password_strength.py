import random

import pytest
from allure_commons._allure import step

from gui.screens.onboarding import OnboardingWelcomeToStatusView
from . import marks

from constants.onboarding import LanguageCodes

pytestmark = marks


@pytest.mark.case(702989)
def test_check_language_selector(main_window, user_account):

    with step('Verify user can change language on onboarding screen'):
        welcome_screen = OnboardingWelcomeToStatusView().wait_until_appears()
        assert welcome_screen.language_selector.object.text == LanguageCodes.ENGLISH.value, f'English should be default'

        selector = welcome_screen.open_language_selector()
        new_language = random.choice([LanguageCodes.KOREAN.value, LanguageCodes.CZECH.value])
        selector.select_language(new_language.lower())

        assert welcome_screen.create_profile_button.object.text != 'Create profile', f'Language was not changed'

        welcome_screen.open_language_selector().select_language(LanguageCodes.ENGLISH.value.lower())

        assert welcome_screen.language_selector.object.text == LanguageCodes.ENGLISH.value, f'Language was not changed'
