import allure

import configs
import driver
from gui.elements.object import QObject
from gui.objects_map import names


class NicknamePopup(QObject):

    def __init__(self):
        super().__init__(names.nicknamePopup_nicknameInput)

    @allure.step('Set nickname {1}')
    def set_nickname(self, nickname: str):
        self.wait_until_appears(configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        # Return submits the popup (NicknamePopup.qml onKeyPressed).
        driver.type_text(self.object, f'{nickname}<Return>')
        self.wait_until_hidden(configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
