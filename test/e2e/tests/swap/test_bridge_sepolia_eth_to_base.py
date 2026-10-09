import time

import pytest
from allure_commons._allure import step

from constants.networks import WalletNetworkNaming
from constants.wallet import WalletHistoryTitles
from gui.components.wallet.swap_popup import SwapPopup
from helpers.wallet_helper import (
    authenticate_with_password,
    open_wallet_account,
    wait_for_account_assets_loaded,
    wallet_send_import_user,
    wallet_send_returning_user,
)


@pytest.mark.bridge
@pytest.mark.transaction
@pytest.mark.timeout(600)
def test_bridge_sepolia_eth_to_base(main_window, user_account):
    user_account = wallet_send_returning_user()
    wallet_send_import_user(main_window, user_account)
    wallet_account = open_wallet_account(main_window)
    wait_for_account_assets_loaded(wallet_account)
    swap_popup = wallet_account.open_swap_popup()
    sepolia = WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET
    base_sepolia = WalletNetworkNaming.LAYER2_BASE_SEPOLIA

    with step('Quote Sepolia ETH to Base Sepolia ETH'):
        swap_popup.select_token('receive', 'ETH', base_sepolia.chain_id)
        swap_popup.set_pay_amount('0,0001')
        swap_popup.wait_until_confirm_ready('Confirm Bridge')

    with step('Sign and send the bridge'):
        sent_at = time.time()
        swap_popup.sign('Sign Bridge')
        authenticate_with_password(user_account)
        SwapPopup().wait_until_hidden()

    with step('Bridge appears in History on Sepolia'):
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.BRIDGE,
            network_name=sepolia.value,
            sent_at=sent_at,
        )
