"""Helpers to set up a community #general channel for benchmark tests."""

import time

import driver
from allure_commons._allure import step

import configs
from constants import RandomCommunity
from constants.community import Channel
from gui.screens.messages import MessagesScreen
from helpers.chat_helper import skip_message_backup_popup_if_visible
from helpers.multiple_instances_helper import (
    add_mutual_contact_via_activity_center,
    authorize_user_in_aut,
    switch_to_aut,
)
from scripts.utils.generators import random_text_message


def _open_general_channel(main_window, community_name: str):
    community_screen = main_window.left_panel.open_community(community_name)
    community_screen.wait_for_content_loaded()
    community_screen.left_panel.select_channel(Channel.DEFAULT_CHANNEL_NAME.value)
    community_screen.wait_for_content_loaded()
    return community_screen


def _incoming_album_arrived(chat) -> bool:
    try:
        for item in chat._iter_message_objects(None, scroll_to_recent=True):
            try:
                if bool(getattr(item, 'amISender', False)):
                    continue
                if str(getattr(item, 'messageImage', '') or ''):
                    return True
                if int(getattr(item, 'albumCount', 0) or 0) > 0:
                    return True
            except (RuntimeError, AttributeError, TypeError, ValueError):
                continue
    except (RuntimeError, AttributeError, LookupError):
        return False
    return False


def setup_community_general_channel(
        aut_owner,
        aut_member,
        main_window,
        owner,
        member,
) -> tuple:
    with step(f'Launch users {owner.name} and {member.name}'):
        for aut, account in zip((aut_owner, aut_member), (owner, member)):
            authorize_user_in_aut(aut, main_window, account)

    add_mutual_contact_via_activity_center(aut_owner, aut_member, main_window, owner, member)
    community = RandomCommunity()

    with step(f'User {owner.name}, create community and invite {member.name}'):
        switch_to_aut(aut_owner, main_window)
        main_window.left_panel.create_community(community_data=community)
        community_screen = main_window.left_panel.open_community(community.name)
        community_screen.left_panel.open_add_members_popup().invite(
            [member.name],
            message=random_text_message(),
        )

    with step(f'User {member.name}, accept community invitation from {owner.name}'):
        switch_to_aut(aut_member, main_window)
        chat = main_window.left_panel.open_messages_screen().left_panel.click_chat_by_name(owner.name)
        skip_message_backup_popup_if_visible()
        community_screen = chat.click_community_invite_message()
        community_screen.left_panel.wait_for_name(
            community.name,
            configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
        )
        community_screen.left_panel.open_welcome_community_popup().join().authenticate(member.password)
        assert driver.waitFor(
            lambda: not community_screen.left_panel.is_join_community_visible,
            configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
        ), 'Join community button not hidden'
        # Keep this AUT on #general (not minimized) so SDS delivery ACKs can complete.
        _open_general_channel(main_window, community.name)

    with step(f'User {owner.name}, open community #general channel'):
        switch_to_aut(aut_owner, main_window)
        _open_general_channel(main_window, community.name)
        messages_screen = MessagesScreen()
        messages_screen.group_chat.wait_until_appears()

    def wake_member_on_general(message_text=None):
        # Community Delivered is SDS: the sender only flips after an incoming
        # community message whose bloom filter/causal history includes theirs.
        with step(f'User {member.name}, receive the message and send an SDS delivery ACK'):
            switch_to_aut(aut_member, main_window)
            member_screen = MessagesScreen()
            member_screen.group_chat.wait_until_appears()
            member_chat = member_screen.chat
            if message_text:
                member_chat.find_message_by_text(message_text)
            else:
                assert driver.waitFor(
                    lambda: _incoming_album_arrived(member_chat),
                    configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000,
                ), 'Member did not receive the community image album'
            ack = f'e2e-bench-ack-{int(time.time() * 1000)}'
            member_screen.group_chat.send_message_to_group_chat(ack)
            member_chat.wait_until_outgoing_sent(ack)
            switch_to_aut(aut_owner, main_window)
            messages_screen.group_chat.wait_until_appears()

    return messages_screen, wake_member_on_general
