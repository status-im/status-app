import random

import allure
import pytest
from allure_commons._allure import step

import configs
import driver
from configs import get_platform
from constants import permission_data, RandomCommunity
from constants.community import ToastMessages, PermissionsElements
from gui.components.changes_detected_popup import PermissionsChangesDetectedToastMessage
from gui.main_window import MainWindow
from gui.screens.community_settings import PermissionsIntroView


@pytest.mark.case(703632, 705014, 705016)
@pytest.mark.critical
# TODO: https://github.com/status-im/status-desktop/issues/19285
def test_add_edit_remove_duplicate_permissions(main_screen: MainWindow):
    with step('Create community and select it'):
        community = RandomCommunity()
        main_screen.left_panel.create_community(community_data=community)
        community_screen = main_screen.left_panel.open_community(community.name)

    with step('Open add new permission page'):
        community_setting = community_screen.left_panel.open_community_settings()
        permissions_intro_view = community_setting.left_panel.open_permissions()

    with step('Create new permission'):
        permission_set = random.choice(permission_data)
        permissions_settings = permissions_intro_view.add_new_permission()
        permissions_settings.set_who_holds_checkbox_state(permission_set['checkbox_state'])
        permissions_settings.set_who_holds_asset_and_amount(permission_set['first_asset'],
                                                            permission_set['amount'])
        permissions_settings.set_who_holds_asset_and_amount(permission_set['second_asset'],
                                                            permission_set['amount'])
        permissions_settings.set_is_allowed_to(permission_set['allowed_to'])
        permissions_settings.set_in(permission_set['in_channel'])
        permissions_settings.create_permission()

    with step('Check toast message for permission creation'):
        toast_messages = main_screen.wait_for_toast_notifications()
        message = toast_messages[0]
        assert ToastMessages.CREATE_PERMISSION_TOAST.value in toast_messages, \
            f"Toast message is incorrect, current message is {message}"

    # TODO: that has to be brought back when token name and token amount representations are fixed

    # with step('Created permission is displayed on permission page'):
    #     if permission_set['asset_title'] is not False:
    #         assert driver.waitFor(
    #             lambda: permission_set['asset_title'] in permissions_settings.get_who_holds_tags_titles(),
    #             configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
    #     if permission_set['second_asset_title'] is not False:
    #         assert driver.waitFor(lambda: permission_set[
    #                                           'second_asset_title'] in permissions_settings.get_who_holds_tags_titles(),
    #                               configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
    #     if permission_set['allowed_to_title'] is not False:
    #         assert driver.waitFor(lambda: permission_set[
    #                                           'allowed_to_title'] in permissions_settings.get_is_allowed_tags_titles(),
    #                               configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
    #     if permission_set['in_channel'] is False:
    #         assert driver.waitFor(
    #             lambda: community.name in permissions_settings.get_in_community_in_channel_tags_titles(),
    #             configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
    #     if permission_set['in_channel']:
    #         assert driver.waitFor(lambda: permission_set[
    #                                           'in_channel'] in permissions_settings.get_in_community_in_channel_tags_titles(),
    #                               configs.timeouts.UI_LOAD_TIMEOUT_MSEC)

    with step('Edit permission'):
        edit_permission_view = permissions_intro_view.open_edit_permission_view()
        if permission_set['allowed_to'] is 'becomeAdmin' and permission_set['checkbox_state'] is True:
            permissions_settings.set_who_holds_checkbox_state(False)
        elif permission_set['checkbox_state'] is False:
            permissions_settings.set_allowed_to_from_permission('becomeMember')
        else:
            edit_permission_view.switch_hide_permission_checkbox(True)


    with step('Confirm changes and verify that permission was changed'):
        changes_popup = PermissionsChangesDetectedToastMessage().wait_until_appears()
        changes_popup.update_permission()
        if permission_set['allowed_to'] is 'becomeAdmin' and permission_set[
            'checkbox_state'] is True:
            if permission_set['asset_title'] is not False:
                assert driver.waitFor(lambda: permission_set[
                                                  'asset_title'] not in permissions_settings.get_who_holds_tags_titles(),
                                      configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
            if permission_set['second_asset_title'] is not False:
                assert driver.waitFor(
                    lambda: permission_set[
                                'second_asset_title'] not in permissions_settings.get_who_holds_tags_titles(),
                    configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        elif permission_set['checkbox_state'] is False:
            assert driver.waitFor(lambda: 'Become member' in permissions_settings.get_is_allowed_tags_titles(),
                                  configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        else:
            assert driver.waitFor(lambda: permissions_intro_view._hide_icon.is_visible,
                                  configs.timeouts.UI_LOAD_TIMEOUT_MSEC)

    with step('Check toast message for edited permission'):
        messages = main_screen.wait_for_toast_notifications()
        assert ToastMessages.UPDATE_PERMISSION_TOAST.value in messages, \
            f"Toast message is incorrect, current message is {message}"

    with step('Delete permission'):
        delete_pop_up = permissions_intro_view.click_delete_permission()
        delete_pop_up.confirm_delete_button.click()

    with step('Verify that permission was deleted'):
        assert driver.waitFor(lambda: PermissionsIntroView().is_visible)

    with step('Check toast message for deleted permission'):
        messages = main_screen.wait_for_toast_notifications()
        assert ToastMessages.DELETE_PERMISSION_TOAST.value in messages, \
            f"Toast message is incorrect, current message is {message}"

    with step('Create new permission'):
        new_permission_data = {
            'checkbox_state': True,
            'first_asset': 'ETH',
            'amount': '6',
            'allowed_to': 'becomeMember'
        }
        permissions_settings = permissions_intro_view.add_new_permission()
        permissions_settings.set_who_holds_checkbox_state(new_permission_data['checkbox_state'])
        permissions_settings.set_who_holds_asset_and_amount(new_permission_data['first_asset'],
                                                            new_permission_data['amount'])
        permissions_settings.set_is_allowed_to(new_permission_data['allowed_to'])
        permissions_settings.create_permission()

    with step('Duplicate created permission and verify correct duplicate warning appears'):
        permission_view = permissions_intro_view.click_duplicate_permission()
        assert permission_view.get_warning_text() == PermissionsElements.DUPLICATE_WARNING.value
        permissions_settings.set_who_holds_asset_and_amount('Aragon', '10')
        permissions_settings.create_permission()

    # TODO: that has to be brought back when token name and token amount representations are fixed

    # with step('Duplicated permission is displayed on permission page'):
    #     assert driver.waitFor(
    #         lambda: '10 ANT' in permissions_settings.get_who_holds_tags_titles(),
    #         configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
