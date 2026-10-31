"""Desktop UI helpers for chat threads (feature-flagged)."""
import pathlib
import typing

import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.elements.text_label import TextLabel
from gui.objects_map import messaging_names
from helpers.chat_helper import chat_contains_message_text, plain_text_from_message_object
from scripts.utils.generators import random_text_message


def thread_title_from_parent_message(parent_text: str) -> str:
    return parent_text[:50]


def thread_parent_message_literal() -> str:
    return f'<mark>{random_text_message()[:30]}'


def _qml_flag(value) -> bool:
    if isinstance(value, str):
        return value.lower() == 'true'
    return bool(value)


def _thread_message_views():
    logs = driver.findAllObjects(messaging_names.mainWindow_chatLogView_StatusListView)
    for log in logs:
        if not _log_is_thread_view(log):
            continue
        real_name = dict(messaging_names.chatLogView_chatMessageViewDelegate_MessageView)
        real_name['container'] = driver.objectMap.realName(log)
        try:
            yield from driver.findAllObjects(real_name)
        except (LookupError, RuntimeError):
            continue


def _log_is_thread_view(log) -> bool:
    node = log
    for _ in range(16):
        try:
            node = node.parent
        except (RuntimeError, AttributeError):
            return False
        if node is None:
            return False
        try:
            if _qml_flag(getattr(node, 'isThreadView', False)):
                return True
        except (RuntimeError, AttributeError):
            continue
    return False


class ThreadPanel:
    def __init__(self):
        self._close_button = Button(messaging_names.closeThreadPanelButton)

    @property
    @allure.step('Thread side panel is open')
    def is_open(self) -> bool:
        try:
            self._close_button.wait_until_appears(configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
            return True
        except TimeoutError:
            return False

    @allure.step('Send message in the open thread panel')
    def send_message(self, message: str):
        field = TextEdit(messaging_names.threadMessageInputField)
        field.wait_until_appears()
        field.click()
        field.set_text_property(message)
        send_button = Button(messaging_names.threadSendButton)
        send_button.wait_until_enabled().click()

    @allure.step('Send image in the open thread or thread main chat')
    def send_image(self, path_or_base64: str):
        chat_input = QObject(messaging_names.threadChatInput)
        chat_input.wait_until_appears()
        if isinstance(path_or_base64, str) and path_or_base64.startswith('data:image/'):
            image_payload = path_or_base64
        else:
            image_payload = pathlib.Path(str(path_or_base64)).as_uri()
        chat_input.object.selectImageString(image_payload)
        Button(messaging_names.threadSendButton).wait_until_enabled().click()

    @allure.step('Find message in the open thread panel')
    def find_message(self, message_text: str):
        from gui.screens.messages.message import Message

        found = None

        def message_found() -> bool:
            nonlocal found
            for item in _thread_message_views():
                if message_text in plain_text_from_message_object(item):
                    found = Message(item)
                    return True
            return False

        timeout_msec = configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000
        if not driver.waitFor(message_found, timeout_msec):
            raise LookupError(f'Thread message not found within {timeout_msec} ms: {message_text!r}')
        return found

    @allure.step('Close thread side panel')
    def close(self):
        self._close_button.wait_until_appears().click()
        timeout_msec = configs.timeouts.UI_LOAD_TIMEOUT_MSEC
        assert driver.waitFor(lambda: not self._close_button.exists, timeout_msec), (
            f'Thread panel did not close within {timeout_msec} ms'
        )


def _header_label_text(locator: dict) -> str:
    label = TextLabel(locator)
    if not driver.object.exists(label.real_name):
        return ''
    return str(label.object.text)


@allure.step('Active chat header title')
def active_chat_header_title() -> str:
    for locator in (messaging_names.threadHeaderTitle, messaging_names.statusChatInfoButton):
        try:
            title = _header_label_text(locator)
        except Exception:
            continue
        if title:
            return title
    return ''


@allure.step('Wait until chat header shows {expected!r}')
def wait_for_chat_header(expected: str, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
    assert driver.waitFor(lambda: active_chat_header_title() == expected, timeout_msec), (
        f'Chat header did not become {expected!r} within {timeout_msec} ms; '
        f'last title was {active_chat_header_title()!r}'
    )


@allure.step('Wait until reply is absent from main chat transcript')
def wait_until_reply_not_in_main_chat(chat, reply_text: str):
    timeout_msec = configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000
    assert driver.waitFor(
        lambda: not chat_contains_message_text(chat, reply_text),
        timeout_msec,
    ), f'Reply {reply_text!r} appeared in main chat transcript'


@allure.step('Wait until notifications count for {item_name!r} is at least {min_count}')
def wait_for_notifications_count(
        drop_area_real_name: dict,
        item_name: str,
        min_count: int,
        timeout_msec: int = configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000,
) -> int:
    last_count: typing.Optional[int] = None

    def _ready() -> bool:
        nonlocal last_count
        last_count = list_item_notifications_count(drop_area_real_name, item_name)
        return last_count >= min_count

    assert driver.waitFor(_ready, timeout_msec), (
        f'Notifications for {item_name!r} did not reach {min_count}; last count was {last_count}'
    )
    return last_count or 0


def list_item_notifications_count(drop_area_real_name: dict, item_name: str) -> int:
    for obj in driver.findAllObjects(drop_area_real_name):
        if str(getattr(obj, 'objectName', '')) != item_name:
            continue
        return _row_badge_count(getattr(obj, 'item', obj))
    raise LookupError(f'Chat list item {item_name!r} not found')


def _row_badge_count(list_item) -> int:
    count = int(getattr(list_item, 'notificationsCount', 0) or 0)
    if count == 0 and _qml_flag(getattr(list_item, 'hasUnreadMessages', False)):
        return 1
    return count


def messages_list_notifications_count(chat_list_item_real_name: dict, item_name: str) -> int:
    real_name = dict(chat_list_item_real_name)
    real_name['objectName'] = item_name
    matches = driver.findAllObjects(real_name)
    if not matches:
        raise LookupError(f'Messages list item {item_name!r} not found')
    return _row_badge_count(matches[0])
