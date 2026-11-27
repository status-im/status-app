import logging
from collections.abc import Callable

import pytest

from pages.app import App
from pages.onboarding.welcome_back_page import WelcomeBackPage
from pages.settings.settings_page import SettingsPage
from support.multi_device_helpers import StepMixin
from support.platform import is_android

SIGN_OUT = "100-MenuItem"
MAX_SWIPES_PER_SWEEP = 6
MAX_RECOVERY_ROUNDS = 3
logger = logging.getLogger(__name__)
EXPECTED_MENU_ITEMS = {
    "101-MenuItem": "Recovery phrase",
    "0-MenuItem": "Profile",
    "1-MenuItem": "Password",
    "14-MenuItem": "Keycard",
    "3-MenuItem": "ENS usernames",
    "9-MenuItem": "Syncing",
    "18-MenuItem": "On-device backup",
    "19-MenuItem": "P2P network",
    "4-MenuItem": "Messaging",
    "5-MenuItem": "Wallet",
    "10-MenuItem": "Browser",
    "13-MenuItem": "Communities",
    "17-MenuItem": "Privacy and security",
    "6-MenuItem": "Appearance",
    "8-MenuItem": "Notifications",
    "7-MenuItem": "Language & Currency",
    "11-MenuItem": "Advanced",
    "12-MenuItem": "About",
    SIGN_OUT: "Sign out",
}


def _assert_accessible_settings_menu(app: App, settings: SettingsPage) -> None:
    assert app.click_settings_left_nav(), "Failed to open Settings"
    assert settings.is_loaded(), "Settings did not load"
    seen = settings.visible_menu_item_ids()

    def record_new_rows() -> bool:
        current = settings.visible_menu_item_ids()
        added_rows = bool(current - seen)
        seen.update(current)
        return added_rows

    def sweep(swipe: Callable[[], None]) -> None:
        for _ in range(MAX_SWIPES_PER_SWEEP):
            if EXPECTED_MENU_ITEMS.keys() <= seen:
                return
            swipe()
            settings.wait_for_condition(record_new_rows, timeout=5, poll_interval=0.3)

    def missing_rows() -> list[str]:
        return [f"{name} ({tid})" for tid, name in EXPECTED_MENU_ITEMS.items() if tid not in seen]

    sweep(settings.swipe_toward_end_of_menu)
    if missing := missing_rows():
        logger.warning("Retrying Settings rows missing after the first sweep: %s", ", ".join(missing))
        for _ in range(MAX_RECOVERY_ROUNDS):
            sweep(settings.swipe_toward_start_of_menu)
            sweep(settings.swipe_toward_end_of_menu)
            if EXPECTED_MENU_ITEMS.keys() <= seen:
                break

    missing = missing_rows()
    assert not missing, f"Settings rows missing from the on-screen accessibility tree: {', '.join(missing)}"


class TestSettingsAccessibility(StepMixin):
    """Check the full Settings list on Android.

    Emulators can omit buffered rows from the tree; scrolling away and back
    gives their delegates another chance to be created in view.
    """

    @pytest.mark.device_count(1)
    @pytest.mark.portrait
    @pytest.mark.e2e
    async def test_settings_rows_are_accessible_after_scrolling_and_cold_restart(self):
        """Scroll through Settings before and after a fresh launch and login."""
        if not is_android(self.driver):
            pytest.skip("Checks the Android UiAutomator accessibility tree")

        app = App(self.driver)
        settings = SettingsPage(self.driver)
        async with self.step(self.device, "Scroll through the Settings accessibility tree"):
            _assert_accessible_settings_menu(app, settings)

        async with self.step(self.device, "Cold restart and sign back in"):
            lifecycle = app.app_lifecycle
            assert lifecycle.terminate_app(), "Failed to stop the app"
            assert lifecycle.wait_for_app_not_running(), "App was still running before launch"
            assert lifecycle.activate_app_with_ui_ready(), "Failed to relaunch the app"
            welcome_back = WelcomeBackPage(self.driver)
            assert welcome_back.perform_login(self.device.user.password), "Login failed after restart"

        async with self.step(self.device, "Scroll through the Settings accessibility tree after restart"):
            _assert_accessible_settings_menu(app, settings)
