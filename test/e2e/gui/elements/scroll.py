import logging
import time

import allure

import driver
from .object import QObject

LOG = logging.getLogger(__name__)


def effective_vertical_viewport_margin(surface_height: float, max_margin: int = 24) -> int:
    """Vertical inset from scroll edges when deciding whether a row center is \"clickably\" inside.

    Caps ``max_margin`` so that small scroll surfaces (CI windows, banners shrinking the flickable)
    keep a non-empty inner band instead of permanently rejecting every ``cy``.
    """
    if surface_height <= 0:
        return 0
    return min(max_margin, max(0, int((surface_height - 8) // 2)))


def row_vertically_usable_in_scroll_viewport(
    scroll_bounds,
    row_bounds,
    max_margin: int = 24,
) -> bool:
    """True if a channel/list row is suitably positioned for interaction inside the scroll viewport.

    Prefer vertical center inside an adaptive inner band; fall back to any overlap with the viewport.
    """
    cy = row_bounds.y + row_bounds.height / 2
    h = scroll_bounds.height
    m = effective_vertical_viewport_margin(h, max_margin)
    top = scroll_bounds.y + m
    bot = scroll_bounds.y + h - m
    if top <= cy <= bot:
        return True
    return (
        row_bounds.y < scroll_bounds.y + scroll_bounds.height
        and row_bounds.y + row_bounds.height > scroll_bounds.y
    )


def _element_center_y_in_scroll_viewport(
    element: QObject, scroll_surface, margin: int = 24
) -> bool:
    """True if the element's vertical center lies inside the scroll surface (global coords).

    Qt Quick items clipped by a Flickable/ScrollView often keep ``visible == true``; relying on
    that skips scrolling and leaves targets off-screen (see ActivityCenter._scroll_notification_into_view).

    Uses ``driver.object.globalBounds`` like :meth:`QObject.bounds`, but resolves the target with a short
    ``waitForObjectExists`` so we do not call ``element.object`` (full UI timeout) on every scroll step.

    Uses :func:`effective_vertical_viewport_margin` so narrow scroll surfaces still yield a valid band.
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
    m = effective_vertical_viewport_margin(srect.height, margin)
    top = srect.y + m
    bot = srect.y + srect.height - m
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
