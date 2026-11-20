import logging

import allure

import configs

LOG = logging.getLogger(__name__)
import driver


# these methods were originally presented in framework
# but got replaced with something else
# it is a storage for the legacy code until we decide to remove it for real

@allure.step('Wait until hidden {0}')
def wait_until_hidden(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
    condition = driver.wait_until(lambda: not self.is_visible, timeout_msec)
    if not condition:
        raise TimeoutError(f'Timeout reached: Object {self} is not hidden within {timeout_msec} ms')
    LOG.info('%s: is hidden', self)
    return self


@allure.step('Wait until appears {0}')
def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
    condition = driver.wait_until(lambda: self.is_visible, timeout_msec)
    if not condition:
        raise TimeoutError(f'Object {self} is not visible within {timeout_msec} ms')
    LOG.info('%s: is visible', self)
    return self
