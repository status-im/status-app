import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomCommunity, RandomUser, UserAccount
from gui.main_window import MainWindow
from gui.screens.messages import MessagesScreen
from helpers.community_general_helper import join_community_from_invite
from helpers.multiple_instances_helper import (
    accept_contact_request_from_settings,
    authorize_user_in_aut,
    get_chat_key,
    send_contact_request_from_settings,
    switch_to_aut,
)
from scripts.utils.generators import random_text_message


@pytest.mark.communities
def test_community_pins_panel_after_leave_rejoin(multiple_instances):
    owner: UserAccount = RandomUser()
    member: UserAccount = RandomUser()
    community = RandomCommunity()
    main_screen = MainWindow()

    with multiple_instances(user_data=None) as aut_owner, multiple_instances(user_data=None) as aut_member:
        with step(f'Launch users {owner.name} and {member.name}'):
            for aut, account in zip((aut_owner, aut_member), (owner, member)):
                authorize_user_in_aut(aut, main_screen, account)

        with step(f'{member.name} shares chat key'):
            chat_key = get_chat_key(aut_member, main_screen)
            main_screen.minimize()

        with step(f'{owner.name} sends contact request to {member.name}'):
            send_contact_request_from_settings(
                aut_owner, main_screen, chat_key, f'Hello {member.name}')
            main_screen.minimize()

        with step(f'{member.name} accepts contact from {owner.name}'):
            accept_contact_request_from_settings(aut_member, main_screen, owner.name)

        with step(f'{owner.name} creates community and invites {member.name}'):
            switch_to_aut(aut_owner, main_screen)
            main_screen.left_panel.create_community(community_data=community)
            community_screen = main_screen.left_panel.open_community(community.name)
            community_screen.left_panel.open_add_members_popup().invite(
                [member.name],
                message=random_text_message(),
            )
            main_screen.minimize()

        with step(f'{member.name} joins {community.name}'):
            switch_to_aut(aut_member, main_screen)
            join_community_from_invite(main_screen, owner.name, member.password, community.name)
            main_screen.minimize()

        with step(f'{owner.name} pins a message in #general'):
            switch_to_aut(aut_owner, main_screen)
            main_screen.left_panel.open_community(community.name)
            messages_screen = MessagesScreen()
            pinned_text = random_text_message()
            messages_screen.group_chat.send_message_to_group_chat(pinned_text)
            messages_screen.chat.find_message_by_text(pinned_text, 0).open_context_menu().pin_message()
            main_screen.minimize()

        with step(f'{member.name} sees {pinned_text} in the pins panel'):
            switch_to_aut(aut_member, main_screen)
            main_screen.left_panel.open_community(community.name)
            MessagesScreen().tool_bar.open_pinned_messages_panel().wait_for_message(pinned_text).close()

        with step(f'{member.name} leaves {community.name}'):
            main_screen.left_panel.open_community_context_menu(
                community.name).open_leave_community_popup().confirm_action()
            assert driver.waitFor(
                lambda: community.name not in main_screen.left_panel.communities(),
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            ), f'{community.name} should not be in the left panel after leave'

        with step(f'{member.name} rejoins {community.name}'):
            join_community_from_invite(main_screen, owner.name, member.password, community.name)

        with step(f'{member.name} still sees {pinned_text} in the pins panel after rejoin'):
            main_screen.left_panel.open_community(community.name)
            MessagesScreen().tool_bar.open_pinned_messages_panel().wait_for_message(pinned_text).close()
