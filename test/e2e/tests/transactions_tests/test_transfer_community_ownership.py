import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomCommunity, RandomUser
from constants.wallet import WalletNetworkNaming
from gui.components.wallet.send_popup import SendPopup
from gui.main_window import MainWindow
from gui.screens.community_settings_tokens import MintedTokensView
from helpers.chat_helper import skip_message_backup_popup_if_visible
from helpers.community_tokens_helper import mint_owner_and_tokenmaster
from helpers.multiple_instances_helper import (
    accept_contact_request_from_settings,
    authorize_user_in_aut,
    get_chat_key,
    get_user_display_name,
    send_contact_request_from_settings,
    switch_to_aut,
)
from helpers.onboarding_helper import skip_post_login_popups_if_visible
from helpers.settings_helper import enable_managing_communities_toggle, enable_testnet_mode
from helpers.wallet_helper import (
    authenticate_with_password,
    get_status_account_address,
    open_wallet_account,
    wait_for_account_assets_loaded,
    wallet_send_import_user,
    wallet_send_returning_user,
)
from scripts.utils.generators import random_text_message


@pytest.mark.transaction
@pytest.mark.parametrize('network_name', [
    pytest.param(WalletNetworkNaming.LAYER1_ETHEREUM_HOODI.value, id='hoodi'),
])
def test_transfer_community_ownership(multiple_instances, network_name):
    owner = wallet_send_returning_user()
    recipient = RandomUser()
    community = RandomCommunity()
    main_screen = MainWindow()

    with multiple_instances(user_data=None) as aut_owner, multiple_instances(user_data=None) as aut_recipient:
        with step(f'Launch owner from funded seed and recipient {recipient.name}'):
            switch_to_aut(aut_owner, main_screen)
            wallet_send_import_user(main_screen, owner)
            enable_managing_communities_toggle(main_screen)
            owner_display_name = get_user_display_name(aut_owner, main_screen)
            main_screen.minimize()
            authorize_user_in_aut(aut_recipient, main_screen, recipient)

        with step('Enable testnet on recipient and copy wallet address'):
            switch_to_aut(aut_recipient, main_screen)
            enable_testnet_mode(main_screen)
            skip_post_login_popups_if_visible()
            recipient_address = get_status_account_address(main_screen)
            main_screen.minimize()

        with step('Owner sends Hoodi ETH to recipient for set-signer fees'):
            switch_to_aut(aut_owner, main_screen)
            wallet_account = open_wallet_account(main_screen)
            wait_for_account_assets_loaded(wallet_account)
            send_popup = wallet_account.open_send_popup()
            send_popup.select_network(network_name)
            send_popup.sign_and_send(recipient_address, '0.01', 'ETH')
            authenticate_with_password(owner)
            SendPopup().wait_until_hidden()
            main_screen.minimize()

        with step(f'{recipient.name} shares chat key'):
            chat_key = get_chat_key(aut_recipient, main_screen)
            main_screen.minimize()

        with step(f'{owner.name} sends contact request to {recipient.name}'):
            send_contact_request_from_settings(
                aut_owner, main_screen, chat_key, f'Hello {recipient.name}')
            main_screen.minimize()

        with step(f'{recipient.name} accepts contact from {owner_display_name}'):
            accept_contact_request_from_settings(aut_recipient, main_screen, owner_display_name)

        with step(f'{owner.name} creates community and invites {recipient.name}'):
            switch_to_aut(aut_owner, main_screen)
            main_screen.left_panel.create_community(community_data=community)
            community_screen = main_screen.left_panel.open_community(community.name)
            add_members = community_screen.left_panel.open_add_members_popup()
            add_members.invite([recipient.name], message=random_text_message())
            main_screen.minimize()

        with step(f'{recipient.name} joins community from invitation'):
            switch_to_aut(aut_recipient, main_screen)
            messages_view = main_screen.left_panel.open_messages_screen()
            skip_message_backup_popup_if_visible()
            assert driver.waitFor(
                lambda: owner_display_name in messages_view.left_panel.get_chats_names,
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            ), f'Chat with {owner_display_name} not in list'
            chat = messages_view.left_panel.click_chat_by_name(owner_display_name)
            community_screen = chat.click_community_invite_message()
            welcome_popup = community_screen.left_panel.open_welcome_community_popup()
            assert community.name in welcome_popup.title
            welcome_popup.join().authenticate(recipient.password)
            assert driver.waitFor(
                lambda: not community_screen.left_panel.is_join_community_visible,
                configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
            ), 'Join community button not hidden'
            main_screen.minimize()

        with step(f'{owner.name} mints Owner and TokenMaster tokens'):
            switch_to_aut(aut_owner, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            community_setting = community_screen.left_panel.open_community_settings()
            mint_owner_and_tokenmaster(
                community_setting, owner.password, network_name, community.name)

        with step(f'{owner.name} sends Owner token to {recipient.name}'):
            token_page = MintedTokensView().open_owner_token(community.name)
            send_popup = token_page.open_transfer_ownership().confirm_and_open_send()
            send_popup.sign_and_send_preselected(recipient_address)
            authenticate_with_password(owner)
            SendPopup().wait_until_hidden()
            main_screen.minimize()

        with step(f'{recipient.name} finalises ownership'):
            switch_to_aut(aut_recipient, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            overview = community_screen.left_panel.open_community_settings().left_panel.open_overview()
            overview.open_finalise_ownership().finalise_and_sign(recipient.password)
            overview = community_screen.left_panel.open_community_settings().left_panel.open_overview()
            assert driver.waitFor(
                lambda: 'control node' in overview.primary_button_text.lower(),
                configs.timeouts.WALLET_HISTORY_TX_TIMEOUT_MSEC,
            ), f'Recipient is not control node after finalise, got {overview.primary_button_text!r}'
            main_screen.minimize()

        with step('Previous owner no longer has owner-only mint controls'):
            switch_to_aut(aut_owner, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            tokens_view = community_screen.left_panel.open_community_settings().left_panel.open_tokens()
            assert driver.waitFor(
                lambda: (
                    not tokens_view.mint_token_button.is_visible
                    or not tokens_view.is_mint_token_button_enabled
                ),
                configs.timeouts.WALLET_HISTORY_TX_TIMEOUT_MSEC,
            ), 'Mint token button still enabled for previous owner'
