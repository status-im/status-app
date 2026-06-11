"""Dedicated drawer-navigation coverage.

Every other test treats navigation as setup plumbing and is entitled to the
most reliable transport available. This test is the one place where drawer
navigation is itself the behaviour under test: if tapping through the drawer
breaks for real users, this fails — loudly and attributably — instead of
surfacing as misleading failures scattered across unrelated suites.
"""

import pytest

from pages.app import App
from utils.multi_device_helpers import StepMixin
from utils.screen_identity import confirm_screen, dismiss_backup_modal


SECTIONS = ("messages", "wallet", "settings")


class TestNavigationDrawer(StepMixin):
    @pytest.mark.gate
    @pytest.mark.smoke
    @pytest.mark.timeout(1200)
    async def test_drawer_navigation_cycles(self):
        app = App(self.device.driver)
        dismiss_backup_modal(app)

        nav_actions = {
            "messages": app.click_messages_button,
            "wallet": app.click_wallet_button,
            "settings": app.click_settings_button,
        }

        for cycle in range(1, 4):
            for section in SECTIONS:
                async with self.step(
                    self.device, f"Cycle {cycle}: navigate to {section}"
                ):
                    assert nav_actions[section](), (
                        f"Drawer navigation to {section} failed (cycle {cycle})"
                    )
                    assert confirm_screen(app, section), (
                        f"Navigation to {section} reported success but the "
                        f"{section} anchor is not visible (cycle {cycle})"
                    )
