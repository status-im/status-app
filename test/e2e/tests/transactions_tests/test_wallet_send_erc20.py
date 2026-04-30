import pytest
from allure_commons._allure import step

from constants.wallet import WalletAddress, WalletNetworkNaming, WalletTokenSymbols
from helpers.wallet_helper import (
    assert_wallet_send_toast,
    authenticate_with_password,
    wallet_send_import_and_open_send_modal,
    wallet_send_returning_user,
)


@pytest.mark.transaction
@pytest.mark.parametrize('receiver_account_address, amount, token_symbol, network_name', [
    pytest.param(
        WalletAddress.RECEIVER_ADDRESS.value,
        '1',
        WalletTokenSymbols.SNT.value,
        WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET.value,
        id='layer1_ethereum_testnet_snt',
    ),
])
def test_wallet_send_erc20(main_window, user_account, receiver_account_address, amount, token_symbol, network_name):
    user_account = wallet_send_returning_user()

    send_popup = wallet_send_import_and_open_send_modal(main_window, user_account)

    with step('Select network'):
        send_popup.select_network(network_name)

    with step('Sign and send ERC-20 transaction to blockchain'):
        send_popup.sign_and_send(receiver_account_address, amount, token_symbol)

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    assert_wallet_send_toast(main_window, receiver_account_address)
