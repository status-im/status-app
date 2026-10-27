import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomUser, UserAccount
from ext.test_files.base64_images import BASE_64_IMAGE_JPEG
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
)
from scripts.utils.generators import random_text_message


@pytest.mark.critical
@pytest.mark.smoke
@pytest.mark.threads
def test_messaging_1x1_thread_side_panel_list_and_image(multiple_instances):
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

        with step(f'{user_one.name} opens the 1:1 chat'):
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

        with step('Start thread from message and reply in side panel'):
            messages_screen.group_chat.send_message_to_group_chat(parent_message)
            parent = messages_screen.chat.find_message_by_text(parent_message, 0)
            parent.open_context_menu().create_thread()
            assert thread_panel.is_open
            thread_panel.send_message(reply_message)
            thread_panel.find_message(reply_message)
            thread_panel.close()

        with step('Thread row under contact opens thread in main panel'):
            assert driver.waitFor(
                lambda: thread_title in messages_screen.left_panel.get_chats_names,
                configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000,
            ), f'Thread row {thread_title!r} missing under contact in Messages list'
            messages_screen.left_panel.click_chat_by_name(thread_title)
            wait_for_chat_header(thread_title)
            messages_screen.chat.find_message_by_text(reply_message, 0)

        with step('Image in thread main panel stays out of contact chat'):
            timeout_msec = configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000
            thread_panel.send_image(str(BASE_64_IMAGE_JPEG))
            assert driver.waitFor(
                lambda: (
                    messages_screen.chat.messages(0)[0].image_message is not None
                    and messages_screen.chat.messages(0)[0].image_message.visible
                ),
                timeout_msec,
            ), 'Image not found in thread main panel'
            messages_screen.left_panel.click_chat_by_name(user_two.name)
            wait_for_chat_header(user_two.name)

            def contact_chat_has_no_image() -> bool:
                for message in messages_screen.chat.messages(0):
                    image = message.image_message
                    if image is not None and image.visible:
                        return False
                return True

            assert driver.waitFor(contact_chat_has_no_image, timeout_msec), (
                'Image from thread appeared in contact chat transcript'
            )
