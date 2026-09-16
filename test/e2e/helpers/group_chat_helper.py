"""Helpers to create a 3-person group chat across multiple AUTs."""

from allure_commons._allure import step

from gui.screens.messages import MessagesScreen
from helpers.chat_helper import skip_message_backup_popup_if_visible
from helpers.multiple_instances_helper import (
    add_mutual_contact_via_activity_center,
    authorize_user_in_aut,
    switch_to_aut,
)


def setup_three_user_group_chat(
        aut_one,
        aut_two,
        aut_three,
        main_window,
        user_one,
        user_two,
        user_three,
) -> MessagesScreen:
    with step(f'Launch users {user_one.name}, {user_two.name}, {user_three.name}'):
        for aut, account in zip(
                (aut_one, aut_two, aut_three),
                (user_one, user_two, user_three),
        ):
            authorize_user_in_aut(aut, main_window, account)

    add_mutual_contact_via_activity_center(aut_one, aut_two, main_window, user_one, user_two)
    add_mutual_contact_via_activity_center(aut_one, aut_three, main_window, user_one, user_three)

    members = [user_two.name, user_three.name]
    group_name = f'{user_two.name}&{user_three.name}'

    with step(f'User {user_one.name}, create group chat with {members}'):
        switch_to_aut(aut_one, main_window)
        main_window.left_panel.open_messages_screen()
        skip_message_backup_popup_if_visible()
        messages_screen = MessagesScreen()
        messages_screen.left_panel.start_chat().create_chat(members)
        assert messages_screen.group_chat.wait_until_appears().group_name == group_name
        actual_members = set(messages_screen.right_panel.members)
        assert {user_one.name, user_two.name, user_three.name} <= actual_members
        assert len(messages_screen.right_panel.members) == 3

    return messages_screen
