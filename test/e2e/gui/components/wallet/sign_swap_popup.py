from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class SignSwapModalPopup(QObject):

    def __init__(self):
        super().__init__(names.swapSignModal)
        self.sign_button = Button(names.swapSignModalSignButton)
