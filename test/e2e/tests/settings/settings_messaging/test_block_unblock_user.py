import time

import allure
import pytest
from allure_commons._allure import step

import driver
from constants import UserAccount, RandomUser
from constants.community import BlockPopupWarnings, ToastMessages
from gui.main_window import MainWindow
import configs
from gui.screens.messages import ToolBar
from helpers.multiple_instances_helper import authorize_user_in_aut, get_chat_key, switch_to_aut


@pytest.mark.case(738772, 738772)
@pytest.mark.smoke
@pytest.mark.settings_messaging
# TODO: add step when blocked user sends a message
def test_block_and_unblock_user_from_settings_and_profile(multiple_instances):
    user_one: UserAccount = RandomUser()
    user_two: UserAccount = RandomUser()
    timeout = configs.timeouts.UI_LOAD_TIMEOUT_MSEC
    main_window = MainWindow()

    with \
            multiple_instances(user_data=None) as aut_one, \
            multiple_instances(user_data=None) as aut_two:
        with step(f'Launch multiple instances with new users {user_one.name}, {user_two.name}'):
            for aut, account in zip([aut_one, aut_two], [user_one, user_two]):
                authorize_user_in_aut(aut, main_window, account)

            with step(f'User {user_two.name}, get chat key'):
                user_2_chat_key = get_chat_key(aut_two, main_window)
                main_window.minimize()

            with step(f'User {user_one.name}, send contact request to {user_two.name}'):
                switch_to_aut(aut_one, main_window)
                settings = main_window.left_panel.open_settings()
                contact_request_form = settings.left_panel.open_messaging_settings().open_contacts_settings().open_contact_request_form()
                contact_request_form.send(user_2_chat_key, f'Hello {user_two.name}')
                main_window.minimize()

            with step(f'User {user_two.name}, accept contact request from {user_one.name} via activity center'):
                switch_to_aut(aut_two, main_window)
                activity_center = main_window.left_panel.open_activity_center()
                request = activity_center.find_contact_request_in_list(user_one.name, timeout)
                activity_center.accept_contact_request(request)
                main_window.left_panel.click()
                main_window.minimize()

        with step(
                f'User {user_one.name}, block contact {user_two.name} from user profile and verify button Block '
                f'appeared'):
            aut_one.attach()
            main_window.prepare()
            contacts_settings = \
                main_window.left_panel.open_settings().left_panel.open_messaging_settings().open_contacts_settings()
            assert driver.waitFor(
                lambda: user_two.name in [str(contact) for contact in contacts_settings.contact_items], timeout)
            block_popup = contacts_settings.open_contacts().open_more_options_popup(user_two.name).block_user()
            warning_text = \
                BlockPopupWarnings.BLOCK_WARNING_PART_1.value + user_two.name + BlockPopupWarnings.BLOCK_WARNING_PART_2.value
            assert driver.waitFor(lambda: block_popup.get_warning_text() == warning_text,
                                  timeout), f'Text is incorrect, actual text is {block_popup.get_warning_text()}, ' \
                                            f'correct text is {warning_text}'
            block_popup.block_user_button.click()

        with step('Check toast message about blocked member'):
            toast_messages = main_window.wait_for_toast_notifications()
            message_1 = ToastMessages.REMOVED_CONTACT_TOAST.value
            message_2 = user_two.name + ToastMessages.BLOCKED_USER_TOAST.value
            assert driver.waitFor(lambda: message_1 in toast_messages,
                                  timeout), f"Toast message {message_1} is incorrect, current message is {toast_messages}"
            assert driver.waitFor(lambda: message_2 in toast_messages,
                                  timeout), f"Toast message {message_2} is incorrect, current message is {toast_messages}"

        with step(f'User {user_two.name} does not see {user_one.name} in contacts list'):
            aut_two.attach()
            main_window.prepare()
            contacts_settings = main_window.left_panel.open_settings().left_panel.open_messaging_settings().open_contacts_settings()
            assert contacts_settings.invite_friends_button.wait_until_appears().is_visible

        with step(
                f'User {user_one.name}, unblock {user_two.name} from contact settings and verify {user_two.name} was '
                f'removed from blocked list'):
            aut_one.attach()
            main_window.prepare()
            contacts_settings = main_window.left_panel.open_settings().left_panel.open_messaging_settings().open_contacts_settings()
            unblock_popup = contacts_settings.open_blocked().open_more_options_popup(user_two.name).unblock_user()
            warning_text = \
                BlockPopupWarnings.UNBLOCK_TEXT_1.value + user_two.name + \
                BlockPopupWarnings.UNBLOCK_TEXT_2.value + user_two.name + \
                BlockPopupWarnings.UNBLOCK_TEXT_3.value

            assert driver.waitFor(lambda: unblock_popup.get_warning_text() == warning_text,
                                  timeout), f'Text is incorrect, actual text is {unblock_popup.get_warning_text()}, ' \
                                            f'correct text is {warning_text}'
            unblock_popup.unblock_user_button.click()

        with step('Check toast message about unblocked member'):
            toast_messages = main_window.wait_for_toast_notifications()
            message_2 = user_two.name + ToastMessages.UNBLOCKED_USER_TOAST.value
            assert driver.waitFor(lambda: message_2 in toast_messages,
                                  timeout), f"Toast message {message_2} is incorrect, current message is {toast_messages}"
