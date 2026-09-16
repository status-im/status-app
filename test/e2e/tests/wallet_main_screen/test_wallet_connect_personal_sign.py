import allure
import pytest

from helpers.wallet_connect_helper import WalletConnectDapp, request_personal_sign
from helpers.wallet_helper import get_status_account_address, sign_with_password


@pytest.mark.timeout(400)
@allure.title('WalletConnect — personal_sign with password authentication')
@allure.description(
    'Connect a WalletConnect test dApp, approve its personal_sign request, '
    'authenticate with the profile password, and verify the recovered signer.'
)
def test_wallet_connect_personal_sign(main_screen, user_account):
    account_address = get_status_account_address(main_screen)

    with WalletConnectDapp() as dapp:
        request_personal_sign(main_screen, dapp, account_address)
        sign_with_password(user_account)
        dapp.assert_signed_by(account_address)
