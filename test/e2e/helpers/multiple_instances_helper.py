"""
Helper functions for common operations with multiple instances.
Reduces code duplication across test files.
"""
import allure
from allure_commons._allure import step

import configs


def _attach_and_prepare(aut, main_window):
    aut.attach()
    main_window.prepare()
    main_window.wait_until_appears(configs.timeouts.APP_LOAD_TIMEOUT_MSEC)


@allure.step('Switch to AUT and prepare main window')
def switch_to_aut(aut, main_window):
    """
    Switch to the given AUT and prepare main window.
    
    Args:
        aut: The AUT to switch to
        main_window: MainWindow instance
    """
    _attach_and_prepare(aut, main_window)


@allure.step('Authorize user in AUT')
def authorize_user_in_aut(aut, main_window, user_account):
    _attach_and_prepare(aut, main_window)
    main_window.authorize_user(user_account)
    main_window.minimize()


@allure.step('Get chat key from user')
def get_chat_key(aut, main_window):
    _attach_and_prepare(aut, main_window)
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
    _attach_and_prepare(aut, main_window)
    settings = main_window.left_panel.open_settings()
    messaging_settings = settings.left_panel.open_messaging_settings()
    contacts_settings = messaging_settings.open_contacts_settings()
    contact_request_popup = contacts_settings.open_contact_request_form()
    contact_request_popup.send(chat_key, message)
    return contacts_settings


@allure.step('Accept contact request from settings')
def accept_contact_request_from_settings(aut, main_window, user_name):
    """
    Accept contact request from messaging settings.
    
    Args:
        aut: The AUT to accept request in
        main_window: MainWindow instance
        user_name: Name of the user to accept request from
    """
    _attach_and_prepare(aut, main_window)
    settings = main_window.left_panel.open_settings()
    messaging_settings = settings.left_panel.open_messaging_settings()
    contacts_settings = messaging_settings.open_contacts_settings()
    contacts_settings.accept_contact_request(user_name)

