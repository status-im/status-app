import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomUser, UserAccount
from gui.main_window import MainWindow
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
    delete_open_thread,
    follow_open_thread,
    thread_parent_message_literal,
    thread_title_from_parent_message,
    unfollow_open_thread,
    wait_for_chat_header,
    wait_for_thread_list_row,
)
from scripts.utils.generators import random_text_message


@pytest.mark.threads
def test_messaging_1x1_thread_follow_and_delete(multiple_instances):
    user_one: UserAccount = RandomUser()
    user_two: UserAccount = RandomUser()
    parent_message = thread_parent_message_literal()
    reply_message = random_text_message()
    thread_title = thread_title_from_parent_message(parent_message)
    main_window = MainWindow()
    thread_panel = ThreadPanel()

    with multiple_instances() as aut_one, multiple_instances() as aut_two:
        with step(f'Launch instances for {user_one.name} and {user_two.name}'):
            for aut, account in zip([aut_one, aut_two], [user_one, user_two]):
                authorize_user_in_aut(aut, main_window, account)

        with step(f'{user_two.name} gets chat key'):
            chat_key = get_chat_key(aut_two, main_window)
            main_window.minimize()

        with step(f'{user_one.name} sends a contact request'):
            send_contact_request_from_settings(
                aut_one, main_window, chat_key, f'Hello {user_two.name}',
            )
            main_window.minimize()

        with step(f'{user_two.name} accepts the contact request'):
            accept_contact_request_from_settings(aut_two, main_window, user_one.name)
            skip_message_backup_popup_if_visible()
            main_window.minimize()

        with step(f'{user_one.name} sends the parent message'):
            switch_to_aut(aut_one, main_window)
            skip_message_backup_popup_if_visible()
            assert driver.waitFor(
                lambda: main_window.left_panel.messages_button.exists,
                configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
            ), 'Messages nav button did not appear'
            messages_screen = main_window.left_panel.open_messages_screen()
            assert driver.waitFor(
                lambda: user_two.name in messages_screen.left_panel.get_chats_names,
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            ), f'Chat with {user_two.name!r} not found'
            messages_screen.left_panel.click_chat_by_name(user_two.name)
            messages_screen.group_chat.send_message_to_group_chat(parent_message)
            main_window.minimize()

        with step(f'{user_two.name} starts a thread and replies'):
            switch_to_aut(aut_two, main_window)
            skip_message_backup_popup_if_visible()
            messages_screen = main_window.left_panel.open_messages_screen()
            messages_screen.left_panel.click_chat_by_name(user_one.name)
            parent = messages_screen.chat.find_message_by_text(parent_message, 0)
            parent.open_context_menu().create_thread()
            assert thread_panel.is_open
            thread_panel.send_message(reply_message)
            thread_panel.find_message(reply_message)
            thread_panel.close()
            wait_for_thread_list_row(messages_screen, thread_title, True)

        with step('Unfollow hides the thread row and returns to the contact chat'):
            messages_screen.left_panel.click_chat_by_name(thread_title)
            wait_for_chat_header(thread_title)
            unfollow_open_thread()
            wait_for_chat_header(user_one.name)
            messages_screen.chat.find_message_by_text(parent_message, 0)
            wait_for_thread_list_row(messages_screen, thread_title, False)

        with step('Follow from the thread card brings the row back'):
            parent = messages_screen.chat.find_message_by_text(parent_message, 0)
            parent.open_thread_from_card()
            assert thread_panel.is_open
            follow_open_thread()
            thread_panel.close()
            wait_for_thread_list_row(messages_screen, thread_title, True)

        with step('Delete removes the thread row and keeps the parent message'):
            messages_screen.left_panel.click_chat_by_name(thread_title)
            wait_for_chat_header(thread_title)
            delete_open_thread()
            wait_for_chat_header(user_one.name)
            messages_screen.chat.find_message_by_text(parent_message, 0)
            wait_for_thread_list_row(messages_screen, thread_title, False)
