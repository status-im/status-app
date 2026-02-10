import pytest
from allure_commons._allure import step

from constants import permission_data_member, RandomCommunity
from constants.community import LimitWarnings
from gui.main_window import MainWindow


@pytest.mark.case(739309)
@pytest.mark.communities
def test_add_5_member_role_permissions(main_screen: MainWindow):

    with step('Create community and select it'):
        community = RandomCommunity()
        main_screen.left_panel.create_community(community_data=community)
        community_screen = main_screen.left_panel.open_community(community.name)

    with step('Open add new permission page'):
        community_setting = community_screen.left_panel.open_community_settings()
        permissions_intro_view = community_setting.left_panel.open_permissions()

    with step('Create new permission'):
        permission_data = permission_data_member
        for index, item in enumerate(permission_data):
            permissions_settings = permissions_intro_view.add_new_permission()
            permissions_settings.set_who_holds_checkbox_state(permission_data[index]['checkbox_state'])
            permissions_settings.set_who_holds_asset_and_amount(permission_data[index]['first_asset'],
                                                                permission_data[index]['amount'])
            permissions_settings.set_is_allowed_to(permission_data[index]['allowed_to'])
            permissions_settings.create_permission()

        # with step('Created permission is displayed on permission page'):
        #     if permission_data[index]['asset_title'] is not False:
        #         assert driver.waitFor(
        #             lambda: permission_data[index]['asset_title'] in permissions_settings.get_who_holds_tags_titles(),
        #             configs.timeouts.UI_LOAD_TIMEOUT_MSEC)

    with step('Open form to create 6th member role permission and validate it is not allowed'):
        extra_permission_data = {
            'checkbox_state': True,
            'first_asset': 'Status',
            'amount': '100',
            'allowed_to': 'becomeMember'
        }
        permissions_settings = permissions_intro_view.add_new_permission()
        permissions_settings.set_who_holds_checkbox_state(extra_permission_data['checkbox_state'])
        permissions_settings.set_who_holds_asset_and_amount(extra_permission_data['first_asset'],
                                                            extra_permission_data['amount'])
        permissions_settings.set_is_allowed_to(extra_permission_data['allowed_to'])

        assert permissions_settings.warning_panel.exists, 'Member role limit warning is not displayed'
        assert permissions_settings.get_warning_text() \
               == LimitWarnings.MEMBER_ROLE_LIMIT_WARNING.value, \
            f'Warning text about become a member limit reached is incorrect'
