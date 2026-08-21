import time

import pytest
from allure_commons._allure import step

from constants.networks import LAYER2_ETHEREUM_TESTNETS
from constants.wallet import WalletAddress, WalletHistoryTitles
from gui.components.wallet.send_popup import SendPopup
from helpers.wallet_helper import (
    authenticate_with_password,
    open_wallet_account,
    wallet_send_import_user,
    wallet_send_returning_user,
)


@pytest.mark.case(704602)
@pytest.mark.transaction
@pytest.mark.parametrize('receiver_account_address, network_name', [
    pytest.param(
        WalletAddress.RECEIVER_ADDRESS.value,
        network.value,
        id=f'{network.name.lower()}_erc721',
    )
    for network in LAYER2_ETHEREUM_TESTNETS
])
@pytest.mark.timeout(timeout=180)
@pytest.mark.skip(reason='https://github.com/status-im/status-app/issues/22017')
def test_wallet_send_nft(
    main_window,
    user_account,
    receiver_account_address,
    network_name,
):
    user_account = wallet_send_returning_user()
    wallet_send_import_user(main_window, user_account)

    with step('Open wallet send popup after collectibles are loaded'):
        wallet_account = open_wallet_account(main_window)
        wallet_account.open_collectibles_tab()
        send_popup = wallet_account.open_send_popup()

    with step(f'Select {network_name} network'):
        send_popup.select_network(network_name)

    with step('Sign and send ERC-721 NFT to blockchain'):
        sent_at = time.time()
        send_popup.sign_and_send(receiver_account_address, '', '')

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    with step('Verify send flow completed'):
        SendPopup().wait_until_hidden()

    with step('Verify NFT transaction appears in History'):
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.SEND,
            network_name=network_name,
            sent_at=sent_at,
            to_address=receiver_account_address,
        )
