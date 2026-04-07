"""
Helper functions for common operations with multiple instances.
Reduces code duplication across test files.
"""
import allure
from allure_commons._allure import step

import configs


@allure.step('Switch to AUT and prepare main window')
def switch_to_aut(aut, main_window):
    """
    Switch to the given AUT and prepare main window.
    
    Args:
        aut: The AUT to switch to
        main_window: MainWindow instance
    """
    aut.attach()
    main_window.prepare()


@allure.step('Authorize user in AUT')
def authorize_user_in_aut(aut, main_window, user_account):
    """
    Authorize user in the given AUT.
    
    Args:
        aut: The AUT to authorize user in
        main_window: MainWindow instance
        user_account: UserAccount to authorize
    """
    aut.attach()
    main_window.wait_until_appears(configs.timeouts.APP_LOAD_TIMEOUT_MSEC).prepare()
    main_window.authorize_user(user_account)


@allure.step('Get chat key from user')
def get_chat_key(aut, main_window):
    """
    Get chat key from the current user.
    
    Args:
        aut: The AUT to get chat key from
        main_window: MainWindow instance
        
    Returns:
        str: Chat key of the user
    """
    aut.attach()
    main_window.prepare()
    profile_popup = main_window.left_panel.open_online_identifier().open_profile_popup_from_online_identifier()
    chat_key = profile_popup.copy_chat_key
    main_window.left_panel.click()
    return chat_key


@allure.step('Send contact request from settings')
def send_contact_request_from_settings(aut, main_window, chat_key, message):
    """
    Send contact request from messaging settings.
    
    Args:
        aut: The AUT to send request from
        main_window: MainWindow instance
        chat_key: Chat key of the recipient
        message: Message to send with the request
        
    Returns:
        ContactsSettingsView: The contacts settings view instance
    """
    aut.attach()
    main_window.prepare()
    settings = main_window.left_panel.open_settings()
    messaging_settings = settings.left_panel.open_messaging_settings()
    contacts_settings = messaging_settings.open_contacts_settings()
    contact_request_popup = contacts_settings.open_contact_request_form()
    contact_request_popup.send(chat_key, message)
    return contacts_settings


@allure.step('Accept contact request via Activity Center')
def accept_contact_request_via_activity_center(aut, main_window, from_user_name: str):
    """Same flow as critical group-chat tests: focus AUT, accept, then minimize to avoid cross-window clicks."""
    switch_to_aut(aut, main_window)
    activity_center = main_window.left_panel.open_activity_center()
    request = activity_center.find_contact_request_in_list(from_user_name)
    activity_center.accept_contact_request(request)
    main_window.left_panel.click()
    main_window.minimize()


@allure.step('Accept contact request from settings')
def accept_contact_request_from_settings(aut, main_window, user_name):
    """
    Accept contact request from messaging settings.
    
    Args:
        aut: The AUT to accept request in
        main_window: MainWindow instance
        user_name: Name of the user to accept request from
    """
    aut.attach()
    main_window.prepare()
    settings = main_window.left_panel.open_settings()
    messaging_settings = settings.left_panel.open_messaging_settings()
    contacts_settings = messaging_settings.open_contacts_settings()
    contacts_settings.accept_contact_request(user_name)

