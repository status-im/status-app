import allure
import pytest
from allure_commons._allure import step

from constants import RandomCommunity
from gui.main_window import MainWindow


@pytest.mark.case(703226, 703233, 703234, 703235, 703227)
@pytest.mark.parametrize(
    'category_name, general_checkbox, channel_name, channel_description, channel_emoji, second_channel_name, '
    'second_channel_description, second_channel_emoji',
    [pytest.param('Category in general', True, 'Channel', 'Description', 'sunglasses', 'Second-channel',
                  'Description', 'sunglasses')])
@pytest.mark.critical
def test_create_edit_remove_community_category(main_screen: MainWindow, category_name, general_checkbox, channel_name,
                                 channel_description, channel_emoji, second_channel_name, second_channel_description,
                                 second_channel_emoji):
    with step('Create community and select it'):
        community = RandomCommunity()
        main_screen.left_panel.create_community(community_data=community)
        community_screen = main_screen.left_panel.open_community(community.name)

    with step('Create community category and verify that it displays correctly'):
        community_screen.create_category(category_name, general_checkbox)

    with step('Verify category'):
        community_screen.verify_category(category_name)

    with step('Create community channel inside category'):
        community_screen.left_panel.open_new_channel_popup_in_category().create(channel_name, channel_description,
                                                                                channel_emoji).save_create_button.click()

    with step('Create community channel outside of category'):
        community_screen.create_channel(second_channel_name, second_channel_description, second_channel_emoji)

    with step('Verify that selected channel is listed outside of category'):
        assert community_screen.left_panel.get_channel_or_category_index(second_channel_name) == 0

    with step('Open edit category popup'):
        category_popup = community_screen.edit_category()
        category_popup.enter_category_title("New category").click_checkbox_by_index(0)
        category_popup.save_button.click()

    with step('Verify that selected channel is now listed inside category'):
        assert community_screen.left_panel.get_channel_or_category_index(second_channel_name) == 3

    with step('Open edit category popup'):
        category_popup = community_screen.edit_category()
        category_popup.click_checkbox_by_index(2)
        category_popup.save_button.click()

    with step('Verify that selected channel is now listed outside of category'):
        assert community_screen.left_panel.get_channel_or_category_index(second_channel_name) == 0

    with step('Delete category'):
        community_screen.delete_category()

    with step('Verify category is not in the list'):
        assert category_name not in community_screen.left_panel.categories_items

    with step('Verify created channel and general channel are still in the list'):
        new_channel = community_screen.left_panel.get_channel_parameters(channel_name)
        general_channel = community_screen.left_panel.get_channel_parameters('general')
        assert new_channel in community_screen.left_panel.channels
        assert general_channel in community_screen.left_panel.channels