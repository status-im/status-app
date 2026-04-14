import allure

from constants.showcase_visibility import ShowcaseVisibility
from gui.elements.object import QObject
from gui.objects_map import names, settings_names


class ProfileShowcaseVisibilityMenu(QObject):

    def __init__(self):
        super().__init__(names.contextMenu_PopupItem)
        self._no_one = QObject(settings_names.profileShowcaseNoOne)
        self._contacts = QObject(settings_names.profileShowcaseContacts)
        self._everyone = QObject(settings_names.profileShowcaseEveryone)

    @allure.step('Select showcase visibility option')
    def select_visibility_option(self, visibility_option: int):
        match visibility_option:
            case ShowcaseVisibility.NO_ONE:
                self._no_one.click()
            case ShowcaseVisibility.CONTACTS:
                self._contacts.click()
            case ShowcaseVisibility.EVERYONE:
                self._everyone.click()
            case _:
                raise ValueError(
                    f'Unsupported showcase visibility for this menu: {visibility_option!r} '
                    f'(expected {ShowcaseVisibility.NO_ONE}, {ShowcaseVisibility.CONTACTS}, '
                    f'or {ShowcaseVisibility.EVERYONE})'
                )
        return self
