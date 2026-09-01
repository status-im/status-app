import time

import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomCommunity
from helpers.settings_helper import enable_managing_communities_toggle
from helpers.wallet_helper import (
    open_wallet_account,
    wallet_send_import_user,
    wallet_send_returning_user,
)
from constants.community import MintOwnerTokensElements
from constants.wallet import WalletHistoryTitles, WalletNetworkNaming
from gui.screens.community_settings_tokens import MintedTokensView


@pytest.mark.case(727245)
@pytest.mark.transaction
@pytest.mark.parametrize('network_name', [
    pytest.param(WalletNetworkNaming.LAYER1_ETHEREUM_HOODI.value, id='hoodi'),
])
def test_mint_owner_and_tokenmaster_tokens(main_window, user_account, network_name):
    user_account = wallet_send_returning_user()
    wallet_send_import_user(main_window, user_account)

    with step('Switch manage community on testnet option'):
        enable_managing_communities_toggle(main_window)

    with step('Create community and select it'):
        community = RandomCommunity()
        main_window.left_panel.create_community(community_data=community)
        community_screen = main_window.left_panel.open_community(community.name)

    with step('Open mint owner token view'):
        community_setting = community_screen.left_panel.open_community_settings()
        tokens_screen = community_setting.left_panel.open_tokens().click_mint_owner_button()

    with step('Click next'):
        edit_owner_token_view = tokens_screen.click_next()

    with step('Select network'):
        edit_owner_token_view.select_network(network_name)

    with step('Verify fees title and gas fees exist'):
        expected_fee_title = (
            'Mint ' + community.name
            + MintOwnerTokensElements.SIGN_TRANSACTION_MINT_TITLE.value
            + network_name
        )
        actual_fee_title = edit_owner_token_view.get_fee_title
        assert actual_fee_title == expected_fee_title, (
            f'{actual_fee_title!r} != {expected_fee_title!r}'
        )
        assert driver.waitFor(lambda: edit_owner_token_view.get_fee_total_value != '',
                              configs.timeouts.UI_LOAD_TIMEOUT_MSEC)

    with step('Start minting'):
        start_minting = edit_owner_token_view.mint()

    with step('Verify fee text and sign transaction'):
        assert start_minting.get_fee_title == 'Mint ' + community.name + MintOwnerTokensElements.SIGN_TRANSACTION_MINT_TITLE.value + network_name
        assert start_minting.get_fee_total_value != ''
        start_minting.sign_transaction(user_account.password)
        sent_at = time.time()

    with step('Verify Owner and TokenMaster mint completed'):
        MintedTokensView().check_community_collectibles_statuses(community.name)

    with step('Verify mint transaction appears in History'):
        wallet_account = open_wallet_account(main_window)
        wallet_account.wait_for_new_history_transaction(
            titles=WalletHistoryTitles.MINT,
            network_name=network_name,
            sent_at=sent_at,
        )
