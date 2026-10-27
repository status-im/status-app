"""Helpers to create a 3-person group chat across multiple AUTs."""

from allure_commons._allure import step

import configs
import driver
from gui.screens.messages import MessagesScreen
from helpers.chat_helper import skip_message_backup_popup_if_visible
from helpers.multiple_instances_helper import (
    add_mutual_contact_via_activity_center,
    authorize_user_in_aut,
    switch_to_aut,
)


def three_user_group_name(user_two, user_three) -> str:
    return f'{user_two.name}&{user_three.name}'


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
    group_name = three_user_group_name(user_two, user_three)

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


def open_group_chat(aut, main_window, group_name: str) -> MessagesScreen:
    switch_to_aut(aut, main_window)
    skip_message_backup_popup_if_visible()
    messages_screen = main_window.left_panel.open_messages_screen()
    assert driver.wait_until(
        lambda: group_name in messages_screen.left_panel.get_chats_names,
        configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000,
    ), f'Group {group_name!r} not found in {messages_screen.left_panel.get_chats_names}'
    messages_screen.left_panel.click_chat_by_name(group_name)
    return messages_screen
