import logging
import time

import allure

import configs
import driver
from .object import QObject, _dump_element_state

LOG = logging.getLogger(__name__)


def _strip_visible(locator):
    """Recursively remove 'visible' key from a locator dict.

    findObject on Windows VM fails for locators with 'visible: True' because Squish
    considers many elements not visible even when they exist and are interactable.
    Stripping the filter lets us get the object reference for bounds checking.
    """
    if not isinstance(locator, dict):
        return locator
    return {k: _strip_visible(v) for k, v in locator.items() if k != 'visible'}


def _center_in_viewport(elem_bounds, container_bounds) -> bool:
    """Check that the element's center point is inside the container's visible area.

    Stricter than a simple overlap check: ensures at least half the element is visible
    vertically before stopping the scroll. A bare-minimum overlap (e.g. 1px at the edge)
    is not enough — the element must be meaningfully in view so clicks land correctly.
    """
    center_x = elem_bounds.x + elem_bounds.width / 2
    center_y = elem_bounds.y + elem_bounds.height / 2
    return (
        container_bounds.x <= center_x <= container_bounds.x + container_bounds.width
        and container_bounds.y <= center_y <= container_bounds.y + container_bounds.height
    )


def _is_in_viewport(element: QObject, scroll_container: QObject) -> bool:
    """Check that element is inside the scroll container's visible area.

    Primary check: waitForObject — works on all platforms and correctly fails
    for clipped elements.
    Fallback for platforms where waitForObject is unreliable (e.g. Windows VM):
    compare global bounds of the element with the scroll container bounds.
    An element that exists but is outside the container bounds is still clipped.
    """
    try:
        driver.waitForObject(element.real_name, configs.timeouts.OBJECT_LOOKUP_TIMEOUT_MSEC)
        return True
    except (LookupError, RuntimeError):
        pass

    if not driver.object.exists(element.real_name):
        return False
    try:
        obj = driver.findObject(_strip_visible(element.real_name))
        elem_bounds = driver.object.globalBounds(obj)
        # Strip 'visible' filter so findObject succeeds on Windows VM where
        # Squish cannot locate elements by visible: True even when they exist.
        container_obj = driver.findObject(_strip_visible(scroll_container.real_name))
        container_bounds = driver.object.globalBounds(container_obj)
        in_view = _center_in_viewport(elem_bounds, container_bounds)
        if in_view:
            lines = [
                f'in-viewport bounds fallback succeeded (center check)',
                f'  elem:      x={elem_bounds.x} y={elem_bounds.y} w={elem_bounds.width} h={elem_bounds.height}',
                f'  elem center: cx={elem_bounds.x + elem_bounds.width/2} cy={elem_bounds.y + elem_bounds.height/2}',
                f'  container: x={container_bounds.x} y={container_bounds.y} w={container_bounds.width} h={container_bounds.height}',
            ]
            report = '\n'.join(lines)
            LOG.info('%s: %s', element, report)
            allure.attach(report, name=f'in-viewport bounds fallback — {type(element).__name__}',
                          attachment_type=allure.attachment_type.TEXT)
        return in_view
    except Exception as e:
        msg = f'{element}: bounds check failed: {e}'
        LOG.warning(msg)
        allure.attach(msg, name='bounds check error', attachment_type=allure.attachment_type.TEXT)
        return False


class Scroll(QObject):

    def _get_container_obj(self):
        """Return the scroll container for the scroll loop.

        Prefers findObject (instant) and short-timeout waitForObject (1s) over
        the default 5s — avoids blocking a whole loop iteration on each attempt.
        """
        strategies = [
            lambda: driver.findObject(_strip_visible(self.real_name)),
            lambda: driver.waitForObject(
                _strip_visible(self.real_name),
                configs.timeouts.OBJECT_LOOKUP_TIMEOUT_MSEC,
            ),
            lambda: driver.waitForObject(
                self.real_name,
                configs.timeouts.OBJECT_LOOKUP_TIMEOUT_MSEC,
            ),
        ]
        for get_obj in strategies:
            try:
                return get_obj()
            except Exception:
                pass
        raise LookupError(f'Scroll container not found: {self.real_name}')

    @allure.step('Scroll vertical down to object {1}')
    def vertical_scroll_down(self, element: QObject, timeout_sec: int = 5):
        started_at = time.monotonic()
        while not element.exists:
            time.sleep(0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Element does not exist: {element}')

        started_at = time.monotonic()
        while not _is_in_viewport(element, self):
            container = self._get_container_obj()
            driver.mouse.scroll(container, container.width / 2, container.height / 2, 0, -30, 1, 0.1)
            if time.monotonic() - started_at > timeout_sec:
                _dump_element_state(element.real_name, f'scroll_down timeout — {type(element).__name__}')
                raise LookupError(f'Object not found: {element}')

    @allure.step('Scroll vertical up to object {1}')
    def vertical_scroll_up(self, element: QObject, timeout_sec: int = 5):
        started_at = time.monotonic()
        while not _is_in_viewport(element, self):
            container = self._get_container_obj()
            driver.mouse.scroll(container, container.width / 2, container.height / 2, 0, 30, 1, 0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Object not found: {element}')

    @allure.step('Scroll horizontal right to object {1}')
    def horizontal_scroll_right(self, element: QObject, timeout_sec: int = 5):
        started_at = time.monotonic()
        while not _is_in_viewport(element, self):
            container = self._get_container_obj()
            driver.mouse.scroll(container, container.width / 2, container.height / 2, 30, 0, 1, 0.1)
            if time.monotonic() - started_at > timeout_sec:
                raise LookupError(f'Object not found: {element}')
