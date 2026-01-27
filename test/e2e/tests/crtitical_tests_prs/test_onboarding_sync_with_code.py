import time

import pyperclip
import pytest
from allure_commons._allure import step

import configs.testpath
import driver
from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from constants import UserAccount, RandomUser
from constants.syncing import SyncingSettings
from gui.components.splash_screen import SplashScreen
from gui.main_window import MainWindow
from gui.screens.onboarding import OnboardingWelcomeToStatusView, SyncResultView, OnboardingProfileSyncedView, \
    OnboardingBiometricsView


@pytest.mark.case(703592, 738760)
@pytest.mark.critical
@pytest.mark.smoke
def test_sync_devices_during_onboarding_change_settings_unpair(multiple_instances):
    user: UserAccount = RandomUser()
    main_window = MainWindow()

    with multiple_instances(user_data=None) as aut_one, multiple_instances(user_data=None) as aut_two:
        with step(f'Get syncing code in first instance {aut_one.aut_id}'):
            aut_one.attach()
            main_window.prepare()
            main_window.authorize_user(user)
            home = main_window.left_panel.open_home_screen()
            sync_settings_view = home.open_syncing_settings_from_grid()
            assert sync_settings_view.sync_new_device_instructions_header.text \
                   == SyncingSettings.SYNC_A_NEW_DEVICE_INSTRUCTIONS_HEADER.value, f"Sync a new device title is incorrect"

            assert sync_settings_view.sync_new_device_instructions_subtitle.text \
                   == SyncingSettings.SYNC_A_NEW_DEVICE_INSTRUCTIONS_SUBTITLE.value, f"Sync a new device subtitle is incorrect"

            setup_syncing = sync_settings_view.open_sync_new_device_popup(
                user.password)
            setup_syncing.wait_until_enabled()
            sync_code = setup_syncing.syncing_code

        with step('Verify sync code format is valid'):
            sync_code_fields = sync_code.split(':')
            assert sync_code_fields[0] == 'cs3'
            assert len(sync_code_fields) == 7

        with step(f'Open sync code form in second instance {aut_two.aut_id}'):
            aut_two.attach()
            main_window.prepare()
            welcome_screen = OnboardingWelcomeToStatusView().wait_until_appears()
            sync_view = welcome_screen.sync_existing_user()

        with step('Paste sync code on second instance and wait until device is synced'):
            sync_start = sync_view.open_enter_sync_code_form()
            pyperclip.copy(sync_code)
            sync_start.click_paste_button()
            sync_start.continue_button.click()
            profile_syncing_view = OnboardingProfileSyncedView().wait_until_appears()
            assert profile_syncing_view.log_in_button.wait_until_appears(timeout_msec=15000), \
                f'Log in button is not shown within 15 seconds'
            assert 'Profile synced' in str(
                profile_syncing_view.profile_synced_view_header.wait_until_appears().object.text), \
                f'Device is not synced'

        with step('Sign in to synced account'):
            profile_syncing_view.log_in_button.click()
            if configs.system.get_platform() == "Darwin":
                OnboardingBiometricsView().maybe_later()
            SplashScreen().wait_until_hidden(APP_LOAD_TIMEOUT_MSEC)

            with step('Verify user details are the same with user in first instance'):
                online_identifier = main_window.left_panel.open_online_identifier()
                assert online_identifier.get_user_name == user.name, \
                    f'Name in online identifier and display name do not match'
                main_window.left_panel.click()

        with step(f'Open first instance {aut_one.aut_id} and verify it is synced, click done'):
            aut_one.attach()
            main_window.prepare()
            sync_device_found = SyncResultView()
            assert driver.waitFor(
                lambda: 'Device synced!' in sync_device_found.device_synced_notifications, 23000)
            assert user.name in sync_device_found.device_synced_notifications
            sync_device_found.done_button.click()

        # TODO: https://github.com/status-im/status-desktop/issues/18680
        with step('Change Allow contact requests toggle state to OFF'):
            messaging_settings = main_window.left_panel.open_settings().left_panel.open_messaging_settings()
            time.sleep(2)  # allowing messages settings page to fully appear
            messaging_settings.switch_allow_contact_requests_toggle(False)
            time.sleep(2)  # wait for animation of the toggle to finish
            assert driver.waitFor(
                lambda: not messaging_settings.allow_contact_requests_toggle.object.checked,
                3000), f'Toggle did not change to OFF. Current state: {messaging_settings.allow_contact_requests_toggle.object.checked}'

        with step(f'Check that settings changes are reflected in second instance {aut_two.aut_id}'):
            aut_two.attach()
            main_window.prepare()
            msg_stngs = main_window.left_panel.open_settings().left_panel.open_messaging_settings()
            assert driver.waitFor(
                lambda: not msg_stngs.allow_contact_requests_toggle.object.checked, 15000), \
                f'Toggle changes are not synced'

        with step(f'Unpair the device from first instance {aut_one.aut_id}'):
            aut_one.attach()
            main_window.prepare()
            synced_view = main_window.left_panel.open_settings().left_panel.open_syncing_settings()
            synced_view.open_unpair_confirmation().confirm_unpairing()

        with step('Switch toggle state ON'):
            home = main_window.left_panel.open_home_screen()
            messaging_settings = home.open_messaging_settings_from_grid()
            messaging_settings.switch_allow_contact_requests_toggle(True)
            assert messaging_settings.allow_contact_requests_toggle.object.checked

        with step(f'Check that changes for toggle are not reflected in second instance {aut_two.aut_id}'):
            aut_two.attach()
            main_window.prepare()
            home = main_window.left_panel.open_home_screen()
            msg_stngs = home.open_messaging_settings_from_grid()
            assert driver.waitFor(
                lambda: not msg_stngs.allow_contact_requests_toggle.object.checked, 15000), \
                f'Toggle state should remain unchecked becase devices are not paired'
