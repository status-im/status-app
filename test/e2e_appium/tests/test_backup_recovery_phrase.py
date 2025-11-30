import os
import pytest

from pages.app import App
from pages.settings.settings_page import SettingsPage
from utils.multi_device_helpers import StepMixin
from utils.screenshot import save_page_source


class TestBackupRecoveryPhrase(StepMixin):
    @pytest.mark.critical
    async def test_sign_out_from_settings(self):
        async with self.step(self.device, "Navigate to Settings"):
            app = App(self.device.driver)
            assert app.click_settings_left_nav(), "Failed to open Settings"
            settings = SettingsPage(self.device.driver)
            assert settings.is_loaded(), "Settings not detected"

        async with self.step(self.device, "Sign out"):
            assert settings.open_sign_out_and_quit(), "Failed to open 'Sign out & Quit'"
            assert settings.confirm_sign_out(), "Failed to confirm sign out"

        async with self.step(self.device, "Verify authentication required"):
            from pages.onboarding.welcome_back_page import WelcomeBackPage
            welcome_back = WelcomeBackPage(self.device.driver)
            assert welcome_back.is_screen_displayed(timeout=15), (
                "App should require authentication after sign out"
            )

    @pytest.mark.parametrize(
        "remove_phrase",
        [pytest.param(True, id="delete")],
    )
    @pytest.mark.smoke
    async def test_backup_recovery_phrase_flow(self, remove_phrase):
        async with self.step(self.device, "Navigate to Settings"):
            app = App(self.device.driver)
            assert app.click_settings_left_nav(), "Failed to open Settings"
            settings = SettingsPage(self.device.driver)
            assert settings.is_loaded(), "Settings not detected"

        async with self.step(self.device, "Open backup recovery phrase modal"):
            modal = settings.open_backup_recovery_phrase()
            assert modal is not None and modal.is_displayed(), "Backup Seed modal not shown"

        async with self.step(self.device, "Reveal and capture seed phrase"):
            assert modal.reveal_seed_phrase(), "Failed to reveal seed phrase"
            word_map = modal.get_seed_words_map()
            assert len(word_map) >= 12, (
                f"Expected 12 word mappings, got {len(word_map)}: {word_map}"
            )

        async with self.step(self.device, "Confirm seed phrase"):
            assert modal.click_next(), "Failed to move to confirm step after reveal"
            index_to_word = {i: w for i, w in word_map.items()}
            assert modal.fill_confirmation_words(index_to_word), (
                "Failed to fill confirmation words"
            )

        async with self.step(self.device, "Complete backup flow"):
            assert modal.click_continue(), "Failed to proceed after confirmation"
            assert modal.click_done(), "Failed to finish backup flow"
            assert modal.wait_until_closed(), "Backup modal did not close after completion"

        async with self.step(self.device, "Verify backup success"):
            assert not settings.is_backup_entry_removed(), (
                "Backup entry should be present after completion"
            )

            keep_msg = app.wait_for_toast(
                expected_substring="backed up your recovery phrase",
                timeout=8,
                stability=0.2,
            )
            assert keep_msg, "Expected a toast to appear after backup completion"
            assert "backed up your recovery phrase" in keep_msg.lower()

        # Capture screenshot for reference
        try:
            screenshot_dir = os.path.join("screenshots", self.device.device_id)
            os.makedirs(screenshot_dir, exist_ok=True)
            save_page_source(self.device.driver, screenshot_dir, "post_backup")
        except Exception:
            pass

        # If requested, perform delete path
        if remove_phrase:
            async with self.step(self.device, "Open backup modal for deletion"):
                modal = settings.open_backup_recovery_phrase()

            async with self.step(self.device, "Confirm and delete seed phrase"):
                assert modal.reveal_seed_phrase(), "Failed to reveal seed phrase (2nd pass)"
                assert modal.click_next(), "Failed to move to confirm step (2nd pass)"
                assert modal.fill_confirmation_words(index_to_word), (
                    "Failed to fill confirmation words (2nd pass)"
                )
                assert modal.click_continue(), (
                    "Failed to proceed after confirmation (2nd pass)"
                )
                assert modal.set_remove_checkbox(True), "Failed to tick remove checkbox"
                assert modal.click_done(), "Failed to finish (Done) (2nd pass)"
                assert modal.wait_until_closed(), (
                    "Backup modal did not close after deletion"
                )

            async with self.step(self.device, "Verify deletion success"):
                delete_msg = app.wait_for_toast(
                    expected_substring="recovery phrase permanently removed",
                    timeout=8,
                    stability=0.2,
                )
                assert delete_msg, "Expected a toast to appear after deletion"
                assert "recovery phrase permanently removed" in delete_msg.lower()

                assert settings.is_backup_entry_removed(), (
                    "Backup entry should be removed after deletion"
                )

            # Capture screenshot after deletion
            try:
                save_page_source(self.device.driver, screenshot_dir, "post_backup_delete")
            except Exception:
                pass
