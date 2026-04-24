import allure
import pytest
from allure_commons._allure import step

import driver

from constants.wallet import WalletNetworkNaming, WalletEditNetworkErrorMessages, WalletNetworkSettings

from gui.main_window import MainWindow


@pytest.mark.case(703515)
@pytest.mark.parametrize('network_tab', [
    pytest.param(WalletNetworkSettings.EDIT_NETWORK_LIVE_TAB.value),
    pytest.param(WalletNetworkSettings.EDIT_NETWORK_TEST_TAB.value)
])
@pytest.mark.skip(reason='fix me')
def test_settings_networks_edit_restore_defaults(main_screen: MainWindow, network_tab: str):
    networks = main_screen.left_panel.open_settings().left_panel.open_wallet_settings().open_networks()

    with step('Check mainnet network item titles'):
        assert \
            networks.get_network_item_attribute_by_id_and_attr_name('title',
                                                                    WalletNetworkNaming.ETHEREUM_MAINNET_NETWORK_ID.value) == WalletNetworkNaming.LAYER1_ETHEREUM.value
        assert \
            networks.get_network_item_attribute_by_id_and_attr_name('title',
                                                                    WalletNetworkNaming.OPTIMISM_MAINNET_NETWORK_ID.value) == WalletNetworkNaming.LAYER2_OPTIMISIM.value
        assert \
            networks.get_network_item_attribute_by_id_and_attr_name('title',
                                                                    WalletNetworkNaming.ARBITRUM_MAINNET_NETWORK_ID.value) == WalletNetworkNaming.LAYER2_ARBITRUM.value
        assert \
            networks.get_network_item_attribute_by_id_and_attr_name('title', WalletNetworkNaming.BASE_MAINNET_NETWORK_ID.value) == WalletNetworkNaming.LAYER2_BASE.value

    with step('Check testnet network item title'):
        networks_testnet = networks.switch_testnet_mode_toggle()
        networks_testnet.turn_on_button.click()
        assert \
            networks.get_network_item_attribute_by_id_and_attr_name('title',
                                                                    WalletNetworkNaming.HOODI_NETWORK_ID.value) == WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET.value
        networks.switch_testnet_mode_toggle().turn_off_button.click()

    with step('Open Ethereum Mainnet network item to edit'):
        edit_network_form = networks.edit_network(
            WalletNetworkNaming.LAYER1_ETHEREUM.value)

    with step('Check the elements on the form'):
        edit_network_form.wait_until_appears().check_available_elements_on_edit_view(network_tab)

    with step('Click in Main JSON RPC URL and paste incorrect URL'):
        edit_network_form.edit_network_main_json_rpc_url_input("https://google.com", network_tab)

    with step('Check error message for Main JSON RPC URL input'):
        assert driver.waitFor(
            lambda: edit_network_form.get_main_rpc_url_error_message_text() == WalletEditNetworkErrorMessages.PINGUNSUCCESSFUL.value)

    with step('Click in Failover JSON RPC URL and paste incorrect URL'):
        edit_network_form.edit_network_failover_json_rpc_url_input("https://google.com", network_tab)

    with step('Check error message for Failover JSON RPC URL input'):
        assert driver.waitFor(
            lambda: edit_network_form.get_failover_rpc_url_error_message_text() == WalletEditNetworkErrorMessages.PINGUNSUCCESSFUL.value)

    with step('Check the acknowledgment checkbox'):
        edit_network_form.check_acknowledgement_checkbox(True, network_tab)

    with step('Check the acknowledgment text'):
        assert edit_network_form.get_acknowledgement_checkbox_text(
            'text') == WalletNetworkSettings.ACKNOWLEDGMENT_CHECKBOX_TEXT.value

    with step('Click Revert to default button and go to Networks screen'):
        edit_network_form.click_revert_to_default_and_go_to_networks_main_screen().save_and_restart_later()

    with step('Verify toast message appears for reverting to defaults'):
        if network_tab == WalletNetworkSettings.EDIT_NETWORK_LIVE_TAB.value:
            assert len(main_screen.wait_for_toast_notifications()) == 1, \
                f"Multiple toast messages appeared"
            message = main_screen.wait_for_toast_notifications()[0]
            assert message == WalletNetworkSettings.REVERT_TO_DEFAULT_LIVE_MAINNET_TOAST_MESSAGE.value, \
                f"Toast message is incorrect, current message is {message}"
        elif network_tab == WalletNetworkSettings.EDIT_NETWORK_TEST_TAB.value:
            assert len(main_screen.wait_for_toast_notifications()) == 1, \
                f"Multiple toast messages appeared"
            message = main_screen.wait_for_toast_notifications()[0]
            assert message == WalletNetworkSettings.REVERT_TO_DEFAULT_TEST_MAINNET_TOAST_MESSAGE.value, \
                f"Toast message is incorrect, current message is {message}"

        edit_network_form.click_network_back()

    with step('Open Ethereum Mainnet network item to edit'):
        edit_network_form = networks.click_network_item_to_open_edit_view(
            WalletNetworkNaming.ETHEREUM_MAINNET_NETWORK_ID.value)

    with step('Verify value in Main JSON RPC URL input'):
        assert edit_network_form.verify_edit_network_main_json_rpc_url_value(network_tab), \
            f"Reverted value in Main JSON RPC is incorrect"

    with (step('Verify value in Failover JSON RPC URL input')):
        assert edit_network_form.verify_edit_network_failover_json_rpc_url_value(network_tab), \
            f"Reverted value in Failover JSON RPC is incorrect"

    with step('Verify the acknowledgment checkbox is unchecked'):
        assert edit_network_form.check_acknowledgement_checkbox(False, network_tab)
