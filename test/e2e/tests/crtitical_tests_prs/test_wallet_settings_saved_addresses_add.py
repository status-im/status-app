import random
import string

import allure
import pytest
from allure_commons._allure import step


import configs
import driver
from gui.main_window import MainWindow
from helpers.settings_helper import open_wallet_settings


@pytest.mark.parametrize('name, address',
                         [
                             pytest.param(
                                 ''.join(random.choices(string.ascii_letters, k=24)),
                                 '0x8397bc3c5a60a1883174f722403d63a8833312b7')
                         ])
@pytest.mark.case(704620, 738787)
@pytest.mark.critical
@pytest.mark.smoke
def test_wallet_settings_add_saved_address(main_screen: MainWindow, address: str, name: str):
    with (step('Open wallet settings - Saved addresses section')):
        settings_saved_addresses = open_wallet_settings(main_screen).open_saved_addresses()

    with step('Click Add new address button and open add saved address popup'):
        add_saved_address_popup = settings_saved_addresses.open_add_edit_saved_address_popup()

    with step('Fill in the form and preferred networks and add the address'):
        add_saved_address_popup.add_saved_address(name, address)

    with step('Verify recently added saved address is present in the list'):
        assert driver.waitFor(
            lambda: name in settings_saved_addresses.get_saved_address_names_list(),
            configs.timeouts.LOADING_LIST_TIMEOUT_MSEC), f'Address: {name} not found'

    with step('Verify toast message when adding saved address'):
        messages = main_screen.wait_for_toast_notifications()
        assert f'{name} successfully added to your saved addresses' in messages, \
            f"Toast message about adding saved address is not correct or not present. \
                Current list of messages: {messages}"

    with step('Remove saved address'):
        settings_saved_addresses.delete_saved_address_with_confirmation(name)

    with step('Verify recently added saved address is present in the list'):
        assert driver.waitFor(
            lambda: name not in settings_saved_addresses.get_saved_address_names_list(),
            configs.timeouts.LOADING_LIST_TIMEOUT_MSEC), f'Address: {name} was not deleted'
