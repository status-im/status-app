import allure

import configs
from gui.components.status_modals import StatusPopup
from gui.elements.button import Button
from gui.elements.text_edit import TextEdit
from gui.objects_map import names


class ColorSelectPopup(StatusPopup):

    def __init__(self):
        super().__init__()
        self._hex_color_text_edit = TextEdit(names.communitySettings_ColorPanel_HexColor_Input)
        self._save_button = Button(names.communitySettings_SaveColor_Button)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._hex_color_text_edit.wait_until_appears(timeout_msec)
        return self

    @allure.step('Wait until hidden {0}')
    def wait_until_hidden(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._hex_color_text_edit.wait_until_hidden(timeout_msec)

    @allure.step('Select color {1}')
    def select_color(self, value: str):
        self._hex_color_text_edit.text = value
        self._save_button.click()
