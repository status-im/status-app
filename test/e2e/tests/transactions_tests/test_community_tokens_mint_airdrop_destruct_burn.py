import time

import pytest
from allure_commons._allure import step

from constants import RandomCommunity
from constants.wallet import WalletHistoryTitles, WalletNetworkNaming
from gui.screens.community_settings_tokens import MintedTokensView, TokensView
from helpers.community_tokens_helper import (
    add_generated_account_address,
    mint_community_token,
    mint_owner_and_tokenmaster,
)
from helpers.settings_helper import enable_managing_communities_toggle
from helpers.wallet_helper import (
    open_wallet_account,
    wallet_send_import_user,
    wallet_send_returning_user,
)

NFT_NAME = 'HoodiNFT'
NFT_SYMBOL = 'HNFT'
ASSET_NAME = 'HoodiAST'
ASSET_SYMBOL = 'HAST'
TOKEN_SUPPLY = '10'
AIRDROP_ACCOUNT_NAME = 'Airdrop dest'


@pytest.mark.transaction
@pytest.mark.parametrize('network_name', [
    pytest.param(WalletNetworkNaming.LAYER1_ETHEREUM_HOODI.value, id='hoodi'),
])
def test_community_tokens_mint_airdrop_destruct_burn(main_window, user_account, network_name):
    user_account = wallet_send_returning_user()
    wallet_send_import_user(main_window, user_account)

    with step('Add a second account in the same profile for airdrop'):
        recipient_address = add_generated_account_address(main_window, AIRDROP_ACCOUNT_NAME)

    with step('Switch manage community on testnet option'):
        enable_managing_communities_toggle(main_window)

    with step('Create community and select it'):
        community = RandomCommunity()
        main_window.left_panel.create_community(community_data=community)
        community_screen = main_window.left_panel.open_community(community.name)

    with step('Mint Owner and TokenMaster tokens'):
        community_setting = community_screen.left_panel.open_community_settings()
        mint_owner_and_tokenmaster(
            community_setting, user_account.password, network_name, community.name)

    with step('Mint remotely destructible collectible with finite supply'):
        tokens_view = TokensView()
        mint_community_token(
            tokens_view,
            user_account.password,
            name=NFT_NAME,
            description='Hoodi e2e collectible',
            symbol=NFT_SYMBOL,
            supply=TOKEN_SUPPLY,
            network_name=network_name,
            is_asset=False,
        )

    with step('Mint community asset with finite supply'):
        tokens_view = community_setting.left_panel.open_tokens()
        mint_community_token(
            tokens_view,
            user_account.password,
            name=ASSET_NAME,
            description='Hoodi e2e asset',
            symbol=ASSET_SYMBOL,
            supply=TOKEN_SUPPLY,
            network_name=network_name,
            is_asset=True,
        )

    with step('Airdrop collectible to the second account'):
        token_page = MintedTokensView().open_collectible(NFT_NAME)
        airdrop_view = token_page.open_airdrop()
        airdrop_view.add_eth_recipient(recipient_address)
        airdrop_view.create_and_sign(user_account.password)

    with step('Remotely destruct airdropped collectible'):
        community_setting.left_panel.open_tokens()
        token_page = MintedTokensView().open_collectible(NFT_NAME)
        destruct_sent_at = time.time()
        token_page.open_remotely_destruct().destruct_first_holder_and_sign(user_account.password)

    with step('Burn remaining collectible supply'):
        community_setting.left_panel.open_tokens()
        token_page = MintedTokensView().open_collectible(NFT_NAME)
        burn_sent_at = time.time()
        token_page.open_burn().burn_all_remaining_and_sign(user_account.password)

    with step('Verify destroy and burn transactions appear in History'):
        wallet_account = open_wallet_account(main_window)
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.DESTROY,
            network_name=network_name,
            sent_at=destruct_sent_at,
        )
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.BURN,
            network_name=network_name,
            sent_at=burn_sent_at,
        )
