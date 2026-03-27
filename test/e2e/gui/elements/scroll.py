import logging
import time

import allure

import driver
from .object import QObject

LOG = logging.getLogger(__name__)


def _element_center_y_in_scroll_viewport(
    element: QObject, scroll_surface, margin: int = 24
) -> bool:
    """True if the element's vertical center lies inside the scroll surface (global coords).

    Qt Quick items clipped by a Flickable/ScrollView often keep ``visible == true``; relying on
    that skips scrolling and leaves targets off-screen (see ActivityCenter._scroll_notification_into_view).

    Uses ``driver.object.globalBounds`` like :meth:`QObject.bounds`, but resolves the target with a short
    ``waitForObjectExists`` so we do not call ``element.object`` (full UI timeout) on every scroll step.
    """
    try:
        elem_obj = driver.waitForObjectExists(element.real_name, 200)
    except (LookupError, RuntimeError):
        return False
    try:
        srect = driver.object.globalBounds(scroll_surface)
        crect = driver.object.globalBounds(elem_obj)
    except (RuntimeError, AttributeError):
        return False
    cy = crect.y + crect.height / 2
    top = srect.y + margin
    bot = srect.y + srect.height - margin
    return top <= cy <= bot


def _element_center_x_in_scroll_viewport(
    element: QObject, scroll_surface, margin: int = 24
) -> bool:
    try:
        elem_obj = driver.waitForObjectExists(element.real_name, 200)
    except (LookupError, RuntimeError):
        return False
    try:
        srect = driver.object.globalBounds(scroll_surface)
        crect = driver.object.globalBounds(elem_obj)
    except (RuntimeError, AttributeError):
        return False
    cx = crect.x + crect.width / 2
    left = srect.x + margin
    right = srect.x + srect.width - margin
    return left <= cx <= right


class Scroll(QObject):

    @allure.step('Scroll vertical down to object {1}')
    def vertical_scroll_down(self, element: QObject, timeout_sec: int = 5, extra_scrolls_after: int = 0):
        # First wait for element to exist (UI might need time to update after authentication)
        started_at = time.monotonic()
        while not element.exists:
            time.sleep(0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Element does not exist: {element}')

        scroll_obj = self.object
        sx = max(1, int(scroll_obj.width / 2))
        sy = max(1, int(scroll_obj.height / 2))

        # Scroll until the target is inside the scroll viewport (not just QML ``visible``).
        started_at = time.monotonic()
        while not _element_center_y_in_scroll_viewport(element, scroll_obj):
            driver.mouse.scroll(scroll_obj, sx, sy, 0, -30, 1, 0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Object not found: {element}')

        # Optional: scroll more to center element (e.g. for popups that need space below to open fully)
        for _ in range(extra_scrolls_after):
            driver.mouse.scroll(scroll_obj, sx, sy, 0, -30, 1, 0.1)
            time.sleep(0.1)

    @allure.step('Scroll vertical up to object {1}')
    def vertical_scroll_up(self, element: QObject, timeout_sec: int = 5):
        scroll_obj = self.object
        sx = max(1, int(scroll_obj.width / 2))
        sy = max(1, int(scroll_obj.height / 2))
        started_at = time.monotonic()
        while not _element_center_y_in_scroll_viewport(element, scroll_obj):
            driver.mouse.scroll(scroll_obj, sx, sy, 0, 30, 1, 0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Object not found: {element}')

    @allure.step('Scroll horizontal right to object {1}')
    def horizontal_scroll_right(self, element: QObject, timeout_sec: int = 5):
        scroll_obj = self.object
        sx = max(1, int(scroll_obj.width / 2))
        sy = max(1, int(scroll_obj.height / 2))
        started_at = time.monotonic()
        while not _element_center_x_in_scroll_viewport(element, scroll_obj):
            driver.mouse.scroll(scroll_obj, sx, sy, 30, 0, 1, 0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Object not found: {element}')
