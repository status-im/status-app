import allure
import pytest
import configs
import constants

from allure_commons._allure import step

from constants import RandomCommunity
from tests import test_data
from gui.components.context_menu import ContextMenu
from gui.main_window import MainWindow
from helpers.chat_helper import skip_message_backup_popup_if_visible


@pytest.mark.case(703272, 703273, 703274)
@pytest.mark.communities
@pytest.mark.parametrize('user_data', [configs.testpath.TEST_USER_DATA / 'member'])
@pytest.mark.parametrize('user_account', [constants.user.community_member])
def test_member_role_cannot_add_edit_or_delete_category(main_screen, user_data, user_account):

    with step('Choose community user is not owner of'):
        community_screen = main_screen.left_panel.open_community('Community with 2 users')

    with step('Verify that member cannot add category'):
        if community_screen.left_panel._channel_or_category_button.exists:
            test_data.error.append("Create channel or category button is present")
        if community_screen.left_panel._create_category_button.is_visible:
            test_data.error.append("Create category button is visible")

    with step('Verify that member cannot edit category'):
        with step('Right-click on category in the left navigation bar'):
            community_screen.left_panel.open_category_context_menu()
        with step('Verify that context menu does not appear'):
            assert not ContextMenu().is_visible
        with step('Verify that delete item is not present in more options context menu'):
            assert not community_screen.left_panel.open_more_options().edit_category_item.is_visible

    with step('Verify that member cannot delete category'):
        with step('Right-click on category in the left navigation bar'):
            community_screen.left_panel.open_category_context_menu()
        with step('Verify that context menu does not appear'):
            assert not ContextMenu().is_visible
        with step('Verify that delete item is not present in more options context menu'):
            assert not community_screen.left_panel.open_more_options().delete_category_item.is_visible


@pytest.mark.case(704622)
@pytest.mark.parametrize('category_name, general_checkbox',
                         [pytest.param('Category in general', True)])
def test_clicking_community_category(main_screen: MainWindow, category_name, general_checkbox):
    with step('Create community and select it'):
        community = RandomCommunity()
        main_screen.left_panel.create_community(community_data=community)
        community_screen = main_screen.left_panel.open_community(community.name)

    with step('Create community category and verify that it displays correctly'):
        community_screen.create_category(category_name, general_checkbox)
        community_screen.verify_category(category_name)

    with step('Verify that general channel is listed inside category'):
        assert community_screen.left_panel.get_channel_or_category_index('general') == 1

    with step('Verify that general channel is visible and toggle button has down direction'):
        general_channel = community_screen.left_panel.get_channel_parameters('general')
        assert general_channel.visible
        assert community_screen.left_panel.get_arrow_icon_rotation_value(category_name) == 0

    with step('Click added category'):
        community_screen.left_panel.click_category(category_name)

    with step('Verify that general channel is not visible and toggle button has right direction'):
        general_channel = community_screen.left_panel.get_channel_parameters('general')
        assert community_screen.left_panel.get_arrow_icon_rotation_value(category_name) == 270

    with step(
            'Click open more options button and verify that toggle button has down direction'):
        community_screen.left_panel.open_more_options()
        # rotation should be 0 here, because we click arrow button before open more options, otherwise it doesn't see it
        assert community_screen.left_panel.get_arrow_icon_rotation_value(category_name) == 0

    with step('Click plus button and verify that toggle button has down direction'):
        community_screen.left_panel._add_channel_inside_category_item.click()
        assert community_screen.left_panel.get_arrow_icon_rotation_value(category_name) == 0
