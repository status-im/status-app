import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import communities_names


class ColorSelectPopup(QObject):
    """Waits for hex input to appear (indicates color picker is ready)."""

    def __init__(self):
        # Use hex input as popup indicator - unique objectName, works in both Create and Edit flows
        super().__init__(communities_names.communityColorPopup_HexInput)
        self._hex_color_text_edit = QObject(communities_names.communityColorPopup_HexInput)
        self._save_button = Button(communities_names.communityColorPopup_SaveButton)

    @allure.step('Select color {1}')
    def select_color(self, value: str):
        self._hex_color_text_edit.wait_until_appears(
            timeout_msec=configs.timeouts.LOADING_LIST_TIMEOUT_MSEC
        ).set_text_property(value)
        self._save_button.click()
