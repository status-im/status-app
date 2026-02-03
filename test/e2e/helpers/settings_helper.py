"""
Helper functions for common settings operations.
Reduces code duplication across test files.
"""
import time

import allure
from gui.components.settings.keycard_popup import KeycardPopup


@allure.step('Enable testnet mode')
def enable_testnet_mode(main_window):
    """Enable testnet mode from wallet settings."""
    wallet_settings = main_window.left_panel.open_settings().left_panel.open_wallet_settings()
    test_mode_popup = wallet_settings.open_networks().switch_testnet_mode_toggle()
    test_mode_popup.turn_on_testnet_mode()


@allure.step('Enable managing communities on testnet toggle')
def enable_managing_communities_toggle(main_window):
    """Enable managing communities on testnet from advanced settings."""
    settings = main_window.left_panel.open_settings()
    settings.left_panel.open_advanced_settings().enable_manage_communities_on_testnet_toggle()


@allure.step('Open wallet settings')
def open_wallet_settings(main_window):
    """
    Open wallet settings from main window.
    
    Returns:
        WalletSettingsView: The wallet settings view instance
    """
    return main_window.left_panel.open_settings().left_panel.open_wallet_settings()


@allure.step('Open messaging settings')
def open_messaging_settings(main_window):
    """
    Open messaging settings from main window.
    
    Returns:
        MessagingSettingsView: The messaging settings view instance
    """
    return main_window.left_panel.open_settings().left_panel.open_messaging_settings()


@allure.step('Open profile settings')
def open_profile_settings(main_window):
    """
    Open profile settings from main window.
    
    Returns:
        ProfileSettingsView: The profile settings view instance
    """
    return main_window.left_panel.open_settings().left_panel.open_profile_settings()


@allure.step('Verify toast notification contains message')
def verify_toast_notification(main_window, expected_message):
    """
    Verify that a toast notification contains the expected message.
    
    Args:
        main_window: MainWindow instance
        expected_message: Expected message in the toast
        
    Returns:
        bool: True if message is found in toast notifications
    """
    messages = main_window.wait_for_toast_notifications()
    return expected_message in messages


@allure.step('Skip Keycard error popup')
def skip_pcsc_error_popup_if_visible():
    time.sleep(0.1)

    pcsc_error_popup = KeycardPopup()
    if pcsc_error_popup.is_visible:
        pcsc_error_popup.close_button.click()
        time.sleep(0.1)

