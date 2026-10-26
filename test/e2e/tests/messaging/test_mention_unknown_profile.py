import pytest
from allure_commons._allure import step

import configs
import driver
from constants import UserAccount, RandomUser
from gui.main_window import MainWindow
from gui.screens.messages import MessagesScreen
from helpers.chat_helper import (
    latest_message_text,
    skip_intro_if_visible,
    skip_message_backup_popup_if_visible,
)
from helpers.multiple_instances_helper import (
    add_mutual_contact_via_activity_center,
    authorize_user_in_aut,
    switch_to_aut,
)


def mention_shows_display_name(chat, expected_name: str) -> bool:
    text = latest_message_text(chat)
    return expected_name in text and '0x' not in text


@pytest.mark.messaging
def test_mention_of_unknown_user_resolves_to_real_name(multiple_instances):
    user_a: UserAccount = RandomUser()
    user_b: UserAccount = RandomUser()
    user_c: UserAccount = RandomUser()
    main_window = MainWindow()
    messages_screen = MessagesScreen()
    profile_timeout = configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000

    with \
            multiple_instances(user_data=None) as aut_a, \
            multiple_instances(user_data=None) as aut_b, \
            multiple_instances(user_data=None) as aut_c:
        with step(f'Launch users {user_a.name}, {user_b.name}, {user_c.name}'):
            for aut, account in zip((aut_a, aut_b, aut_c), (user_a, user_b, user_c)):
                authorize_user_in_aut(aut, main_window, account)

        add_mutual_contact_via_activity_center(aut_a, aut_b, main_window, user_a, user_b)
        add_mutual_contact_via_activity_center(aut_a, aut_c, main_window, user_a, user_c)

        with step(f'User {user_a.name} mentions {user_c.name} in 1:1 with {user_b.name}'):
            switch_to_aut(aut_a, main_window)
            skip_message_backup_popup_if_visible()
            messages_screen = main_window.left_panel.open_messages_screen()
            messages_screen.left_panel.click_chat_by_name(user_b.name)
            messages_screen.group_chat.wait_until_appears()
            messages_screen.group_chat.send_message_mentioning(user_c.name)
            assert driver.waitFor(
                lambda: mention_shows_display_name(messages_screen.chat, user_c.name),
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            ), (
                f'Control: mention of {user_c.name} not resolved for the sender '
                f'{user_a.name}: {latest_message_text(messages_screen.chat)!r}'
            )
            main_window.minimize()

        with step(
            f'User {user_b.name} sees mention of unknown {user_c.name} '
            f'resolve to the real name (#22947)'
        ):
            switch_to_aut(aut_b, main_window)
            skip_intro_if_visible()
            skip_message_backup_popup_if_visible()
            messages_screen = main_window.left_panel.open_messages_screen()
            messages_screen.left_panel.click_chat_by_name(user_a.name)
            messages_screen.group_chat.wait_until_appears()
            assert driver.waitFor(
                lambda: mention_shows_display_name(messages_screen.chat, user_c.name),
                profile_timeout,
            ), (
                f'Mention of unknown user stayed a generated name for {user_b.name}; '
                f'expected {user_c.name!r}, got {latest_message_text(messages_screen.chat)!r}'
            )
