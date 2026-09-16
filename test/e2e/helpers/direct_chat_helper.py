"""Helpers to set up a 1-on-1 chat across two AUTs."""

from allure_commons._allure import step

from gui.screens.messages import MessagesScreen
from helpers.chat_helper import skip_message_backup_popup_if_visible
from helpers.multiple_instances_helper import (
    add_mutual_contact_via_activity_center,
    authorize_user_in_aut,
    switch_to_aut,
)


def setup_two_user_direct_chat(
        aut_one,
        aut_two,
        main_window,
        user_one,
        user_two,
) -> MessagesScreen:
    with step(f'Launch users {user_one.name} and {user_two.name}'):
        for aut, account in zip((aut_one, aut_two), (user_one, user_two)):
            authorize_user_in_aut(aut, main_window, account)

    add_mutual_contact_via_activity_center(aut_one, aut_two, main_window, user_one, user_two)

    with step(f'User {user_one.name}, open 1-on-1 chat with {user_two.name}'):
        switch_to_aut(aut_one, main_window)
        messages_screen = main_window.left_panel.open_messages_screen()
        skip_message_backup_popup_if_visible()
        messages_screen.left_panel.click_chat_by_name(user_two.name)
        messages_screen.group_chat.wait_until_appears()

    return messages_screen
