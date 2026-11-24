import pytest
from allure_commons._allure import step

from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from driver.aut import AUT
from gui.main_window import MainWindow
from gui.screens.onboarding import ReturningLoginView
from helpers.aut_helper import quit_app


@pytest.mark.settings_all
def test_quit_shortcut_ignores_minimize_on_close(aut: AUT, main_screen: MainWindow, user_account):
    advanced = main_screen.left_panel.open_settings().left_panel.open_advanced_settings()
    if not advanced.minimize_to_tray_on_close_button.is_visible:
        pytest.skip('Minimize to tray on close is hidden when the system tray is unavailable')

    with step('Minimize to tray on: quit shortcut closes the application'):
        advanced.set_minimize_to_tray_on_close(True)
        quit_app(main_screen, aut)

    with step('Minimize to tray off: quit shortcut closes the application'):
        aut.restart()
        main_screen.prepare()
        ReturningLoginView().wait_until_appears(APP_LOAD_TIMEOUT_MSEC)
        main_screen.returning_log_in(user_account)
        advanced = main_screen.left_panel.open_settings().left_panel.open_advanced_settings()
        advanced.set_minimize_to_tray_on_close(False)
        quit_app(main_screen, aut)