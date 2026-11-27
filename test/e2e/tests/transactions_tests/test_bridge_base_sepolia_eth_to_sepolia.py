import time

import pytest
from allure_commons._allure import step

import configs
import constants
from constants.networks import WalletNetworkNaming
from constants.wallet import WalletHistoryTitles
from gui.components.wallet.swap_popup import SwapPopup
from helpers.onboarding_helper import skip_post_login_popups_if_visible
from helpers.wallet_helper import (
    authenticate_with_password,
    open_wallet_account,
    wait_for_account_assets_loaded,
)


@pytest.mark.bridge
@pytest.mark.transaction
@pytest.mark.parametrize(
    'user_data, user_account',
    [pytest.param(
        configs.testpath.TEST_USER_DATA / 'funds',
        constants.user.funds,
    )],
    indirect=['user_data', 'user_account'],
)
@pytest.mark.timeout(600)
def test_bridge_base_sepolia_eth_to_sepolia(main_screen, user_account):
    # Sepolia -> Base Sepolia quotes INSUFFICIENT_LIQUIDITY (max $0) as of 2026-11-27.
    skip_post_login_popups_if_visible()
    wallet_account = open_wallet_account(main_screen)
    wait_for_account_assets_loaded(wallet_account)
    swap_popup = wallet_account.open_swap_popup()
    sepolia = WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET
    base_sepolia = WalletNetworkNaming.LAYER2_BASE_SEPOLIA

    with step('Quote Base Sepolia ETH to Sepolia ETH'):
        swap_popup.select_token('receive', 'ETH', sepolia.chain_id)
        swap_popup.select_token('pay', 'ETH', base_sepolia.chain_id)
        swap_popup.set_pay_amount('0.0001')
        swap_popup.wait_until_confirm_ready('Confirm Bridge')

    with step('Sign and send the bridge'):
        sent_at = time.time()
        swap_popup.sign('Sign Bridge')
        authenticate_with_password(user_account)
        SwapPopup().wait_until_hidden()

    with step('Bridge appears in History on Base Sepolia'):
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.BRIDGE,
            network_name=base_sepolia.value,
            sent_at=sent_at,
        )
