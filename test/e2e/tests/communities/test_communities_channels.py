import random
import string
import time

import allure
import pytest
from allure_commons._allure import step

import configs
import constants
import driver
from constants import UserAccount, RandomCommunity
from constants.dock_buttons import DockButtons
from gui.main_window import MainWindow
from gui.screens.messages import MessagesScreen
from scripts.utils.parsers import remove_tags


@pytest.mark.case(703049, 703050, 703051)
@pytest.mark.communities
@pytest.mark.parametrize(
    'channel_name, channel_description, channel_emoji, channel_emoji_image, channel_color, new_channel_name, '
    'new_channel_description, new_channel_emoji',
    [('Channel', 'Description', 'sunglasses', None, '#4360df', 'New-channel', 'New channel description', 'thumbsup')])
def test_create_edit_remove_community_channel(main_screen, channel_name, channel_description, channel_emoji,
                                              channel_emoji_image,
                                              channel_color, new_channel_name, new_channel_description,
                                              new_channel_emoji):
    with step('Create community and select it'):
        community = RandomCommunity()
        main_screen.left_panel.create_community(community_data=community)
        community_screen = main_screen.left_panel.open_community(community.name)

    with step('Verify General channel is present for recently created community'):
        community_screen.verify_channel(
            'general',
            'General channel for the community',
            None
        )

    with step('Create new channel for recently created community'):
        community_screen.create_channel(channel_name, channel_description, channel_emoji)

    with step('Verify channel'):
        community_screen.verify_channel(
            channel_name,
            channel_description,
            channel_emoji_image
        )

    with step('Edit channel'):
        community_screen.edit_channel(channel_name, new_channel_name, new_channel_description, new_channel_emoji)

    with step('Verify edited channel details are correct in channels list'):
        channel = community_screen.left_panel.get_channel_parameters(new_channel_name)
        assert channel.name == new_channel_name

    with step('Verify edited channel details are correct in community toolbar'):
        assert driver.waitFor(lambda: community_screen.tool_bar.channel_name == new_channel_name,
                              configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        assert community_screen.tool_bar.channel_description == new_channel_description
        assert community_screen.tool_bar.channel_emoji == '👍 '
        # assert community_screen.tool_bar.channel_color == channel_color

    with step('Delete channel'):
        community_screen.delete_channel(new_channel_name)

    with step('Delete general channel'):
        community_screen.delete_channel('general')

    with step('Verify channels list is empty'):
        assert len(community_screen.left_panel.channels) == 0


@pytest.mark.case(703269, 703270, 703271)
@pytest.mark.parametrize('user_data', [configs.testpath.TEST_USER_DATA / 'member'])
@pytest.mark.parametrize('user_account', [constants.user.community_member])
def test_member_role_cannot_add_edit_and_delete_channels(main_screen: MainWindow):

    with step('Choose community user is not owner of'):
        community_screen = main_screen.left_panel.open_community('Community with 2 users')
    with step('Verify that member cannot add new channel'):
        with step('Verify that create channel or category button is not present'):
            assert not community_screen.left_panel.does_create_channel_or_category_button_exist()
        with step('Verify that add channel button is not present'):
            assert not community_screen.left_panel.is_add_channels_button_visible()

    with step('Verify that member cannot edit and delete channel'):
        with step('Right-click on general channel in the left navigation bar'):
            general_channel_context_menu = community_screen.left_panel.open_general_channel_context_menu()
        with step('Verify that edit item is not present in channel context menu'):
            assert general_channel_context_menu.edit_channel_from_context.exists is False, \
                f'Edit channel option is present when it should not'
        with step('Verify that delete item is not present in channel context menu'):
            assert general_channel_context_menu.delete_channel_from_context.exists is False, \
                f'Delete channel option is present when it should not'

        with step('Open context menu from the tool bar'):
            more_options = community_screen.tool_bar.open_more_options_dropdown()
        with step('Verify that edit item is not present in context menu'):
            assert more_options.edit_channel_from_context.exists is False, \
                f'Edit channel option is present when it should not'
        with step('Verify that delete item is not present in context menu'):
            assert more_options.delete_channel_context_item.exists is False, \
                f'Delete channel option is present when it should not'


@pytest.mark.case(737079)
@pytest.mark.parametrize('user_data_one, user_data_two, asset, amount, channel_description', [
    (configs.testpath.TEST_USER_DATA / 'squisher', configs.testpath.TEST_USER_DATA / 'athletic', 'ETH', '10',
     'description')
])
@pytest.mark.skip(reason='tests with user data are not working')
def test_member_cannot_see_hidden_channel(multiple_instances, user_data_one, user_data_two, asset, amount,
                                          channel_description):
    user_one: UserAccount = constants.user_account_one
    user_two: UserAccount = constants.user_account_two
    channel_name = ''.join(random.choices(string.ascii_letters + string.digits, k=8))
    main_screen = MainWindow()

    with (multiple_instances(user_data=user_data_one) as aut_one, multiple_instances(
            user_data=user_data_two) as aut_two):
        with step(f'Launch multiple instances with authorized users {user_one.name} and {user_two.name}'):
            for aut, account in zip([aut_one, aut_two], [user_one, user_two]):
                aut.attach()
                main_screen.wait_until_appears(configs.timeouts.APP_LOAD_TIMEOUT_MSEC).prepare()
                main_screen.authorize_user(account)

        with step(f'User {user_two.name}, select non-restricted channel and can send message'):
            aut_two.attach()
            main_screen.prepare()
            community_screen = main_screen.left_panel.open_community('Community with 2 users')

        with step(f'User {user_two.name}, create hidden channel, verify that it is in the list'):
            create_channel_popup = community_screen.left_panel.open_create_channel_popup().create(channel_name,
                                                                                              channel_description,
                                                                                              emoji=None)
            permission_popup = create_channel_popup.add_permission()
            time.sleep(3)
            permission_popup.set_who_holds_asset_and_amount(asset, amount)
            permission_popup.set_is_allowed_to('viewOnly')
            permission_popup.switch_hide_permission_checkbox(True)
            permission_popup.create_permission()
            create_channel_popup.save_create_button.click()
            channel = community_screen.left_panel.get_channel_parameters(channel_name)
            assert driver.waitFor(lambda: channel in community_screen.left_panel.channels,
                                  configs.timeouts.UI_LOAD_TIMEOUT_MSEC)

        with step(f'User {user_one.name}, cannot see hidden channel in the list'):
            aut_one.attach()
            main_screen.prepare()
            assert driver.waitFor(lambda: channel not in community_screen.left_panel.channels,
                                  configs.timeouts.UI_LOAD_TIMEOUT_MSEC)


@pytest.mark.case(737070, 737074)
@pytest.mark.parametrize('user_data_one, user_data_two, channel_name, channel_description', [
    (configs.testpath.TEST_USER_DATA / 'squisher', configs.testpath.TEST_USER_DATA / 'athletic', 'Channel_',
     'Description')
])
@pytest.mark.skip(reason='tests with user data are not working')
def test_view_and_post_in_non_restricted_channel(multiple_instances, user_data_one, user_data_two, channel_name,
                                                 channel_description):
    user_one: UserAccount = constants.user_account_one
    user_two: UserAccount = constants.user_account_two
    channel_name = channel_name + ''.join(random.choices(string.ascii_letters + string.digits, k=5))
    main_screen = MainWindow()

    with multiple_instances(user_data=user_data_one) as aut_one, multiple_instances(user_data=user_data_two) as aut_two:
        with step(f'Launch multiple instances with authorized users {user_one.name} and {user_two.name}'):
            for aut, account in zip([aut_one, aut_two], [user_one, user_two]):
                aut.attach()
                main_screen.wait_until_appears(configs.timeouts.APP_LOAD_TIMEOUT_MSEC).prepare()
                main_screen.authorize_user(account)

        with step(f'User {user_two.name}, select non-restricted channel and can send message'):
            aut_two.attach()
            main_screen.prepare()
            community_screen = main_screen.left_panel.open_community('Community with 2 users')
            community_screen.create_channel(channel_name, channel_description, emoji=None)
            community_screen.left_panel.select_channel(channel_name)
            messages_screen = MessagesScreen()
            message_text = "Hi"
            messages_screen.group_chat.send_message_to_group_chat(message_text)

        with step(
                f'User {user_one.name}, select non-restricted channel, verify that can view other messages and also '
                f'can send message'):
            aut_one.attach()
            main_screen.prepare()
            community_screen = main_screen.left_panel.open_community('Community with 2 users')
            community_screen.left_panel.select_channel(channel_name)
            messages_screen = MessagesScreen()
            message_object = messages_screen.chat.messages(0)[0]
            assert 'Hi' in str(message_object.text), f"Message text is not found in last message"
            message_text = "Hi hi"
            messages_screen.group_chat.send_message_to_group_chat(message_text)

        with step(f'User {user_two.name}, verify that can see sent by member message'):
            aut_two.attach()
            main_screen.prepare()
            message_object = messages_screen.chat.messages(0)[0]
            assert driver.waitFor(lambda: 'Hi hi' in remove_tags(str(message_object.text)),
                                  configs.timeouts.UI_LOAD_TIMEOUT_MSEC), f"Message text is not found in last message"

            community_screen.delete_channel(channel_name)
