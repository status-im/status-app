import allure

from gui.components.change_password_popup import ChangePasswordPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.elements.text_edit import TextEdit
from gui.objects_map import names, settings_names


class ChangePasswordView(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_PasswordView)
        self._scroll_view = Scroll(settings_names.settingsContentBase_ScrollView)
        self._change_password_button = Button(names.change_password_menu_change_password_button)
        self._current_password_text_field = TextEdit(names.change_password_menu_current_password)
        self._new_password_text_field = TextEdit(names.change_password_menu_new_password)
        self._confirm_password_text_field = TextEdit(names.change_password_menu_new_password_confirm)

    @allure.step('Fill in the form, submit and sign out')
    def change_password(self, old_pwd: str, new_pwd: str):
        self._current_password_text_field.clear()
        self._current_password_text_field.type_text(old_pwd)
        self._new_password_text_field.clear()
        self._new_password_text_field.type_text(new_pwd)
        self._confirm_password_text_field.clear()
        self._confirm_password_text_field.type_text(new_pwd)
        self._change_password_button.click()
        return ChangePasswordPopup()
