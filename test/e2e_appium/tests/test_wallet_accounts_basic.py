import pytest

from pages.wallet.wallet_left_panel import WalletLeftPanel
from pages.app import App
from utils.generators import generate_account_name
from utils.multi_device_helpers import StepMixin


class TestWalletAccountsBasic(StepMixin):
    @pytest.mark.wallet
    @pytest.mark.smoke
    async def test_add_and_delete_generated_account(self):
        async with self.step(self.device, "Verify wallet panel loaded"):
            panel = WalletLeftPanel(self.device.driver)
            app = App(self.device.driver)
            assert panel.is_loaded(timeout=20), "Wallet left panel not visible"

        async with self.step(self.device, "Add new account"):
            before = len(panel.account_rows())
            user_password = self.device.user.password

            name = generate_account_name(16)
            assert panel.add_account(name, auth_password=user_password), (
                f"Failed to add account '{name}' via modal"
            )

        async with self.step(self.device, "Verify account added"):
            toast = app.wait_for_toast(
                expected_substring="successfully added",
                timeout=8,
                stability=0.2,
            )
            if toast:
                assert "successfully added" in toast.lower(), (
                    f"Expected success toast after adding account '{name}'. Got: '{toast}'"
                )
            else:
                app.logger.warning("No toast detected after adding account '%s'", name)

            after_add = len(panel.account_rows())
            assert after_add >= before, (
                f"Account list did not grow after adding '{name}'. "
                f"Before: {before}, After: {after_add}"
            )

        async with self.step(self.device, "Delete account"):
            assert panel.delete_latest_account_via_menu(
                auth_password=user_password
            ), f"Failed to delete generated account '{name}' via context menu"

        async with self.step(self.device, "Verify account deleted"):
            toast = app.wait_for_toast(
                expected_substring="successfully removed",
                timeout=8,
                stability=0.2,
            )
            assert toast, "Expected toast after removing account"
            assert "successfully removed" in toast.lower(), (
                f"Expected removal toast after deleting account. Got: '{toast}'"
            )

            after_delete = len(panel.account_rows())
            assert after_delete <= after_add, (
                f"Account list did not shrink after deletion. "
                f"Before deletion: {after_add}, After deletion: {after_delete}"
            )
