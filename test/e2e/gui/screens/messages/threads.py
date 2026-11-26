import typing

import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import messaging_names, names


def _ordered_texts(locator: dict, prop: str) -> typing.List[str]:
    items = [i for i in driver.find_all(locator) if str(getattr(i, prop, '') or '')]
    items.sort(key=lambda i: driver.bounds(i).y)
    return [str(getattr(i, prop)) for i in items]


@allure.step('Open new thread panel from message {0}')
def open_thread_from_message(message) -> 'NewThreadComposer':
    message.open_context_menu_for_message()
    Button(messaging_names.messageContextMenu_openThread_StatusMenuItem).click()
    return NewThreadComposer().wait_until_appears()


class NewThreadComposer(QObject):
    """The composer of NewThreadPanel.qml; its users model is the community roster."""

    def __init__(self):
        super().__init__(messaging_names.newThreadLoader)
        self._message_field = TextEdit(messaging_names.newThread_messageInputField_TextArea)
        self._suggestions = QObject(messaging_names.newThread_suggestionsBox)
        self._send_button = Button(messaging_names.newThread_sendButton)
        self._close_button = Button(messaging_names.closeThreadPanelButton)

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC, check_interval=0.5):
        super().wait_until_appears(timeout_msec, check_interval)
        self._message_field.wait_until_appears(timeout_msec)
        return self

    def _suggestion_names(self) -> typing.List[str]:
        return _ordered_texts(messaging_names.newThread_mentionSuggestion_Rectangle, 'objectName')

    @allure.step('Read thread composer @mention suggestions')
    def mention_suggestion_names(self, filter_text: str = '') -> typing.List[str]:
        self._message_field.click()
        self._message_field.clear(verify=False)
        driver.type_text(self._message_field.object, '@' + filter_text)
        self._suggestions.wait_until_appears(configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        names = []
        driver.wait_until(lambda: bool(names.extend(self._suggestion_names()) or names),
                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        self._message_field.clear(verify=False)
        return names

    @allure.step('Send thread message {1} mentioning {2}')
    def send_mentioning(self, text: str, display_name: str):
        self._message_field.click()
        self._message_field.clear(verify=False)
        driver.type_text(self._message_field.object, f'{text} @{display_name[:24]}')
        self._suggestions.wait_until_appears(configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        item = dict(messaging_names.newThread_mentionSuggestion_Rectangle, objectName=display_name)
        driver.click(driver.wait(item, configs.timeouts.UI_LOAD_TIMEOUT_MSEC))
        assert driver.wait_until(lambda: self._send_button.is_enabled, configs.timeouts.UI_LOAD_TIMEOUT_MSEC), \
            'Thread send button stayed disabled'
        self._send_button.click()
        self.wait_until_hidden(configs.timeouts.MESSAGING_TIMEOUT_SEC * 1000)

    @allure.step('Close thread panel')
    def close(self):
        self._close_button.click()


class ChatInfoThreads(QObject):
    """Threads tab of ChatInfoPanel.qml. Rows come from the threads/message model, not the roster."""

    def __init__(self):
        super().__init__(messaging_names.chatInfoThreadsList)
        self._tab = Button(messaging_names.chatInfoThreadsTab)

    @allure.step('Open threads tab in chat info')
    def open(self) -> 'ChatInfoThreads':
        # An open thread takes the right panel; the info tabs come back once it is closed.
        close_thread = Button(messaging_names.closeThreadPanelButton)
        if close_thread.exists:
            close_thread.click()
        if not self._tab.exists:
            Button(names.chatToolbar_infoButton).click()
        self._tab.click()
        return self.wait_until_appears()

    @property
    @allure.step('Get thread card senders')
    def senders(self) -> typing.List[str]:
        return _ordered_texts(messaging_names.chatInfoThreadsList_threadCardMessageSender, 'text')

    @property
    @allure.step('Get thread card previews')
    def previews(self) -> typing.List[str]:
        return _ordered_texts(messaging_names.chatInfoThreadsList_threadCardMessagePreview, 'text')
