import allure

from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class EducationPopup(QObject):
    def __init__(self):
        super().__init__(names.educationPopup)

        self.educaton_popup = QObject(names.educationPopup)
        self.close_button = Button(names.educationPopupCloseButton)

    @allure.step('Close Education popup')
    def skip(self):
        self.close_button.click()
        self.educaton_popup.wait_until_hidden()
        assert not self.educaton_popup.is_visible
        return self
    