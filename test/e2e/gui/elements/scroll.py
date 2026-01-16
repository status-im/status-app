import logging
import time

import allure

import driver
from .object import QObject

LOG = logging.getLogger(__name__)


class Scroll(QObject):

    @allure.step('Scroll vertical down to object {1}')
    def vertical_scroll_down(self, element: QObject, timeout_sec: int = 5):
        # First wait for element to exist (UI might need time to update after authentication)
        started_at = time.monotonic()
        while not element.exists:
            time.sleep(0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Element does not exist: {element}')
        
        # Now scroll until element is visible
        started_at = time.monotonic()
        while not element.is_visible:
            driver.mouse.scroll(self.object, self.object.width / 2, self.object.height / 2, 0, -30, 1, 0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Object not found: {element}')

    @allure.step('Scroll vertical up to object {1}')
    def vertical_scroll_up(self, element: QObject, timeout_sec: int = 5):
        started_at = time.monotonic()
        while not element.is_visible:
            driver.mouse.scroll(self.object, self.object.width / 2, self.object.height / 2, 0, 30, 1, 0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Object not found: {element}')

    @allure.step('Scroll horizontal right to object {1}')
    def horizontal_scroll_right(self, element: QObject, timeout_sec: int = 5):
        started_at = time.monotonic()
        while not element.is_visible:
            driver.mouse.scroll(self.object, self.object.width / 2, self.object.height / 2, 30, 0, 1, 0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Object not found: {element}')
