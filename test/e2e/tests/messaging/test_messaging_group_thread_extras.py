import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomUser
from gui.main_window import MainWindow
from helpers.chat_helper import close_activity_center_if_visible
from helpers.group_chat_helper import open_group_chat, setup_three_user_group_chat, three_user_group_name
from helpers.thread_helper import (
    ThreadPanel,
    mute_open_thread,
    open_thread_from_list,
    rename_open_thread,
    start_thread_from_message,
    thread_parent_message_literal,
    thread_title_from_parent_message,
    unfollow_open_thread,
    unmute_open_thread,
    wait_for_chat_header,
    wait_for_thread_list_row,
)
from scripts.utils.generators import random_text_message


@pytest.mark.threads
@pytest.mark.spec('SC-THRD-01')
@pytest.mark.spec('SC-THRD-03')
@pytest.mark.spec('SC-THRD-06')
@pytest.mark.spec('SC-THRD-12')
def test_messaging_group_thread_create_reply_and_rename(multiple_instances):
    user_one, user_two, user_three = RandomUser(), RandomUser(), RandomUser()
    parent_message = thread_parent_message_literal()
    reply_message = random_text_message()
    thread_title = thread_title_from_parent_message(parent_message)
    renamed_title = f'Thread-{random_text_message()[:18]}'
    group_name = three_user_group_name(user_two, user_three)
    main_window, thread_panel = MainWindow(), ThreadPanel()

    with multiple_instances() as aut_one, multiple_instances() as aut_two, multiple_instances() as aut_three:
        setup_three_user_group_chat(aut_one, aut_two, aut_three, main_window, user_one, user_two, user_three)

        with step(f'{user_one.name} posts the parent message'):
            messages_screen = main_window.left_panel.open_messages_screen()
            messages_screen.left_panel.click_chat_by_name(group_name)
            messages_screen.group_chat.send_message_to_group_chat(parent_message)
            main_window.minimize()

        with step(f'{user_two.name} starts a thread, replies, and renames it'):
            messages_screen = open_group_chat(aut_two, main_window, group_name)
            start_thread_from_message(messages_screen, parent_message, reply_message, thread_panel)
            wait_for_thread_list_row(messages_screen, thread_title, True)
            open_thread_from_list(messages_screen, thread_title)
            rename_open_thread(renamed_title)
            wait_for_thread_list_row(messages_screen, renamed_title, True)
            main_window.minimize()

        with step(f'{user_one.name} sees the renamed thread'):
            messages_screen = open_group_chat(aut_one, main_window, group_name)
            wait_for_thread_list_row(messages_screen, renamed_title, True)
            assert messages_screen.chat.find_message_by_text(parent_message, 0).has_thread_card()
            open_thread_from_list(messages_screen, renamed_title)
            messages_screen.chat.find_message_by_text(reply_message, 0)


