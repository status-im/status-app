import pytest
from allure_commons._allure import step

from constants.wallet import WalletAddress, WalletNetworkNaming
from gui.components.wallet.send_popup import SendPopup
from helpers.wallet_helper import (
    authenticate_with_password,
    wallet_send_import_and_open_send_modal,
    wallet_send_returning_user,
)


@pytest.mark.transaction
@pytest.mark.smoke
@pytest.mark.parametrize('receiver_account_address, amount, network_name', [
    pytest.param(
        WalletAddress.RECEIVER_ADDRESS.value,
        '0',
        WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET.value,
    ),
])
def test_wallet_send_0_eth(main_window, user_account, receiver_account_address, amount, network_name):
    user_account = wallet_send_returning_user()

    send_popup = wallet_send_import_and_open_send_modal(main_window, user_account)

    with step('Select network'):
        send_popup.select_network(network_name)

    with step('Sign and send ETH transaction to blockchain'):
        send_popup.sign_and_send(receiver_account_address, amount, 'ETH')

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    with step('Verify send flow completed'):
        SendPopup().wait_until_hidden()
