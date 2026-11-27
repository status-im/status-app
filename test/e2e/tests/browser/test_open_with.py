"""Files handed to Status by macOS "Open With" open in browser Tabs."""
import time

import pytest
from allure_commons._allure import step

from configs.system import get_platform
from gui.elements.object import QObject
from gui.objects_map import names
from gui.screens.browser import BrowserScreen
from helpers.open_with_helper import open_with_status, sample_file

pytestmark = [
    pytest.mark.browser,
    pytest.mark.skipif(get_platform() != 'Darwin', reason='"Open With" through LaunchServices'),
]


def test_open_with_pdf_opens_a_tab(main_screen, tmp_path):
    pdf = sample_file(tmp_path, 'pdf')

    open_with_status(pdf)

    BrowserScreen().wait_for_opened_file(pdf.name)


@pytest.mark.parametrize('extension', ['png', 'txt', 'json', 'mp3', 'webm'])
def test_open_with_supported_format_opens_a_tab(main_screen, tmp_path, extension):
    file = sample_file(tmp_path, extension)

    open_with_status(file)

    BrowserScreen().wait_for_opened_file(file.name)


def test_open_with_unsupported_format_says_it_could_not_open(main_screen, tmp_path):
    archive = sample_file(tmp_path, 'zip')

    open_with_status(archive)

    BrowserScreen().wait_for_open_failed(archive.name)


def test_restored_opened_file_opens_only_when_its_tab_is_shown(aut, main_screen, user_account, tmp_path):
    first = sample_file(tmp_path, 'txt', 'restored-first')
    second = sample_file(tmp_path, 'pdf', 'restored-second')
    browser = BrowserScreen()

    with step('Open two files with "Restore open tabs" on'):
        open_with_status(first)
        browser.wait_for_opened_file(first.name)
        browser.set_restore_open_tabs(True)
        open_with_status(second)
        browser.wait_for_opened_file(second.name)
        time.sleep(2)  # the session is saved shortly after a Tab is added

    with step('Restart and log in'):
        aut.restart()
        main_screen.prepare()
        main_screen.authorize_user(user_account)
        browser = main_screen.left_panel.open_browser()
        browser.wait_for_opened_file(second.name)

    with step('Only the shown Tab is built'):
        assert browser.built_tabs()[-2:] == [False, True]

    with step('Showing the other Tab opens its file'):
        browser.show_tab(len(browser.built_tabs()) - 2)
        browser.wait_for_opened_file(first.name)
        assert browser.built_tabs()[-2:] == [True, True]


def test_restored_session_shows_the_tab_that_was_current(aut, main_screen, user_account, tmp_path):
    """An empty Tab is not saved, so it must not shift which saved Tab is current."""
    shown = sample_file(tmp_path, 'pdf', 'current-file')
    later = sample_file(tmp_path, 'txt', 'later-file')

    with step('An empty Tab, then two files, and the first file shown'):
        browser = main_screen.left_panel.open_browser()
        browser.set_restore_open_tabs(True)
        browser.open_empty_tab()
        open_with_status(shown)
        browser.wait_for_opened_file(shown.name)
        open_with_status(later)
        browser.wait_for_opened_file(later.name)
        browser.show_tab(len(browser.built_tabs()) - 2)
        browser.wait_for_opened_file(shown.name)
        time.sleep(2)  # the session is saved shortly after the current Tab changes

    with step('Restart and log in'):
        aut.restart()
        main_screen.prepare()
        main_screen.authorize_user(user_account)

    with step('The same file is shown'):
        main_screen.left_panel.open_browser().wait_for_opened_file(shown.name)


def test_open_with_in_privacy_mode_says_why_it_does_not_open(main_screen, tmp_path):
    pdf = sample_file(tmp_path, 'pdf')
    main_screen.object._eval('appSettings.thirdpartyServicesEnabled = false')

    open_with_status(pdf)

    toast = QObject({**names.ephemeralNotificationList_StatusToastMessage,
                     'primaryText': 'Enable third-party services to open files in Status'})
    toast.wait_until_appears()
