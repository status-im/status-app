import allure

import configs
import driver
from configs.timeouts import APP_LOAD_TIMEOUT_MSEC, UI_LOAD_TIMEOUT_MSEC
from driver.aut import AUT
from gui.components.education_popup import EducationPopup
from gui.components.enable_biometrics_popup import EnableBiometricsPopup
from gui.components.splash_screen import SplashScreen
from gui.main_window import MainWindow
from gui.screens.onboarding import OnboardingWelcomeToStatusView, ReturningLoginView


def open_create_profile_view():
    return OnboardingWelcomeToStatusView().wait_until_appears().open_create_your_profile_view()


def open_create_password_view():
    return open_create_profile_view().open_password_view()


@allure.step('Wait until login screen is shown')
def wait_until_login_screen(timeout_msec: int = APP_LOAD_TIMEOUT_MSEC):
    ReturningLoginView().wait_until_appears(timeout_msec)


@allure.step('Wait until automatic login reaches the main window')
def wait_until_auto_logged_in(main_window: MainWindow, timeout_msec: int = APP_LOAD_TIMEOUT_MSEC):
    login = ReturningLoginView()
    assert driver.waitFor(
        lambda: main_window.left_panel.messages_button.is_visible and not login.is_visible,
        timeout_msec,
    ), 'Automatic login did not reach the main window'
    skip_post_login_popups_if_visible()


@allure.step('Sign out and quit from settings')
def sign_out_and_quit(main_window: MainWindow):
    skip_post_login_popups_if_visible()
    main_window.left_panel.open_settings().left_panel.open_sign_out_and_quit().sign_out_and_quit()


@allure.step('Wait until AUT has quit')
def wait_until_aut_quit(aut: AUT, timeout_msec: int = APP_LOAD_TIMEOUT_MSEC):
    assert aut.ctx is not None, 'AUT context is missing'
    assert driver.waitFor(lambda: not aut.ctx.isRunning, timeout_msec), \
        'Application did not quit after sign out'


@allure.step('Wait until user is logged in')
def wait_until_logged_in(main_window):
    SplashScreen().wait_until_appears().wait_until_hidden(APP_LOAD_TIMEOUT_MSEC)
    skip_post_login_popups_if_visible()
    main_window.left_panel.messages_button.wait_until_appears(APP_LOAD_TIMEOUT_MSEC)


def import_seed_and_log_in(create_your_profile_view, seed_phrase, user_account):
    seed_view = create_your_profile_view.open_seed_phrase_view()
    seed_view.fill_in_seed_phrase_grid(seed_phrase.split(), autocomplete=False)
    create_password_view = seed_view.continue_import()
    create_password_view.create_password(user_account.password)
    splash_screen = SplashScreen().wait_until_appears()
    splash_screen.wait_until_hidden(APP_LOAD_TIMEOUT_MSEC)


@allure.step('Skip Education popup if visible')
def skip_education_popup_if_visible(attempts=4):
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


@allure.step('Skip Enable biometrics popup if visible')
def skip_biometrics_popup_if_visible(timeout_msec: int = UI_LOAD_TIMEOUT_MSEC):
    if configs.system.get_platform() != 'Darwin':
        return
    try:
        EnableBiometricsPopup().skip(timeout_msec)
    except TimeoutError:
        return


@allure.step('Skip post-login popups if visible')
def skip_post_login_popups_if_visible():
    skip_biometrics_popup_if_visible()
    skip_education_popup_if_visible()
