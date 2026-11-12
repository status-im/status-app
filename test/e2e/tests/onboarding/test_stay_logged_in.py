from allure_commons._allure import step

from gui.screens.onboarding import ReturningLoginView
from helpers.onboarding_helper import (
    open_create_password_view,
    sign_out_and_quit,
    wait_until_aut_quit,
    wait_until_auto_logged_in,
    wait_until_logged_in,
    wait_until_login_screen,
)

from . import marks

pytestmark = marks


def test_stay_logged_in_opt_in_survives_sign_out(main_window_without_test_mode, user_account):
    aut, main_window = main_window_without_test_mode

    with step('Create a profile with save password left on'):
        password_view = open_create_password_view()
        password_view.stay_logged_in_switch.wait_until_appears()
        assert password_view.stay_logged_in_switch.is_checked, 'Save password is on by default'
        password_view.create_password(user_account.password)
        wait_until_logged_in(main_window)

    with step('Restart logs in without a password'):
        aut.restart()
        main_window.prepare()
        wait_until_auto_logged_in(main_window)

    with step('Sign out and the next start asks for the password'):
        sign_out_and_quit(main_window)
        wait_until_aut_quit(aut)
        aut.restart()
        main_window.prepare()
        wait_until_login_screen()

    with step('An explicit login stores the credential again'):
        ReturningLoginView().log_in_with_password(user_account.password)
        wait_until_logged_in(main_window)

    with step('The following restart logs in without a password'):
        aut.restart()
        main_window.prepare()
        wait_until_auto_logged_in(main_window)


def test_stay_logged_in_opt_out_requires_password_after_restart(main_window_without_test_mode, user_account):
    aut, main_window = main_window_without_test_mode

    with step('Create a profile with save password turned off'):
        password_view = open_create_password_view()
        password_view.set_stay_logged_in(False)
        password_view.create_password(user_account.password)
        wait_until_logged_in(main_window)

    with step('Restart still asks for the password'):
        aut.restart()
        main_window.prepare()
        wait_until_login_screen()
