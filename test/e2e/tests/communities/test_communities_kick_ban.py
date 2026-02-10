import time

import pytest
from allure_commons._allure import step

import driver
from constants import UserAccount, RandomUser, RandomCommunity, CommunityData
from constants.community import ToastMessages
from gui.screens.community import MembersListPanel
from helpers.chat_helper import skip_message_backup_popup_if_visible
from scripts.utils.generators import random_text_message
import configs.testpath
from gui.main_window import MainWindow
from helpers.multiple_instances_helper import switch_to_aut, authorize_user_in_aut, get_chat_key, send_contact_request_from_settings, accept_contact_request_from_settings


@pytest.mark.case(703252, 703252, 736991)
@pytest.mark.communities
# TODO: investigate the reason of failures on CI https://github.com/status-im/status-desktop/issues/19284
def test_community_admin_ban_kick_member_and_delete_message(multiple_instances):
    user_one: UserAccount = RandomUser()
    user_two: UserAccount = RandomUser()
    timeout = configs.timeouts.UI_LOAD_TIMEOUT_MSEC
    community: CommunityData = RandomCommunity()
    main_screen = MainWindow()

    with multiple_instances(user_data=None) as aut_one, multiple_instances(user_data=None) as aut_two:
        with step(f'Launch multiple instances with authorized users {user_one.name} and {user_two.name}'):
            for aut, account in zip([aut_one, aut_two], [user_one, user_two]):
                authorize_user_in_aut(aut, main_screen, account)

        with step(f'User {user_two.name}, get chat key'):
            chat_key = get_chat_key(aut_two, main_screen)
            main_screen.minimize()

        with step(f'User {user_one.name}, send contact request to {user_two.name}'):
            send_contact_request_from_settings(aut_one, main_screen, chat_key, f'Hello {user_two.name}')
            main_screen.minimize()

        with step(f'User {user_two.name}, accept contact request from {user_one.name}'):
            accept_contact_request_from_settings(aut_two, main_screen, user_one.name)

        with step(f'User {user_two.name}, create community and invite {user_one.name}'):
            main_screen.left_panel.create_community(community_data=community)
            community_screen = main_screen.left_panel.open_community(community.name)
            add_members = community_screen.left_panel.open_add_members_popup()
            add_members.invite([user_one.name], message=random_text_message())
            main_screen.minimize()


        with step(f'User {user_one.name}, accept invitation from {user_two.name}'):
            switch_to_aut(aut_one, main_screen)
            messages_view = main_screen.left_panel.open_messages_screen()
            skip_message_backup_popup_if_visible()
            assert driver.waitFor(lambda: user_two.name in messages_view.left_panel.get_chats_names,
                                  10000)
            chat = messages_view.left_panel.click_chat_by_name(user_two.name)
            community_screen = chat.click_community_invite(community.name, 0)

        with step(f'User {user_one.name}, verify welcome community popup'):
            welcome_popup = community_screen.left_panel.open_welcome_community_popup()
            assert community.name in welcome_popup.title
            assert community.introduction == welcome_popup.intro
            welcome_popup.join().authenticate(user_one.password)
            assert driver.waitFor(lambda: not community_screen.left_panel.is_join_community_visible,
                                  10000), 'Join community button not hidden'
            main_screen.minimize()

        with step(f'User {user_two.name}, ban {user_one.name} from the community'):
            switch_to_aut(aut_two, main_screen)
            community_setting = community_screen.left_panel.open_community_settings()
            members = community_setting.left_panel.open_members()
            members.ban_member(user_one.name).confirm_banning()

        with step('Check toast message about banned member'):
            toast_messages = main_screen.wait_for_toast_notifications()
            assert user_one.name + ToastMessages.BANNED_USER_TOAST.value + community.name in toast_messages, \
                f"{user_one.name + ToastMessages.BANNED_USER_TOAST.value + community.name} is not found in {toast_messages}"

        with step(f'User {user_two.name}, does not see {user_one.name} in members list'):
            members_list = community_screen.right_panel.members
            assert driver.waitFor(lambda: user_one.name not in members_list, timeout)

        with step(f'User {user_two.name}, see {user_one.name} in banned members list'):
            community_screen.right_panel.click_banned_button()
            assert driver.waitFor(lambda: user_one.name not in members_list, timeout)
            main_screen.minimize()

        with step(f'User {user_one.name} tries to join community when being banned by {user_two.name}'):
            switch_to_aut(aut_one, main_screen)
            chat = messages_view.left_panel.click_chat_by_name(user_two.name)
            banned_community_screen = chat.open_banned_community(community.name, 0)
            assert banned_community_screen.community_banned_member_panel.is_visible
            assert banned_community_screen.banned_title() == f"You've been banned from {community.name}"
            main_screen.left_panel.open_community_context_menu(community.name).leave_community_option.click()
            # TODO: think of better check here assert not main_screen.left_panel.communities()
            main_screen.minimize()


        with step(f'User {user_two.name}, unban {user_one.name} in banned members list'):
            switch_to_aut(aut_two, main_screen)
            members.unban_member(user_one.name)
            # toast_messages = main_screen.wait_for_toast_notifications()
            # assert user_one.name + ToastMessages.UNBANNED_USER_TOAST.value + community.name in toast_messages, \
            #     f"{user_one.name + ToastMessages.UNBANNED_USER_TOAST.value + community.name} is not found in {toast_messages}"
            main_screen.minimize()

        with step(f'User {user_one.name} joins community again'):
            switch_to_aut(aut_one, main_screen)
            chat1 = messages_view.left_panel.click_chat_by_name(user_two.name)
            community_screen = chat1.open_banned_community(community.name, 0)
            # toast_messages = main_screen.wait_for_toast_notifications()
            # assert ToastMessages.UNBANNED_USER_CONFIRM.value + community.name in toast_messages, \
            #     f"{ToastMessages.UNBANNED_USER_CONFIRM.value} is not present in {toast_messages}"
            main_screen.left_panel.open_community_context_menu(community.name).leave_community_option.click()

            messages_view1 = main_screen.left_panel.open_messages_screen()
            chat = messages_view1.left_panel.click_chat_by_name(user_two.name)
            time.sleep(1)
            community_screen = chat.click_community_invite(community.name, 0)

            welcome_popup = community_screen.left_panel.open_welcome_community_popup()
            welcome_popup.join().authenticate(user_one.password)
            assert driver.waitFor(lambda: not community_screen.left_panel.is_join_community_visible,
                              10000), 'Join community button not hidden'
            main_screen.minimize()

        with step(f'User {user_two.name}, kick {user_one.name} from the community'):
            switch_to_aut(aut_two, main_screen)
            MembersListPanel().click_all_members_button()
            kick_popup = members.open_kick_member_popup(user_one.name)
            kick_popup.confirm_kicking()

        with step('Check toast message about kicked member'):
            toast_messages = main_screen.wait_for_toast_notifications()
            assert user_one.name + ToastMessages.KICKED_USER_TOAST.value + community.name in toast_messages, \
                f"{user_one.name + ToastMessages.KICKED_USER_TOAST.value} is not found in  {toast_messages}"

        with step(f'User {user_two.name}, does not see {user_one.name} in members list'):
            assert driver.waitFor(lambda: user_one.name not in community_screen.right_panel.members, timeout)
            main_screen.minimize()

        with step(f'User {user_one.name} can rejoin community after being kicked'):
            switch_to_aut(aut_one, main_screen)
            messages_view = main_screen.left_panel.open_messages_screen()
            chat = messages_view.left_panel.click_chat_by_name(user_two.name)
            community_screen = chat.click_community_invite(community.name, 0)
            welcome_popup = community_screen.left_panel.open_welcome_community_popup()
            welcome_popup.join().authenticate(user_one.password)
            assert driver.waitFor(lambda: not community_screen.left_panel.is_join_community_visible,
                                  10000), 'Join community button not hidden'
