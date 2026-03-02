import allure
import configs.testpath
import configs.timeouts
import pytest
from allure_commons._allure import step
from constants import UserAccount, RandomUser
from constants.messaging import Messaging
from gui.main_window import MainWindow
from helpers.chat_helper import skip_message_backup_popup_if_visible


@pytest.mark.case(704610)
@pytest.mark.settings_messaging
def test_messaging_settings_rejecting_request(multiple_instances):
    user_one: UserAccount = RandomUser()
    user_two: UserAccount = RandomUser()
    main_window = MainWindow()

    with multiple_instances(user_data=None) as aut_one, multiple_instances(user_data=None) as aut_two:
        with step(f'Launch multiple instances with authorized users {user_one.name} and {user_two.name}'):
            for aut, account in zip([aut_one, aut_two], [user_one, user_two]):
                aut.attach()
                main_window.wait_until_appears(configs.timeouts.APP_LOAD_TIMEOUT_MSEC).prepare()
                main_window.authorize_user(account)

        with step(f'User {user_two.name}, get chat key'):
            aut_two.attach()
            main_window.prepare()
            online_identifier = main_window.left_panel.open_online_identifier()
            profile_popup = online_identifier.open_profile_popup_from_online_identifier()
            chat_key = profile_popup.copy_chat_key
            main_window.left_panel.click()

        with step(f'User {user_one.name}, send contact request to {user_two.name} in chat section'):
            aut_one.attach()
            main_window.prepare()
            messages_screen = main_window.left_panel.open_messages_screen()
            skip_message_backup_popup_if_visible()
            contact_request_popup = messages_screen.left_panel.start_chat().create_chat_with_chat_key(chat_key)
            contact_request_popup.send(f'Hello {user_two.name}')

        with step(f'Verify that contact request from user {user_two.name} was received and reject contact request'):
            aut_two.attach()
            main_window.prepare()
            settings = main_window.left_panel.open_settings()
            messaging_settings = settings.left_panel.open_messaging_settings()
            contacts_settings = messaging_settings.open_contacts_settings()
            contacts_settings.open_pending_requests()
            contacts_settings.reject_contact_request(user_one.name)

        with step(f'Verify that contacts list of {user_two.name} is empty in messaging settings'):
            contacts_settings = main_window.left_panel.open_settings().left_panel.open_messaging_settings().open_contacts_settings()
            contacts_settings.open_contacts()
            assert str(contacts_settings.no_friends_item_text) == Messaging.NO_FRIENDS_ITEM.value
            assert contacts_settings.invite_friends_button.is_visible

        with step(f'Verify that contacts list of {user_one.name} is empty in messaging settings'):
            aut_one.attach()
            main_window.prepare()
            contacts_settings = main_window.left_panel.open_settings().left_panel.open_messaging_settings().open_contacts_settings()
            contacts_settings.open_contacts()
            assert str(contacts_settings.no_friends_item_text) == Messaging.NO_FRIENDS_ITEM.value
            assert contacts_settings.invite_friends_button.is_visible

        with step(f'User {user_one.name}, send contact request to {user_two.name} again via messaging settings'):
            aut_one.attach()
            main_window.prepare()
            settings = main_window.left_panel.open_settings()
            messaging_settings = settings.left_panel.open_messaging_settings()
            contacts_settings = messaging_settings.open_contacts_settings()
            contact_request_popup = contacts_settings.open_contact_request_form()
            contact_request_popup.send(chat_key, f'Hello again {user_two.name}')

        with step(f'Verify that pending requests tab is not active for {user_two.name}'):
            aut_two.attach()
            main_window.prepare()
            messaging_settings = main_window.left_panel.open_settings().left_panel.open_messaging_settings()
            assert messaging_settings.pending_requests_count == 0
