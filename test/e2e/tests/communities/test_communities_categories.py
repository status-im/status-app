import allure
import pytest
import configs
import constants

from allure_commons._allure import step

from tests import test_data
from gui.components.context_menu import ContextMenu


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
