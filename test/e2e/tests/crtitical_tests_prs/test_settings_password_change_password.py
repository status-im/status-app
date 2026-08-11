import allure
import pytest
from allure_commons._allure import step

from constants import UserAccount
from scripts.utils.generators import random_password_string

from driver.aut import AUT
from gui.main_window import MainWindow


@pytest.mark.case(703005)
@pytest.mark.critical
def test_change_password_and_login(aut: AUT, main_screen: MainWindow, user_account):
    with step('Open change password view'):
        password_view = main_screen.left_panel.open_settings().left_panel.open_password_settings()

    with step('Fill in the change password form and submit'):
        new_password = random_password_string()
        change_password_popup = password_view.change_password(user_account.password, new_password)

    with step('Confirm the password change (fast path, no restart required)'):
        restarting = change_password_popup.confirm_password_change()
        assert not restarting, \
            'Profiles created by this build use the fast password change; no restart expected'

    with step('Restart application'):
        aut.restart()
        main_screen.prepare()

    with step('Login with new password'):
        main_screen.authorize_user(UserAccount(name=user_account.name,
                                               password=new_password))

    with step('Verify that the user logged in correctly'):
        online_identifier = main_screen.left_panel.open_online_identifier()
        profile_popup = online_identifier.open_profile_popup_from_online_identifier()
        assert profile_popup.user_name == user_account.name
