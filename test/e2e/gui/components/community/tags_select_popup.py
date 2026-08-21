import typing

import allure

import configs
import driver
from gui.components.status_modals import StatusStackModal
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import names


class TagsSelectPopup(StatusStackModal):

    def __init__(self):
        super().__init__()
        self._tag_template = QObject(names.o_StatusCommunityTag)
        self._confirm_button = Button(names.confirm_Community_Tags_StatusButton)
        self._search_field = TextEdit(names.tags_edit_TextEdit)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._tag_template.wait_until_appears()
        return self

    def _iter_tags(self):
        return driver.findAllObjects(self._tag_template.real_name)

    def _filtered_tag(self, name: str, selected: typing.List[str]):
        match = None
        visible = []
        for obj in self._iter_tags():
            try:
                tag_name = str(obj.name)
            except (AttributeError, RuntimeError):
                continue
            visible.append(tag_name)
            if tag_name == name and not obj.removable:
                match = obj
        if match is not None and set(visible) <= set(selected + [name]):
            return match
        return None

    def _confirm_enabled(self) -> bool:
        try:
            return bool(driver.waitForObjectExists(self._confirm_button.real_name, 200).enabled)
        except (LookupError, RuntimeError):
            return False

    @allure.step('Select tags and confirm')
    def select_tags(self, values: typing.List[str]):
        selected = []
        for name in values:
            self._search_field.clear(verify=False)
            self._search_field.type_text(name)
            if not driver.waitFor(
                    lambda: self._filtered_tag(name, selected) is not None,
                    configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
                raise LookupError(f'Tag {name!r} not found after search')
            # clicked() hits StatusMouseArea; mouseClick on the tag object misses it
            self._filtered_tag(name, selected).clicked()
            if not driver.waitFor(self._confirm_enabled, configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
                raise LookupError(f'Clicking tag {name!r} did not select it')
            selected.append(name)

        self._search_field.clear(verify=False)
        for obj in self._iter_tags():
            try:
                if str(obj.name) not in values and obj.removable:
                    obj.clicked()
            except (AttributeError, RuntimeError):
                continue
        self._confirm_button.click()