@pytest.mark.threads
@pytest.mark.spec('SC-THRD-17')
@pytest.mark.spec('SC-THRD-18')
@pytest.mark.spec('SC-THRD-26')
@pytest.mark.spec('SC-THRD-27')
@pytest.mark.spec('SC-THRD-37')
def test_messaging_group_thread_mute_and_mention(multiple_instances):
    user_one, user_two, user_three = RandomUser(), RandomUser(), RandomUser()
    parent_message = thread_parent_message_literal()
    reply_message, muted_reply = random_text_message(), random_text_message()
    thread_title = thread_title_from_parent_message(parent_message)
    group_name = three_user_group_name(user_two, user_three)
    main_window, thread_panel = MainWindow(), ThreadPanel()

    with multiple_instances() as aut_one, multiple_instances() as aut_two, multiple_instances() as aut_three:
        setup_three_user_group_chat(aut_one, aut_two, aut_three, main_window, user_one, user_two, user_three)

        with step(f'{user_one.name} posts the parent message'):
            messages_screen = main_window.left_panel.open_messages_screen()
            messages_screen.left_panel.click_chat_by_name(group_name)
            messages_screen.group_chat.send_message_to_group_chat(parent_message)
            main_window.minimize()

        with step(f'{user_two.name} starts a muted thread'):
            messages_screen = open_group_chat(aut_two, main_window, group_name)
            start_thread_from_message(messages_screen, parent_message, reply_message, thread_panel)
            wait_for_thread_list_row(messages_screen, thread_title, True)
            open_thread_from_list(messages_screen, thread_title)
            mute_open_thread()
            messages_screen.left_panel.click_chat_by_name(group_name)
            messages_screen.left_panel.wait_until_row_muted(thread_title)
            main_window.minimize()

        with step(f'{user_one.name} sends an ordinary reply in the muted thread'):
            messages_screen = open_group_chat(aut_one, main_window, group_name)
            open_thread_from_list(messages_screen, thread_title)
            thread_panel.send_message(muted_reply)
            messages_screen.chat.find_message_by_text(muted_reply, 0)
            main_window.minimize()

        with step(f'{user_two.name} has no Activity Center entry and no badge for the muted reply'):
            messages_screen = open_group_chat(aut_two, main_window, group_name)

            def muted_reply_delivered():
                try:
                    parent = messages_screen.chat.find_message_by_text(parent_message, 0)
                    return parent.thread_card_preview() == muted_reply
                except (LookupError, RuntimeError):
                    return False

            assert driver.wait_until(
                muted_reply_delivered, configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000,
            ), 'Muted reply did not reach the thread card'
            assert messages_screen.left_panel.notifications_count(thread_title) == 0
            messages_screen.left_panel.wait_until_row_muted(thread_title)
            activity_center = main_window.left_panel.open_activity_center()
            activity_center.click_activity_center_button('All')
            with pytest.raises(TimeoutError):
                activity_center.find_notification(
                    muted_reply, 'content', timeout_sec=configs.timeouts.UI_LOAD_TIMEOUT_SEC,
                )
            close_activity_center_if_visible()
            main_window.minimize()

        with step(f'{user_one.name} mentions {user_two.name} in the thread'):
            messages_screen = open_group_chat(aut_one, main_window, group_name)
            open_thread_from_list(messages_screen, thread_title)
            thread_panel.send_mention(user_two.name)
            thread_panel.send_mention(user_three.name)
            main_window.minimize()

        with step(f'{user_two.name} opens the mention from Activity Center'):
            messages_screen = open_group_chat(aut_two, main_window, group_name)
            activity_center = main_window.left_panel.open_activity_center()
            activity_center.click_activity_center_button('Mentions')
            activity_center.open_notification_card(
                activity_center.find_notification(thread_title, 'tertiaryText'),
            )
            wait_for_chat_header(thread_title)
            messages_screen.chat.find_message_by_text(parent_message, 0)
            assert driver.wait_until(
                lambda: messages_screen.left_panel.notifications_count(thread_title) == 0,
                configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000,
            )

        with step(f'{user_two.name} unmutes the thread'):
            unmute_open_thread()
            close_activity_center_if_visible()
            main_window.left_panel.open_messages_screen().left_panel.click_chat_by_name(group_name)
            main_window.minimize()

        unmuted_reply = random_text_message()
        with step(f'{user_one.name} sends a reply after unmute'):
            messages_screen = open_group_chat(aut_one, main_window, group_name)
            open_thread_from_list(messages_screen, thread_title)
            thread_panel.send_message(unmuted_reply)
            main_window.minimize()

        with step(f'{user_two.name} sees a badge on the unmuted thread'):
            messages_screen = open_group_chat(aut_two, main_window, group_name)
            assert driver.wait_until(
                lambda: messages_screen.left_panel.notifications_count(thread_title) > 0,
                configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000,
            ), 'Unmuted thread row did not get a badge'
            assert not messages_screen.left_panel.row_is_muted(thread_title)

        with step(f'{user_three.name} sees the thread from the mention and can unfollow'):
            messages_screen = open_group_chat(aut_three, main_window, group_name)
            wait_for_thread_list_row(messages_screen, thread_title, True)
            open_thread_from_list(messages_screen, thread_title)
            unfollow_open_thread()
            wait_for_thread_list_row(messages_screen, thread_title, False)