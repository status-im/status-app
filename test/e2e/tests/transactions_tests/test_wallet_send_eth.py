import time

import pytest
from allure_commons._allure import step

from constants.wallet import (
    WalletAddress,
    WalletHistoryTitles,
    WalletNetworkNaming,
)
from gui.components.wallet.send_popup import SendPopup
from helpers.wallet_helper import (
    authenticate_with_password,
    open_wallet_account,
    wait_for_account_assets_loaded,
    wallet_send_import_user,
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

    wallet_send_import_user(main_window, user_account)
    wallet_account = open_wallet_account(main_window)
    wait_for_account_assets_loaded(wallet_account)
    send_popup = wallet_account.open_send_popup()

    with step('Select network'):
        send_popup.select_network(network_name)

    with step('Sign and send ETH transaction to blockchain'):
        sent_at = time.time()
        send_popup.sign_and_send(receiver_account_address, amount, 'ETH')

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    with step('Verify send flow completed'):
        SendPopup().wait_until_hidden()

    with step('Verify ETH transaction appears in History'):
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.SEND,
            network_name=network_name,
            sent_at=sent_at,
            to_address=receiver_account_address,
            amount=amount,
        )
