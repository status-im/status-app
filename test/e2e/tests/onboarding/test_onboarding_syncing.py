import pytest
from allure_commons._allure import step

from gui.screens.settings_syncing import SyncingSettingsView
from . import marks

from constants.syncing import SyncingSettings
from gui.main_window import MainWindow

pytestmark = marks


@pytest.mark.case(703591)
def test_cancel_setup_syncing(main_screen: MainWindow, user_account):
    with step('Open syncing settings'):
        sync_settings_view = main_screen.left_panel.open_settings().left_panel.open_syncing_settings()
        assert sync_settings_view.sync_new_device_instructions_header.text \
               == SyncingSettings.SYNC_A_NEW_DEVICE_INSTRUCTIONS_HEADER.value, f"Sync a new device title is incorrect"
        assert sync_settings_view.sync_new_device_instructions_subtitle.text \
               == SyncingSettings.SYNC_A_NEW_DEVICE_INSTRUCTIONS_SUBTITLE.value, f"Sync a new device subtitle is incorrect"

    with step('Click setup syncing and close authenticate popup'):
        sync_new_device_popup = sync_settings_view.open_sync_new_device_popup(user_account.password)
        sync_new_device_popup.close()

    with step('Verify that authenticate popup was closed and syncing settings view appears after closing'):
        assert SyncingSettingsView().is_visible
