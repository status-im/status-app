import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomCommunity, RandomUser, UserAccount
from constants.community import Channel
from gui.main_window import MainWindow
from gui.screens.messages import MessagesScreen
from helpers.chat_helper import skip_message_backup_popup_if_visible
from helpers.multiple_instances_helper import (
    accept_contact_request_from_settings,
    authorize_user_in_aut,
    get_chat_key,
    send_contact_request_from_settings,
    switch_to_aut,
)
from helpers.thread_helper import (
    ThreadPanel,
    thread_parent_message_literal,
    thread_title_from_parent_message,
    wait_for_chat_header,
    wait_for_notifications_count,
    wait_until_reply_not_in_main_chat,
)
from scripts.utils.generators import random_text_message

CHANNEL_NAME = Channel.DEFAULT_CHANNEL_NAME.value


@pytest.mark.communities
@pytest.mark.threads
def test_community_channel_thread_reply_edit_navigation_and_badge(multiple_instances):
    user_one: UserAccount = RandomUser()
    user_two: UserAccount = RandomUser()
    community = RandomCommunity()
    parent_message = thread_parent_message_literal()
    reply_message = random_text_message()
    edited_reply = f'{reply_message}-edited'
    thread_title = thread_title_from_parent_message(parent_message)

    main_screen = MainWindow()
    thread_panel = ThreadPanel()

    with multiple_instances() as aut_one, multiple_instances() as aut_two:
        with step(f'Launch instances for {user_one.name} and {user_two.name}'):
            for aut, account in zip([aut_one, aut_two], [user_one, user_two]):
                authorize_user_in_aut(aut, main_screen, account)

        with step(f'{user_two.name} gets chat key'):
            chat_key = get_chat_key(aut_two, main_screen)
            main_screen.minimize()

        with step(f'{user_one.name} sends a contact request'):
            send_contact_request_from_settings(
                aut_one, main_screen, chat_key, f'Hello {user_two.name}',
            )
            main_screen.minimize()

        with step(f'{user_two.name} accepts the contact request'):
            accept_contact_request_from_settings(aut_two, main_screen, user_one.name)

        with step(f'{user_two.name} creates a community and invites {user_one.name}'):
            main_screen.left_panel.create_community(community_data=community)
            community_screen = main_screen.left_panel.open_community(community.name)
            add_members = community_screen.left_panel.open_add_members_popup()
            add_members.invite([user_one.name], message=random_text_message())
            main_screen.minimize()

        with step(f'{user_one.name} joins the community'):
            switch_to_aut(aut_one, main_screen)
            skip_message_backup_popup_if_visible()
            assert driver.waitFor(
                lambda: main_screen.left_panel.messages_button.exists,
                configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
            ), 'Messages nav button did not appear'
            messages_view = main_screen.left_panel.open_messages_screen()
            chat = messages_view.left_panel.click_chat_by_name(user_two.name)
            community_screen = chat.click_community_invite_message(0)
            community_screen.left_panel.wait_for_name(community.name)
            welcome_popup = community_screen.left_panel.open_welcome_community_popup()
            welcome_popup.join().authenticate(user_one.password)
            assert driver.waitFor(
                lambda: not community_screen.left_panel.is_join_community_visible,
                configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
            ), 'Join community button stayed visible'
            main_screen.minimize()

        with step(f'{user_two.name} posts the parent message in {CHANNEL_NAME}'):
            switch_to_aut(aut_two, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            community_screen.left_panel.select_channel(CHANNEL_NAME)
            messages_screen = MessagesScreen()
            messages_screen.group_chat.send_message_to_group_chat(parent_message)
            main_screen.minimize()

        with step(f'{user_two.name} starts a thread and replies in the side panel'):
            switch_to_aut(aut_two, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            community_screen.left_panel.select_channel(CHANNEL_NAME)
            messages_screen = MessagesScreen()
            parent = messages_screen.chat.find_message_by_text(parent_message, 0)
            parent.open_context_menu().create_thread()
            assert driver.waitFor(
                lambda: parent.has_thread_card(),
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            ), 'Thread card did not appear after Create Thread'
            parent.open_thread_from_card()
            assert thread_panel.is_open, 'Thread side panel did not open from the thread card'
            thread_panel.send_message(reply_message)
            thread_panel.find_message(reply_message)
            thread_panel.close()
            wait_until_reply_not_in_main_chat(messages_screen.chat, reply_message)
            main_screen.minimize()

        with step(f'{user_two.name} edits the reply inside the thread panel'):
            switch_to_aut(aut_two, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            community_screen.left_panel.select_channel(CHANNEL_NAME)
            messages_screen = MessagesScreen()
            parent = messages_screen.chat.find_message_by_text(parent_message, 0)
            parent.open_thread_from_card()
            assert thread_panel.is_open
            reply = thread_panel.find_message(reply_message)
            reply.open_context_menu().edit_message(edited_reply, thread_panel=True)
            thread_panel.find_message(edited_reply)
            thread_panel.close()
            main_screen.minimize()

        with step('Thread card, side panel, list row, and main-panel navigation'):
            switch_to_aut(aut_two, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            community_screen.left_panel.select_channel(CHANNEL_NAME)
            messages_screen = MessagesScreen()
            parent = messages_screen.chat.find_message_by_text(parent_message, 0)
            assert parent.has_thread_card(), 'Thread card missing under parent message'
            parent.open_thread_from_card()
            assert thread_panel.is_open, 'Card click did not open thread side panel'
            thread_panel.close()
            assert driver.waitFor(
                lambda: thread_title in [channel.name for channel in community_screen.left_panel.channels],
                configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000,
            ), f'Thread row {thread_title!r} not in community chat list'
            community_screen.left_panel.select_channel(thread_title)
            wait_for_chat_header(thread_title)
            reply = messages_screen.chat.find_message_by_text(edited_reply, 0)
            assert not reply.open_context_menu().is_pin_action_visible(), (
                'Pin must not be available on messages inside a thread'
            )
            main_screen.minimize()

        with step(f'{user_one.name} sees the thread badge without channel unread growth'):
            switch_to_aut(aut_one, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            community_screen.left_panel.select_channel(CHANNEL_NAME)
            messages_screen = MessagesScreen()
            parent = messages_screen.chat.find_message_by_text(parent_message, 0)
            assert parent.has_thread_card()
            channel_badge = community_screen.left_panel.notifications_count(CHANNEL_NAME)
            wait_for_notifications_count(
                community_screen.left_panel.chatListItemDropAreaItem.real_name,
                thread_title,
                1,
            )
            assert community_screen.left_panel.notifications_count(CHANNEL_NAME) == channel_badge, (
                'Channel list badge should not increase when activity is only inside the thread'
            )

        with step(f'{user_one.name} opens reply from Activity Center into the thread'):
            activity_center = main_screen.left_panel.open_activity_center()
            activity_center.replies_button.click()
            reply_card = activity_center.find_notification(thread_title, 'tertiaryText')
            activity_center.open_notification_card(reply_card)
            messages_screen = MessagesScreen()
            wait_for_chat_header(thread_title)
            messages_screen.chat.find_message_by_text(edited_reply, 0)
            assert driver.waitFor(
                lambda: community_screen.left_panel.notifications_count(thread_title) == 0,
                configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000,
            ), 'Thread list badge should clear after opening the thread from Activity Center'
