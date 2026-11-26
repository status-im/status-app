import time

import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import names


class CategoryPopup(QObject):

    def __init__(self):
        super().__init__(names.newChannelnewCategoryPopup)
        self._name_text_edit = TextEdit(names.createOrEditCommunityCategoryNameInput_TextEdit)
        self.channel_item_checkbox = CheckBox(names.channelItemCheckbox_StatusCheckBox)
        self._channels_view = QObject(names.createOrEditCommunityCategoryChannelList_StatusListView)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._name_text_edit.wait_until_appears(timeout_msec)
        return self

    @allure.step('Enter category title in category popup')
    def enter_category_title(self, title):
        self._name_text_edit.text = title
        return self


class NewCategoryPopup(CategoryPopup):

    def __init__(self):
        super(NewCategoryPopup, self).__init__()
        self._create_button = Button(names.create_StatusButton)

    @allure.step('Create category')
    def create(self, name: str, checkbox_state: bool):
        self._name_text_edit.text = name
        if checkbox_state:
            self.channel_item_checkbox.click()
        self._create_button.click()
        self.wait_until_hidden()


class EditCategoryPopup(CategoryPopup):

    def __init__(self):
        super().__init__()
        self.channel_item_checkbox = CheckBox(names.channelItemCheckbox_StatusCheckBox)
        self.delete_button = Button(names.delete_Category_StatusButton)
        self.save_button = Button(names.save_StatusButton)

    @allure.step('Click checkbox in edit category popup')
    def click_checkbox_by_index(self, index: int):
        time.sleep(1)
        checkboxes = driver.find_all(self.channel_item_checkbox.real_name)
        if len(checkboxes) > 0:
            for _index, item in enumerate(checkboxes):
                if index == _index:
                    CheckBox(item).click()
        else:
            raise AssertionError('Empty list of channels')
        return self



