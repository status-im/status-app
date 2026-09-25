from allure_commons._allure import step

from gui.main_window import MainWindow
from . import marks

from driver.aut import AUT
from gui.screens.onboarding import OnboardingWelcomeToStatusView, ReturningLoginView

pytestmark = marks


def _assert_welcome_screen():
    welcome = OnboardingWelcomeToStatusView().wait_until_appears()
    assert welcome.log_in_button.is_visible
    assert not ReturningLoginView().is_visible


def test_remove_last_profile_shows_welcome(aut: AUT, main_screen: MainWindow, user_account):
    with step('Restart application to the login screen'):
        aut.restart()
        main_screen.prepare()
        ReturningLoginView().wait_until_appears()

    with step('Remove the only profile from Manage profiles'):
        ReturningLoginView().open_manage_profiles().delete_profile_by_name(user_account.name)

    with step('Welcome screen is shown after the last profile is removed'):
        _assert_welcome_screen()

    with step('Restart still shows Welcome'):
        aut.restart()
        main_screen.prepare()
        _assert_welcome_screen()
