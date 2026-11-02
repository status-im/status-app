import pytest

from gui.components.wallet.dapps_workflow import DappsWorkflow
from helpers.wallet_helper import sign_with_password


@pytest.mark.critical
@pytest.mark.browser
def test_personal_sign_in_browser(main_screen, user_account, browser_pages):
    browser = main_screen.left_panel.open_browser()
    browser.open_url(f'{browser_pages.origin}/sign.html')
    browser.wait_for_title('E2E Sign')

    dapps = DappsWorkflow()
    dapps.approve_connection_and_close().reject_sign_request()
    browser.wait_for_title('rejected')
    dapps.approve_sign_request()
    sign_with_password(user_account)

    browser.wait_for_title('signed:0x', startswith=True)
