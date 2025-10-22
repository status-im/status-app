import os
import pytest

from tests.base_test import BaseAppReadyTest, cloud_reporting
from utils.screenshot import save_page_source
from pages.app import App


class TestBackupRecoveryPhrase(BaseAppReadyTest):
    @pytest.mark.critical
    @cloud_reporting
    def test_sign_out_from_settings(self):
        # BaseAppReadyTest ensures authenticated home

        # Navigate to Settings: prefer left-nav when available, fallback to Home dock
        opened = self.ctx.app.click_settings_left_nav()
        assert opened, "Failed to open Settings"
        assert self.ctx.settings.is_loaded(), "Settings not detected"

        # Open Sign out & Quit and confirm
        assert self.ctx.settings.open_sign_out_and_quit(), (
            "Failed to open 'Sign out & Quit'"
        )
        assert self.ctx.settings.confirm_sign_out(), "Failed to confirm sign out"

        self.ctx._detect_app_state()
        assert self.ctx.app_state.requires_authentication, (
            "App should require authentication after sign out"
        )

    @pytest.mark.parametrize(
        "remove_phrase",
        [pytest.param(True, id="delete")],
    )
    @pytest.mark.smoke
    @cloud_reporting
    def test_backup_recovery_phrase_flow(self, remove_phrase):
        # BaseAppReadyTest ensures home; open Settings (left-nav preferred)
        opened = self.ctx.app.click_settings_left_nav()
        assert opened, "Failed to open Settings"
        assert self.ctx.settings.is_loaded(), "Settings not detected"

        # Open 'Back up recovery phrase' entry and display modal
        modal = self.ctx.settings.open_backup_recovery_phrase()
        assert modal is not None and modal.is_displayed(), "Backup Seed modal not shown"

        # Step 1: Reveal recovery phrase; capture words for logging
        assert modal.reveal_seed_phrase(), "Failed to reveal seed phrase"
        word_map = modal.get_seed_words_map()
        assert len(word_map) >= 12, (
            f"Expected 12 word mappings, got {len(word_map)}: {word_map}"
        )

        # Proceed to the confirm step (new UI shows 4 inputs at once)
        assert modal.click_next(), "Failed to move to confirm step after reveal"

        # Fill all required confirmation inputs using the captured seed words (1-based indices)
        index_to_word = {i: w for i, w in word_map.items()}
        assert modal.fill_confirmation_words(index_to_word), (
            "Failed to fill confirmation words"
        )

        # Continue to the final screen and finish (keep path first)
        assert modal.click_continue(), "Failed to proceed after confirmation"
        assert modal.click_done(), "Failed to finish backup flow"
        assert modal.wait_until_closed(), "Backup modal did not close after completion"

        # After keep, entry should remain
        assert not self.ctx.settings.is_backup_entry_removed(), (
            "Backup entry should be present after completion"
        )

        # Verify toast appears and assert content-desc contains expected phrase (no fallbacks)
        app = App(self.driver)
        keep_msg = app.wait_for_toast(
            expected_substring="backed up your recovery phrase",
            timeout=8,
            stability=0.2,
        )
        assert keep_msg, "Expected a toast to appear after backup completion"
        assert "backed up your recovery phrase" in keep_msg.lower()

        # Capture final state XML for reference
        try:
            shot_path = self.ctx.take_screenshot("post_backup")
            base_dir = os.path.dirname(shot_path) if shot_path else "screenshots"
            save_page_source(self.driver, base_dir, "post_backup")
        except Exception:
            pass

        # If requested, immediately perform the delete path in the same test
        if remove_phrase:
            driver = self.driver
            driver.quit
            modal = self.ctx.settings.open_backup_recovery_phrase()

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

            # Verify toast after delete via content-desc substring (no fallbacks) BEFORE checking entry removal
            delete_msg = app.wait_for_toast(
                expected_substring="recovery phrase permanently removed",
                timeout=8,
                stability=0.2,
            )
            assert delete_msg, "Expected a toast to appear after deletion"
            assert "recovery phrase permanently removed" in delete_msg.lower()

            # After toast, verify entry removal
            assert self.ctx.settings.is_backup_entry_removed(), (
                "Backup entry should be removed after deletion"
            )

            # Capture final XML after delete path as well
            try:
                shot_path = self.ctx.take_screenshot("post_backup_delete")
                base_dir = os.path.dirname(shot_path) if shot_path else "screenshots"
                save_page_source(self.driver, base_dir, "post_backup_delete")
            except Exception:
                pass
