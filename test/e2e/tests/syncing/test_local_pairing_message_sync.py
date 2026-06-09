import pyperclip
import pytest
from allure_commons._allure import step

import configs
import configs.testpath
import driver
from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from constants.user import message_sync_user, message_sync_contact
from gui.components.splash_screen import SplashScreen
from gui.main_window import MainWindow
from gui.screens.onboarding import (
    OnboardingBiometricsView,
    OnboardingProfileSyncedView,
    OnboardingWelcomeToStatusView,
    SyncResultView,
)
from helpers.chat_helper import get_visible_message_texts, skip_message_backup_popup_if_visible
from helpers.multiple_instances_helper import switch_to_aut
from scripts.utils.generators import random_text_message

from . import marks

pytestmark = marks

MESSAGE_SYNC_USER_DATA = configs.testpath.TEST_USER_DATA / 'message_sync_user'
MESSAGE_SYNC_TIMEOUT_MSEC = 120_000


@pytest.mark.parametrize('user_data', [MESSAGE_SYNC_USER_DATA])
@pytest.mark.parametrize('user_account', [message_sync_user])
@pytest.mark.smoke
@pytest.mark.timeout(timeout=360)
def test_local_pairing_with_message_sync(multiple_instances, user_data, user_account):
    contact_name = message_sync_contact.name
    main_window = MainWindow()

    with multiple_instances(user_data=user_data) as aut_primary:
        with step(f'Log in as {user_account.name} and send a message in chat with {contact_name}'):
            aut_primary.attach()
            main_window.prepare()
            main_window.authorize_user(user_account)

            messages_screen = main_window.left_panel.open_messages_screen()
            skip_message_backup_popup_if_visible()
            assert driver.waitFor(
                lambda: contact_name in messages_screen.left_panel.get_chats_names,
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC), f'Chat with {contact_name} not found'
            chat = messages_screen.left_panel.click_chat_by_name(contact_name)

            new_message = random_text_message()
            messages_screen.group_chat.send_message_to_group_chat(new_message)
            chat.find_message_by_text(new_message, 0)
            primary_messages = get_visible_message_texts(chat)

        with step('Generate sync code with message sync enabled'):
            home = main_window.left_panel.open_home_screen()
            sync_settings_view = home.open_syncing_settings_from_grid()
            setup_syncing = sync_settings_view.open_sync_new_device_popup(
                user_account.password, message_sync=True)
            setup_syncing.wait_until_enabled()
            sync_code = setup_syncing.syncing_code

        with multiple_instances(user_data=None) as aut_paired:
            with step(f'Pair fresh instance {aut_paired.aut_id} using sync code'):
                aut_paired.attach()
                main_window.prepare()
                welcome_screen = OnboardingWelcomeToStatusView().wait_until_appears()
                sync_view = welcome_screen.sync_existing_user()

                sync_start = sync_view.open_enter_sync_code_form()
                pyperclip.copy(sync_code)
                sync_start.click_paste_button()
                sync_start.continue_button.click()
                profile_syncing_view = OnboardingProfileSyncedView().wait_until_appears()
                assert profile_syncing_view.log_in_button.wait_until_appears(timeout_msec=15000)
                profile_syncing_view.log_in_button.click()
                if configs.system.get_platform() == 'Darwin':
                    OnboardingBiometricsView().maybe_later()
                SplashScreen().wait_until_hidden(APP_LOAD_TIMEOUT_MSEC)
                skip_message_backup_popup_if_visible()

            with step(f'Confirm pairing on primary instance {aut_primary.aut_id}'):
                switch_to_aut(aut_primary, main_window)
                sync_device_found = SyncResultView()
                assert driver.waitFor(
                    lambda: 'Device synced!' in sync_device_found.device_synced_notifications,
                    23000)
                sync_device_found.done_button.click()

            with step(f'Verify messages in chat with {contact_name} on paired instance'):
                switch_to_aut(aut_paired, main_window)
                messages_screen = main_window.left_panel.open_messages_screen()
                skip_message_backup_popup_if_visible()
                assert driver.waitFor(
                    lambda: contact_name in messages_screen.left_panel.get_chats_names,
                    MESSAGE_SYNC_TIMEOUT_MSEC), f'Chat with {contact_name} not synced to paired device'

                chat = messages_screen.left_panel.click_chat_by_name(contact_name)
                assert driver.waitFor(
                    lambda: set(get_visible_message_texts(chat)) == set(primary_messages),
                    MESSAGE_SYNC_TIMEOUT_MSEC), (
                    f'Messages on paired device do not match primary.\n'
                    f'Primary: {primary_messages}\n'
                    f'Paired: {get_visible_message_texts(chat)}')
