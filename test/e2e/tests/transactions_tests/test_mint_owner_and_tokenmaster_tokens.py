import random
import time

import allure
import pytest
from allure_commons._allure import step

import configs
import driver
from configs import WALLET_SEED
from constants import ReturningUser, RandomCommunity
from helpers.onboarding_helper import open_create_profile_view, import_seed_and_log_in
from helpers.settings_helper import enable_testnet_mode, enable_managing_communities_toggle
from constants.community import MintOwnerTokensElements
from gui.screens.community_settings_tokens import MintedTokensView
from scripts.utils.generators import random_network_for_minting


@pytest.mark.case(727245)
@pytest.mark.transaction
@pytest.mark.parametrize('network_name', [pytest.param(random_network_for_minting())])
def test_mint_owner_and_tokenmaster_tokens(main_window, user_account, network_name):

    user_account = ReturningUser(
        seed_phrase=WALLET_SEED,
        status_address='0x44ddd47a0c7681a5b0fa080a56cbb7701db4bb43')

    with step('Import seed and log in'):
        with step('Open Create your profile view'):
            create_your_profile_view = open_create_profile_view()
        with step('Import seed and log in'):
            import_seed_and_log_in(create_your_profile_view, user_account.seed_phrase, user_account)

    with step('Set testnet mode'):
        enable_testnet_mode(main_window)

    with step('Switch manage community on testnet option'):
        enable_managing_communities_toggle(main_window)

    with step('Create community and select it'):
        community = RandomCommunity()
        main_window.left_panel.create_community(community_data=community)
        community_screen = main_window.left_panel.select_community(community.name)

    with step('Open mint owner token view'):
        community_setting = community_screen.left_panel.open_community_settings()
        tokens_screen = community_setting.left_panel.open_tokens().click_mint_owner_button()

    with step('Click next'):
        edit_owner_token_view = tokens_screen.click_next()

    with step('Select network'):
        # no Sepolia L1 because of high gas prices, no Linea because of no contracts
        edit_owner_token_view.select_network(network_name)

    with step('Verify fees title and gas fees exist'):
        assert driver.waitFor(lambda: edit_owner_token_view.get_fee_title == 'Mint ' + community.name + MintOwnerTokensElements.SIGN_TRANSACTION_MINT_TITLE.value + network_name,
                              configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        assert driver.waitFor(lambda: edit_owner_token_view.get_fee_total_value != '',
                              configs.timeouts.UI_LOAD_TIMEOUT_MSEC)

    with step('Start minting'):
        start_minting = edit_owner_token_view.mint()

    with step('Verify fee text and sign transaction'):
        assert start_minting.get_fee_title == 'Mint ' + community.name + MintOwnerTokensElements.SIGN_TRANSACTION_MINT_TITLE.value + network_name
        assert start_minting.get_fee_total_value != ''
        start_minting.sign_transaction(user_account.password)
        time.sleep(1)
        minted_tokens_view = MintedTokensView()

    with step('Verify toast messages about started minting process appears'):
        toast_messages = main_window.wait_for_toast_notifications()
        assert f'Minting Owner-{community.name} and TMaster-{community.name} tokens for {community.name} using Account 1' in toast_messages

    with step('Verify that status of both tokens'):
        minted_tokens_view.check_community_collectibles_statuses()
