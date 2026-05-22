import time

import allure

import configs
from gui.elements.object import QObject
from gui.objects_map import names


class EmojiPopup(QObject):
    def __init__(self):
        super().__init__(names.emojiPopup)
        self._search_box = QObject(names.mainWallet_AddEditAccountPopup_AccountEmojiSearchBox)
        self._emoji_item = QObject(names.mainWallet_AddEditAccountPopup_AccountEmoji)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        super().wait_until_appears(timeout_msec)
        self._search_box.wait_until_appears(timeout_msec)
        return self

    @allure.step('Wait until hidden {0}')
    def wait_until_hidden(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._search_box.wait_until_hidden(timeout_msec)
        return self

    @allure.step('Select emoji')
    # FIXME: fix the method to handle multiple emojis with the same name (for example, person keyword returns
    #  multiple results with their own unicodes)
    def select(self, name: str, attempts: int = 2):
        self._search_box.set_text_property(name)
        self._emoji_item.real_name['objectName'] = 'statusEmoji_' + name
        try:
            time.sleep(0.5)
            self._emoji_item.click()
        except LookupError as err:
            if attempts:
                return self.select(name, attempts - 1)
            else:
                raise err
        self.wait_until_hidden()
