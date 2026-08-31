import pytest
from allure_commons._allure import step

from gui.main_window import MainWindow
from . import marks

from constants import UserAccount
from scripts.utils.generators import random_password_string
from constants.onboarding import OnboardingMessages
from driver.aut import AUT
from gui.screens.onboarding import ReturningLoginView

pytestmark = marks


@pytest.mark.case(702991)
@pytest.mark.parametrize('error', [OnboardingMessages.PASSWORD_INCORRECT.value
                                   ])
def test_login_with_wrong_password(aut: AUT, main_screen: MainWindow, user_account, error: str):

    with step('Verify that the user logged in correctly'):
        user_image = main_screen.left_panel.open_online_identifier()
        profile_popup = user_image.open_profile_popup_from_online_identifier()
        assert profile_popup.user_name == user_account.name

    with step('Restart application and input wrong password'):
        aut.restart()
        main_screen.prepare()
        login_view = ReturningLoginView()
        login_view.log_in(UserAccount(
            name=user_account.name,
            password=random_password_string()
        ))

    with step('Verify that user cannot log in and the error appears'):
        assert error in str(login_view.password_box.object.validationError)
