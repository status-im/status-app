import allure
import time

import configs
from constants.showcase_visibility import ShowcaseVisibility
from gui.elements.object import QObject
from gui.objects_map import names, settings_names


class ProfileShowcaseVisibilityMenu(QObject):

    def __init__(self):
        super().__init__(names.contextMenu_PopupItem)
        self._no_one = QObject(settings_names.profileShowcaseNoOne)
        self._contacts = QObject(settings_names.profileShowcaseContacts)
        self._everyone = QObject(settings_names.profileShowcaseEveryone)

    def _option_item(self, visibility_option: int) -> QObject:
        match visibility_option:
            case ShowcaseVisibility.NO_ONE:
                return self._no_one
            case ShowcaseVisibility.CONTACTS:
                return self._contacts
            case ShowcaseVisibility.EVERYONE:
                return self._everyone
            case _:
                raise ValueError(
                    f'Unsupported showcase visibility for this menu: {visibility_option!r} '
                    f'(expected {ShowcaseVisibility.NO_ONE}, {ShowcaseVisibility.CONTACTS}, '
                    f'or {ShowcaseVisibility.EVERYONE})'
                )

    @allure.step('Wait until showcase visibility menu appears')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._everyone.wait_until_appears(timeout_msec)
        return self

    @allure.step('Select showcase visibility option')
    def select_visibility_option(self, visibility_option: int):
        item = self._option_item(visibility_option)
        item.wait_until_appears()
        item.click()
        time.sleep(0.2)
        return self
