import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class EnableBiometricsPopup(QObject):
    def __init__(self):
        super().__init__(names.enableBiometricsPopup)
        self.maybe_later_button = Button(names.enableBiometricsMaybeLaterButton)

    @allure.step('Skip Enable biometrics popup')
    def skip(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.maybe_later_button.wait_until_appears(timeout_msec)
        self.maybe_later_button.click()
        self.wait_until_hidden()
        return self
