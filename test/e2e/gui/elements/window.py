import logging

import allure

import configs
import driver
from gui.elements.object import QObject

LOG = logging.getLogger(__name__)


class Window(QObject):

    def prepare(self) -> 'Window':
        self.maximize()
        self.set_focus()
        # self.on_top_level()
        return self

    @property
    def title(self):
        return str(getattr(self.object, 'title', ''))

    @allure.step("Maximize {0}")
    def maximize(self):
        assert driver.toplevel_window.maximize(self.real_name), 'Maximize failed'
        LOG.info('Window was maximized')

    @allure.step("Minimize {0}")
    def minimize(self):
        assert driver.toplevel_window.minimize(self.real_name), 'Minimize failed'
        LOG.info('Window was minimized')

    @allure.step("Set focus on {0}")
    def set_focus(self):
        assert driver.toplevel_window.set_focus(self.real_name), 'Set focus failed'
        LOG.info('Window was focused')

    @allure.step("Move {0} on top")
    def on_top_level(self):
        assert driver.toplevel_window.on_top_level(self.real_name), 'Set on top failed'
        LOG.info('Window moved on top')

    @allure.step("Close {0}")
    def close(self):
        driver.toplevel_window.close(self.real_name)
        LOG.info('%s closed', self)

    @allure.step("Show {0}")
    def show(self):
        driver.waitForObjectExists(self.real_name).setVisible(True)
        LOG.info('%s is visible', self)

    @allure.step("Hide {0}")
    def hide(self):
        driver.waitForObjectExists(self.real_name).setVisible(False)
        LOG.info('%s hidden', self)

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        super().wait_until_appears(timeout_msec)
        LOG.info('Window appears')
        return self
