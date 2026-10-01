from gui.components.base_popup import BasePopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import communities_names, names


class LeaveCommunityConfirmationPopup(QObject):
    def __init__(self):
        super().__init__(names.statusModal)
        self.leave_button = Button(communities_names.leaveCommunityButton)

    def confirm_action(self):
        self.leave_button.click()
        self.leave_button.wait_until_hidden()

