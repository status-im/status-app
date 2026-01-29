import allure

import configs.timeouts
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class DisableNetworkConfirmationPopup(QObject):
    def __init__(self, network_name):
        super().__init__(names.deactivateNetworkPopup)
        self.network_name = network_name
        self.close_cross_button = Button(names.closeCrossPopupButton)
        self.disable_button = Button(names.deactivateNetworkPopupDisableButton)

    @allure.step('Wait until popup appears')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.disable_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Click disable button to confirm')
    def confirm_disable(self):
        self.disable_button.real_name['text'] = f'Disable {self.network_name}'
        self.disable_button.click()
        return self.wait_until_hidden()

