import time

import pytest
from allure_commons._allure import step

import configs
import constants
from constants.wallet import (
    WalletAddress,
    WalletHistoryTitles,
    WalletNetworkNaming,
    WalletNetworkSettings,
    WalletTokenSymbols,
)
from gui.components.wallet.send_popup import SendPopup
from helpers.onboarding_helper import skip_post_login_popups_if_visible
from helpers.wallet_helper import (
    authenticate_with_password,
    open_wallet_account,
    wait_for_account_assets_loaded,
)


@pytest.mark.transaction
@pytest.mark.parametrize(
    'user_data, user_account',
    [pytest.param(
        configs.testpath.TEST_USER_DATA / 'funds',
        constants.user.funds,
    )],
    indirect=['user_data', 'user_account'],
)
@pytest.mark.parametrize('receiver_account_address, amount, token_symbol, network_name', [
    pytest.param(
        WalletAddress.RECEIVER_ADDRESS.value,
        '1',
        WalletTokenSymbols.STT.value,
        WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET.value,
        id='sepolia_stt',
    ),
])
def test_wallet_send_erc20(
    main_screen,
    user_account,
    receiver_account_address,
    amount,
    token_symbol,
    network_name,
):
    skip_post_login_popups_if_visible()

    wallet_account = open_wallet_account(main_screen)
    wait_for_account_assets_loaded(wallet_account)
    send_popup = wallet_account.open_send_popup()

    with step('Select network'):
        send_popup.select_network(network_name)

    with step('Sign and send ERC-20 transaction to blockchain'):
        sent_at = time.time()
        send_popup.sign_and_send(receiver_account_address, amount, token_symbol)

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    with step('Verify send flow completed'):
        SendPopup().wait_until_hidden()

    with step('Verify ERC-20 transaction appears in History'):
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.SEND,
            network_name=network_name,
            sent_at=sent_at,
            to_address=WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value,
            amount=amount,
        )
