import allure

import configs
from gui.elements.object import QObject
from gui.objects_map import names


class SignPopup(QObject):

    def __init__(self):
        super().__init__(names.signPopup)
        self._pin_input = QObject(names.keycardAuthPinInput)

    @allure.step('Wait until Sign popup PIN appears')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._pin_input.wait_until_appears(timeout_msec)
        return self

    @property
    def is_pin_visible(self) -> bool:
        return self._pin_input.is_visible

    @allure.step('Enter Keycard PIN to sign')
    def enter_pin(self, pin: str, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._pin_input.wait_until_appears(timeout_msec)
        self._pin_input.object.setPin(pin)
        self._pin_input.wait_until_hidden(timeout_msec)
        return self
