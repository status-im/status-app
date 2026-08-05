import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class BuildShowcasePopup(QObject):

    def __init__(self):
        super().__init__(names.profileShowCasePopup)
        self.build_your_showcase_button = Button(names.build_your_showcase_StatusButton)
        self.close_button = Button(names.profileShowcaseCloseButton)

    @property
    def is_present(self) -> bool:
        return self.build_your_showcase_button.is_visible

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.build_your_showcase_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Wait until hidden {0}')
    def wait_until_hidden(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        assert driver.waitFor(
            lambda: not self.build_your_showcase_button.is_visible,
            timeout_msec,
        ), 'Build showcase popup is still visible'
        return self

    @allure.step('Close build showcase popup')
    def close(self):
        if self.close_button.is_visible:
            self.close_button.click()
        elif self.build_your_showcase_button.is_visible:
            self.build_your_showcase_button.click()
        self.wait_until_hidden()
