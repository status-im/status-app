import random
import time

import pytest
from allure_commons._allure import step

import configs
import constants
from constants.networks import LAYER2_ETHEREUM_TESTNETS
from constants.wallet import (
    WalletAddress,
    WalletCollectibleCollections,
    WalletHistoryTitles,
    WalletNetworkSettings,
)
from gui.components.wallet.send_popup import SendPopup
from helpers.onboarding_helper import skip_post_login_popups_if_visible
from helpers.wallet_helper import (
    authenticate_with_password,
    open_wallet_account,
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
@pytest.mark.timeout(timeout=360)
def test_wallet_send_nft(main_screen, user_account):
    receiver_account_address = WalletAddress.RECEIVER_ADDRESS.value
    network_name = random.choice(LAYER2_ETHEREUM_TESTNETS).value

    skip_post_login_popups_if_visible()

    with step('Open wallet send popup after collectibles are loaded'):
        wallet_account = open_wallet_account(main_screen)
        wallet_account.open_collectibles_tab(require_items=True)
        send_popup = wallet_account.open_send_popup()

    with step(f'Select {network_name} network'):
        send_popup.select_network(network_name)

    with step('Sign and send ERC-721 NFT to blockchain'):
        sent_at = time.time()
        send_popup.sign_and_send(
            receiver_account_address,
            '',
            '',
            collectible_collection=WalletCollectibleCollections.ERC721_FAUCET.value,
        )

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    with step('Verify send flow completed'):
        SendPopup().wait_until_hidden()

    with step('Verify NFT transaction appears in History'):
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.SEND,
            network_name=network_name,
            sent_at=sent_at,
            to_address=WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value,
        )
