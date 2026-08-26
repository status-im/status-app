"""
Chat helper functions for common chat operations.
"""
import time
import allure

import configs
from driver.objects_access import find_descendant_by_object_name
from gui.components.community.enable_message_backup_popup import EnableMessageBackupPopup
from gui.components.introduce_yourself_popup import IntroduceYourselfPopup
from scripts.utils.parsers import remove_tags

_MESSAGE_TEXT_PARSE_DEPTH = 48


def plain_text_from_message_object(obj) -> str:
    try:
        chat_text = find_descendant_by_object_name(
            obj, 'StatusTextMessage_chatText', _MESSAGE_TEXT_PARSE_DEPTH,
        )
        if chat_text is not None:
            text = getattr(chat_text, 'text', None)
            if text not in (None, ''):
                plain = remove_tags(str(text)).strip()
                if plain:
                    return plain
    except (LookupError, RuntimeError, AttributeError):
        pass

    for attr in ('unparsedText', 'messageText'):
        raw = getattr(obj, attr, None)
        if raw not in (None, ''):
            plain = remove_tags(str(raw)).strip()
            if plain:
                if getattr(obj, 'isEdited', False) and '(edited)' not in plain:
                    plain = f'{plain} (edited)'
                return plain
    return ''


def message_plain_text(msg) -> str:
    return plain_text_from_message_object(msg.object)


@allure.step('Get visible message texts from chat')
def get_visible_message_texts(chat):
    texts = []
    for msg in chat.messages(index=None):
        text = message_plain_text(msg)
        if text:
            texts.append(text)
    return texts


@allure.step('Check if chat contains message text')
def chat_contains_message_text(chat, needle: str) -> bool:
    try:
        return any(needle in text for text in get_visible_message_texts(chat))
    except Exception:
        return False


@allure.step('Skip Enable Messages backup popup')
def skip_message_backup_popup_if_visible(attempts = 4):
    message_back_up_popup = EnableMessageBackupPopup()
    if not message_back_up_popup.is_visible:
        try:
            message_back_up_popup.wait_until_appears(timeout_msec=1000)
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
