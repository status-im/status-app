import allure

import configs
from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from gui.components.education_popup import EducationPopup

from gui.components.splash_screen import SplashScreen
from gui.screens.onboarding import OnboardingWelcomeToStatusView


def open_create_profile_view():
    return OnboardingWelcomeToStatusView().wait_until_appears().open_create_your_profile_view()


def import_seed_and_log_in(create_your_profile_view, seed_phrase, user_account):
    seed_view = create_your_profile_view.open_seed_phrase_view()
    seed_view.fill_in_seed_phrase_grid(seed_phrase.split(), autocomplete=False)
    create_password_view = seed_view.continue_import()
    create_password_view.create_password(user_account.password)
    splash_screen = SplashScreen().wait_until_appears()
    splash_screen.wait_until_hidden(APP_LOAD_TIMEOUT_MSEC)

@allure.step('Skip Education popup if visible')
def skip_education_popup_if_visible(attempts = 4):
    education_popup = EducationPopup()
    if not education_popup.is_visible:
        return

    for attempt in range(1, attempts + 1):
        try:
            education_popup.skip()
            return
        except Exception as e:
            if attempt < attempts:
                continue
            else:
                raise Exception(f"Failed to close education popup after {attempts} attempts: {e}")

