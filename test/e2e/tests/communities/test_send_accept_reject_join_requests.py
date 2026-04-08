import time

import pytest
from allure_commons._allure import step

import driver
from gui.components.profile_popup import ProfilePopupFromMembers
from gui.components.remove_contact_popup import RemoveContactPopup
from gui.main_window import MainWindow
from helpers.chat_helper import skip_message_backup_popup_if_visible
from helpers.multiple_instances_helper import authorize_user_in_aut, get_chat_key, switch_to_aut
from scripts.utils.generators import random_text_message
import configs
from constants import UserAccount, RandomUser, RandomCommunity


@pytest.mark.smoke
@pytest.mark.communities
def test_send_accept_reject_join_requests(multiple_instances):
    user_one: UserAccount = RandomUser()
    user_two: UserAccount = RandomUser()
    user_three: UserAccount = RandomUser()
    main_screen = MainWindow()

    with (multiple_instances(user_data=None) as aut_one, multiple_instances(
            user_data=None) as aut_two, multiple_instances(user_data=None) as aut_three):
        with step(f'Launch multiple instances with authorized users {user_one.name}, {user_two.name}, {user_three}'):
            for aut, account in zip([aut_one, aut_two, aut_three], [user_one, user_two, user_three]):
                authorize_user_in_aut(aut, main_screen, account)

        with step(f'User {user_two.name}, get chat key'):
            switch_to_aut(aut_two, main_screen)
            chat_key = get_chat_key(aut_two, main_screen)
            main_screen.minimize()

        with step(f'User {user_one.name}, send contact request to {user_two.name}'):
            switch_to_aut(aut_one, main_screen)
            settings = main_screen.left_panel.open_settings()
            contact_request_popup = settings.left_panel.open_messaging_settings().open_contacts_settings().open_contact_request_form()
            contact_request_popup.send(chat_key, f'Hello {user_two.name}')
            main_screen.minimize()

        with step(
                f'User {user_two.name}, accept contact request from {user_one.name} and send contact request to {user_three.name} '):
            switch_to_aut(aut_two, main_screen)
            settings = main_screen.left_panel.open_settings()
            messaging_settings = settings.left_panel.open_messaging_settings()
            contacts_settings = messaging_settings.open_contacts_settings()
            contacts_settings.accept_contact_request(user_one.name)
            main_screen.minimize()

        with step(f'User {user_three.name}, get chat key'):
            switch_to_aut(aut_three, main_screen)
            chat_key = get_chat_key(aut_three, main_screen)
            main_screen.minimize()

        with step(f'User {user_two.name}, send contact request to {user_three.name}'):
            switch_to_aut(aut_two, main_screen)
            skip_message_backup_popup_if_visible()
            settings = main_screen.left_panel.open_settings()
            contact_request_popup = settings.left_panel.open_messaging_settings().open_contacts_settings().open_contact_request_form()
            contact_request_popup.send(chat_key, f'Hello {user_three.name}')
            main_screen.minimize()

        with step(f'User {user_three.name}, accept contact request from {user_two.name}'):
            switch_to_aut(aut_three, main_screen)
            settings = main_screen.left_panel.open_settings()
            messaging_settings = settings.left_panel.open_messaging_settings()
            contacts_settings = messaging_settings.open_contacts_settings()
            contacts_settings.accept_contact_request(user_two.name)
            main_screen.minimize()

        with step(f'User {user_two.name}, creates community with request to join and invites {user_one.name} and {user_three.name}'):
            switch_to_aut(aut_two, main_screen)

            with step('Create community with request to join required and select it'):
                community = RandomCommunity(request_to_join=True)
                main_screen.left_panel.create_community(community_data=community)
                community_screen = main_screen.left_panel.open_community(community.name)

            add_popup = community_screen.left_panel.open_add_members_popup()
            add_popup.invite([user_one.name, user_three.name], message=random_text_message())
            main_screen.minimize()

        with step(f'User {user_three.name}, request to join community from {user_two.name} invite'):
            switch_to_aut(aut_three, main_screen)
            messages_view = main_screen.left_panel.open_messages_screen()
            chat = messages_view.left_panel.click_chat_by_name(user_two.name)
            community_screen = chat.click_community_invite(community.name, 0)

        with step(f'User {user_three.name}, verify welcome community popup and request to join'):
            welcome_popup = community_screen.left_panel.open_welcome_community_popup()
            assert community.name in welcome_popup.title
            assert community.introduction == welcome_popup.intro
            welcome_popup.join().authenticate(user_three.password)
            main_screen.minimize()


        with step(f'User {user_one.name}, request to join community from {user_two.name} invite'):
            switch_to_aut(aut_one, main_screen)
            messages_view = main_screen.left_panel.open_messages_screen()
            skip_message_backup_popup_if_visible()
            chat = messages_view.left_panel.click_chat_by_name(user_two.name)
            community_screen = chat.click_community_invite(community.name, 0)

        with step(f'User {user_one.name}, verify welcome community popup and request to join'):
            welcome_popup = community_screen.left_panel.open_welcome_community_popup()
            assert community.name in welcome_popup.title
            assert community.introduction == welcome_popup.intro
            welcome_popup.join().authenticate(user_one.password)
            main_screen.minimize()

        with step(f'User {user_two.name}, open Manage Community - Members - Pending Requests'):
            switch_to_aut(aut_two, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            community_settings = community_screen.left_panel.open_community_settings()
            members_view = community_settings.left_panel.open_members()

        with step(f'User {user_two.name}, decline {user_three.name} pending request on hover'):
            pending_tab = members_view.open_pending_requests_tab()
            pending_tab.decline_pending_request(user_three.name)
            time.sleep(1)  # To allow list to be rebuilt
            assert user_three.name not in pending_tab.members_names, \
                f'{user_three.name} should not be in community members after decline'

        with step(f'Verify {user_three.name} did not join the community'):
            members_view.open_all_members_tab()
            time.sleep(1)  # Allow tab switch to complete before next action (CI timing)
            assert user_three.name not in members_view.members_names, \
                f'{user_three.name} should not be in community members after decline'

        with step(f'User {user_two.name}, accept {user_one.name} pending request'):
            time.sleep(0.5)  # Ensure tab bar is stable before opening Pending Requests (CI timing)
            pending_tab = members_view.open_pending_requests_tab()
            pending_tab.accept_pending_request(user_one.name)
            time.sleep(1) # To allow list to be rebuilt
            members_view.open_all_members_tab()
            assert user_one.name in members_view.members_names, \
                f'{user_one.name} should be in community members after accept'
            main_screen.minimize()

        with step(f'User {user_one.name}, verify that community appeared and user is a member'):
            switch_to_aut(aut_one, main_screen)
            community_screen = main_screen.left_panel.open_community(community.name)
            assert driver.waitFor(
                lambda: not community_screen.left_panel.is_join_community_visible,
                configs.timeouts.LOADING_LIST_TIMEOUT_MSEC
            ), f'{user_one.name} should see the community as a member (Join/Request button should be hidden)'

        with step(f'User {user_one.name} remove {user_two.name} from contacts from user profile'):
            community_screen = main_screen.left_panel.open_community(community.name)
            profile_popup = community_screen.right_panel.click_member(user_two.name)
            profile_popup.choose_context_menu_option('Remove contact')
            RemoveContactPopup().wait_until_appears().remove_contact_button.click()

        with step(f'User {user_one.name}, send contact request to {user_two.name} from user profile again'):
            profile_popup.send_request().send(f'Hello {user_two.name}')
            profile_popup = ProfilePopupFromMembers().wait_until_appears()
            assert profile_popup.exists, 'Profile popup should reappear after sending contact request'

