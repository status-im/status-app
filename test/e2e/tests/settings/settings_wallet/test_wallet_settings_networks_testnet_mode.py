import allure
import pytest
from allure import step

import configs.system
from constants.wallet import WalletNetworkSettings, WalletNetworkNaming
from gui.components.wallet.testnet_mode_banner import TestnetModeBanner
from gui.components.toast_message import ToastMessage
from gui.main_window import MainWindow


@pytest.mark.case(703505)
@pytest.mark.skip(reason='we need to move this to QML tests level')
def test_switch_testnet_mode(main_screen: MainWindow):
    with step('Verify that Testnet toggle has subtitle'):
        networks = main_screen.left_panel.open_settings().left_panel.open_wallet_settings().open_networks()
        subtitle = networks.get_testnet_toggle_subtitle()
        assert subtitle == WalletNetworkSettings.TESTNET_SUBTITLE.value, \
            f"Testnet title is incorrect, current subtitle is {subtitle}"

    with step('Verify back to Wallet settings button is present and text on top is correct'):
        assert networks.is_back_to_wallet_settings_button_present(), \
            f"Back to Wallet settings button is not visible on Networks screen"

    with step('Verify that Testnet mode toggle is turned off'):
        assert not networks.is_testnet_mode_toggle_checked(), f"Testnet toggle is on when it should not"

    with step('Turn on Testnet mode'):
        networks.switch_testnet_mode_toggle().turn_on_button.click()

    with step('Verify that Testnet mode turned on'):
        assert len(main_screen.wait_for_toast_notifications()) == 1, \
            f"Multiple toast messages appeared"
        message = main_screen.wait_for_toast_notifications()[0]
        assert message == WalletNetworkSettings.TESTNET_ENABLED_TOAST_MESSAGE.value, \
            f"Toast message is incorrect, current message is {message}"
        if not configs.system.TEST_MODE and not configs._local.DEV_BUILD:
            TestnetModeBanner().wait_until_appears()
        assert networks.is_testnet_mode_toggle_checked(), f"Testnet toggle if off when it should not"

    with step('Verify networks are switched to testnets'):
        assert networks.get_network_item_attribute_by_id_and_attr_name('title',
                                                                       WalletNetworkNaming.HOODI_NETWORK_ID.value) == WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET.value

    with step('Turn off Testnet mode in wallet settings'):
        networks.switch_testnet_mode_toggle().turn_off_button.click()

    with step('Verify that Testnet mode turned off'):
        assert len(main_screen.wait_for_toast_notifications()) == 2
        message = main_screen.wait_for_toast_notifications()[1]
        assert message == WalletNetworkSettings.TESTNET_DISABLED_TOAST_MESSAGE.value, \
            f"Toast message is incorrect, current message is {message}"
        if not configs.system.TEST_MODE and not configs._local.DEV_BUILD:
            TestnetModeBanner().wait_until_hidden()
        assert not networks.is_testnet_mode_toggle_checked(), f"Testnet toggle is on when it should not"


@pytest.mark.case(703621)
@pytest.mark.skip(reason='we need to move this to QML tests level')
def test_toggle_testnet_toggle_on_and_close_the_confirmation(main_screen: MainWindow):
    networks = main_screen.left_panel.open_settings().left_panel.open_wallet_settings().open_networks()

    with step('Verify that Testnet mode toggle is turned off'):
        assert not networks.is_testnet_mode_toggle_checked(), f"Testnet toggle is enabled when it should not"

    with step('Check Mainnet network item title'):
        networks.get_network_item_attribute_by_id_and_attr_name('title',
                                                                WalletNetworkNaming.ETHEREUM_MAINNET_NETWORK_ID.value)

    with step('Toggle the Testnet mode toggle ON'):
        testnet_modal = networks.switch_testnet_mode_toggle()

    with step('Click cross button on the Testnet modal'):
        testnet_modal.close_cross_button.click()
        assert not networks.is_testnet_mode_toggle_checked()

    with step('Verify that Testnet mode is not turned off'):
        assert not ToastMessage().is_visible
        if not configs.system.TEST_MODE and not configs._local.DEV_BUILD:
            assert not TestnetModeBanner().is_visible, f"Testnet banner is present when it should not"
        assert not networks.is_testnet_mode_toggle_checked(), \
            f"Testnet toggle is turned on when it should not"


@pytest.mark.case(703622)
@pytest.mark.skip(reason='we need to move this to QML tests level')
def test_switch_testnet_off_by_toggle_and_cancel_in_confirmation(main_screen: MainWindow):
    networks = main_screen.left_panel.open_settings().left_panel.open_wallet_settings().open_networks()

    with step('Verify that Testnet mode toggle is turned off'):
        assert not networks.is_testnet_mode_toggle_checked(), f"Testnet toggle is enabled when it should not"

    with step('Toggle the Testnet mode toggle ON'):
        testnet_modal = networks.switch_testnet_mode_toggle()

    with step('Confirm enabling testnet mode in testnet modal'):
        testnet_modal.turn_on_button.click()

    with step('Verify testnet mode is enabled'):
        assert len(main_screen.wait_for_toast_notifications()) == 1, \
            f"Multiple toast messages appeared"
        message = main_screen.wait_for_toast_notifications()[0]
        assert message == WalletNetworkSettings.TESTNET_ENABLED_TOAST_MESSAGE.value, \
            f"Toast message is incorrect, current message is {message}"
        if not configs.system.TEST_MODE and not configs._local.DEV_BUILD:
            assert TestnetModeBanner().wait_until_appears(), f"Testnet banner is not present when it should"

        assert networks.is_testnet_mode_toggle_checked(), f"testnet toggle is off"

    with step('Toggle the Testnet mode toggle Off'):
        testnet_modal = networks.switch_testnet_mode_toggle()

    with step('Click Cancel button on the Testnet modal'):
        testnet_modal.cancel_button.click()
        assert networks.is_testnet_mode_toggle_checked(), f"Testnet toggle is turned OFF when it should not"

    with step('Verify that Testnet mode is not turned off'):
        if not configs.system.TEST_MODE and not configs._local.DEV_BUILD:
            assert TestnetModeBanner().wait_until_appears(), f"Testnet banner is not present when it should"
