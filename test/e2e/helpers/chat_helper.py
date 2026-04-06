"""
Chat helper functions for common chat operations.
"""
import time
import allure

import configs
from gui.components.community.enable_message_backup_popup import EnableMessageBackupPopup
from gui.components.introduce_yourself_popup import IntroduceYourselfPopup
from gui.components.settings.review_contact_request_popup import AcceptIgnoreRequestFromProfile


@allure.step('Skip Enable Messages backup popup')
def skip_message_backup_popup_if_visible(attempts = 4):
    message_back_up_popup = EnableMessageBackupPopup()
    if not message_back_up_popup.is_visible:
        try:
            message_back_up_popup.wait_until_appears(timeout_msec=configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        except (TimeoutError, Exception):
            return

    for attempt in range(1, attempts + 1):
        message_back_up_popup.skip_button.click()
        try:
            message_back_up_popup.wait_until_hidden(timeout_msec=configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
            return
        except Exception as e:
            if attempt < attempts:
                continue
            else:
                raise Exception(f"Failed to close EnableMessageBackupPopup after {attempts} attempts: {e}")


@allure.step('Accept from Review contact request popup if visible')
def accept_review_contact_request_popup_if_visible() -> bool:
    """When the notification card TapHandler opens the review dialog, finish accept via its Accept button."""
    popup = AcceptIgnoreRequestFromProfile()
    if not popup.is_visible:
        return False
    try:
        popup.accept_button.click()
        time.sleep(0.35)
        return True
    except Exception:
        return False


@allure.step('Skip Introduce Yourself popup')
def skip_intro_if_visible(attempts = 4):
    """
    Skip the introduce yourself popup if it's visible.
    """
    
    introduce_yourself_popup = IntroduceYourselfPopup()
    if not introduce_yourself_popup.is_visible:
        return

    for attempt in range(1, attempts + 1):
        introduce_yourself_popup.skip_button.click()
        try:
            introduce_yourself_popup.wait_until_hidden(timeout_msec=configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
            return
        except Exception as e:
            if attempt < attempts:
                continue
            else:
                raise Exception(f"Failed to close IntroduceYourselfPopup after {attempts} attempts: {e}")

