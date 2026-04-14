import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomCommunity, RandomUser, UserAccount
from constants.showcase_visibility import ShowcaseVisibility
from gui.main_window import MainWindow
from helpers.chat_helper import skip_message_backup_popup_if_visible
from helpers.multiple_instances_helper import (
    accept_contact_request_from_settings,
    authorize_user_in_aut,
    get_chat_key,
    send_contact_request_from_settings,
    switch_to_aut,
)
from scripts.utils.generators import random_text_message


@pytest.mark.communities
def test_join_leave_profile_showcase_community(multiple_instances):
    owner: UserAccount = RandomUser()
    invitee: UserAccount = RandomUser()
    community = RandomCommunity()
    main_screen = MainWindow()

    with multiple_instances(user_data=None) as aut_owner, multiple_instances(user_data=None) as aut_invitee:
        with step(f'Launch two instances: owner {owner.name}, invitee {invitee.name}'):
            for aut, account in zip([aut_owner, aut_invitee], [owner, invitee]):
                authorize_user_in_aut(aut, main_screen, account)

        with step(f'{invitee.name} shares chat key'):
            chat_key = get_chat_key(aut_invitee, main_screen)
            main_screen.minimize()

        with step(f'{owner.name} sends contact request to {invitee.name}'):
            send_contact_request_from_settings(
                aut_owner, main_screen, chat_key, f'Hello {invitee.name}')
            main_screen.minimize()

        with step(f'{invitee.name} accepts contact from {owner.name}'):
            accept_contact_request_from_settings(aut_invitee, main_screen, owner.name)

        with step(f'{owner.name} creates community and invites {invitee.name}'):
            switch_to_aut(aut_owner, main_screen)
            main_screen.left_panel.create_community(community_data=community)
            community_screen = main_screen.left_panel.open_community(community.name)
            add_members = community_screen.left_panel.open_add_members_popup()
            add_members.invite([invitee.name], message=random_text_message())
            main_screen.minimize()

        with step(f'{invitee.name} joins community from invitation'):
            switch_to_aut(aut_invitee, main_screen)
            messages_view = main_screen.left_panel.open_messages_screen()
            skip_message_backup_popup_if_visible()
            assert driver.waitFor(
                lambda: owner.name in messages_view.left_panel.get_chats_names,
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            ), f'Chat with {owner.name} not in list'
            chat = messages_view.left_panel.click_chat_by_name(owner.name)
            community_screen = chat.click_community_invite(community.name, 0)
            welcome_popup = community_screen.left_panel.open_welcome_community_popup()
            assert community.name in welcome_popup.title
            assert community.introduction == welcome_popup.intro
            welcome_popup.join().authenticate(invitee.password)
            assert driver.waitFor(
                lambda: not community_screen.left_panel.is_join_community_visible,
                configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
            ), 'Join community button not hidden'
            main_screen.minimize()

        with step('Invitee: community not in showcase (hidden / No one)'):
            switch_to_aut(aut_invitee, main_screen)
            profile_settings = main_screen.left_panel.open_settings().left_panel.open_profile_settings()
            profile_settings.verify_community_visibility_state(
                community_name=community.name, visibility=ShowcaseVisibility.NO_ONE)

        with step('Invitee: set community visibility to Everyone'):
            visibility_menu = profile_settings.open_showcase_visibility_menu(community_name=community.name)
            visibility_menu.select_visibility_option(ShowcaseVisibility.EVERYONE)
            profile_settings.save_changes_button.click()

        with step('Invitee: community is in showcase'):
            profile_settings.verify_community_visibility_state(
                community_name=community.name, visibility=ShowcaseVisibility.EVERYONE)

        with step('Invitee: community shown on profile cards'):
            profile = main_screen.left_panel.open_online_identifier().open_profile_popup_from_online_identifier()
            communities_names = profile.communities_names_on_cards()
            assert communities_names, 'At least one community card expected after adding to showcase'
            assert community.name in communities_names

        with step(f'{invitee.name} leaves community'):
            context_menu = main_screen.left_panel.open_community_context_menu(community.name)
            assert context_menu.leave_community_option.is_visible
            confirmation = context_menu.open_leave_community_popup()
            confirmation.confirm_action()

        with step('Invitee: community no longer in left panel'):
            assert not main_screen.left_panel.communities(), 'Communities list should be empty after leave'
