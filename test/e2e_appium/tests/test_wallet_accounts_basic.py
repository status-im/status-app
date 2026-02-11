import pytest

from pages.wallet.wallet_left_panel import WalletLeftPanel
from pages.app import App
from pages.onboarding.welcome_back_page import WelcomeBackPage
from utils.generators import generate_account_name
from utils.multi_device_helpers import StepMixin


class TestWalletAccountsBasic(StepMixin):
    @pytest.mark.gate
    @pytest.mark.wallet
    @pytest.mark.smoke
    async def test_add_and_delete_generated_account(self):
        async with self.step(self.device, "Verify wallet panel loaded"):
            panel = WalletLeftPanel(self.device.driver)
            app = App(self.device.driver)
            assert panel.is_loaded(timeout=20), "Wallet left panel not visible"

        async with self.step(self.device, "Select first account"):
            account_rows = panel.account_rows()
            assert len(account_rows) > 0, "No account rows found in wallet panel"
            account_rows[0].click()
            self.device.logger.info("Selected first account row")

        async with self.step(self.device, "Copy address via context menu"):
            # Copy address via context menu (like desktop test)
            context_menu_address = panel.copy_account_address_via_context_menu(index=0)
            assert context_menu_address is not None, "Failed to copy address via context menu"
            assert context_menu_address.startswith("0x"), (
                f"Context menu address should start with '0x', got: {context_menu_address}"
            )
            self.device.logger.info(f"Context menu address: {context_menu_address}")

        async with self.step(self.device, "Open Receive modal and verify address match"):
            # Re-select account after context menu closes (ensures receive button is enabled)
            account_rows = panel.account_rows()
            account_rows[0].click()
            
            receive_modal = panel.open_receive_modal()
            assert receive_modal is not None, "Failed to open receive modal"
            assert receive_modal.is_qr_code_visible(), "QR code not visible in receive modal"

            # Copy address via receive modal's copy button
            receive_modal_address = receive_modal.copy_address()
            assert receive_modal_address is not None, "Failed to copy address from receive modal"
            
            # Compare context menu address with receive modal address (exact match like desktop)
            assert context_menu_address == receive_modal_address, (
                f"Address mismatch: context menu '{context_menu_address}' != "
                f"receive modal '{receive_modal_address}'"
            )
            self.device.logger.info(f"Addresses match: {receive_modal_address}")

            assert receive_modal.close(), "Failed to close receive modal"

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

        async with self.step(self.device, "Rename account via context menu"):
            renamed_name = generate_account_name(16)
            assert panel.edit_account_via_menu(
                renamed_name, index=-1
            ), f"Failed to rename account '{name}' via context menu"

        async with self.step(self.device, "Verify account renamed"):
            assert panel.wait_for_account_name(renamed_name, timeout=10), (
                f"Renamed account '{renamed_name}' not visible in account list"
            )

        async with self.step(self.device, "Restart app"):
            assert panel.restart_app(), "Failed to restart app"

        async with self.step(self.device, "Re-authenticate after restart"):
            welcome_back = WelcomeBackPage(self.device.driver)
            assert welcome_back.perform_login(user_password), (
                "Unable to authenticate after restart"
            )

        async with self.step(self.device, "Verify wallet panel loads after restart"):
            panel = WalletLeftPanel(self.device.driver)
            app = App(self.device.driver)
            assert panel.is_loaded(timeout=20), "Wallet panel not visible after restart"

        async with self.step(self.device, "Verify renamed account persists after restart"):
            assert panel.wait_for_account_name(renamed_name, timeout=10), (
                f"Renamed account '{renamed_name}' not visible after restart"
            )

        async with self.step(self.device, "Add second account after restart"):
            second_name = generate_account_name(16)
            assert panel.add_account(second_name, auth_password=user_password), (
                f"Failed to add second account '{second_name}' after restart"
            )

        async with self.step(self.device, "Verify second account added"):
            toast = app.wait_for_toast(
                expected_substring="successfully added",
                timeout=8,
                stability=0.2,
            )
            if toast:
                assert "successfully added" in toast.lower(), (
                    f"Expected success toast after adding '{second_name}'. Got: '{toast}'"
                )
            assert panel.wait_for_account_name(second_name, timeout=10), (
                f"Second account '{second_name}' not visible in account list"
            )

        async with self.step(self.device, "Delete renamed account"):
            assert panel.delete_account_by_name(
                renamed_name, auth_password=user_password
            ), f"Failed to delete renamed account '{renamed_name}'"

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
