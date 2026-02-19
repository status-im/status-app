from config.logging_config import get_logger
from utils.platform import is_ios


class Gestures:
    """Touch gesture operations for mobile UI automation.

    All gesture methods detect the platform at runtime via
    ``utils.platform.is_ios`` and dispatch the correct Appium
    ``mobile:`` command for Android (UiAutomator2) or iOS (XCUITest).
    """

    def __init__(self, driver, logger=None):
        self._driver = driver
        self._logger = logger or get_logger("gestures")
        self._ios = is_ios(driver)

    def tap(self, x: int, y: int) -> bool:
        """Tap at screen coordinates."""
        try:
            if self._ios:
                self._driver.execute_script("mobile: tap", {"x": x, "y": y})
            else:
                self._driver.execute_script("mobile: clickGesture", {"x": x, "y": y})
            return True
        except Exception as e:
            self._logger.debug("tap(%d, %d) failed: %s", x, y, e)
            return False

    def long_press(self, element_id: str, duration_ms: int = 800) -> bool:
        """Long press on element by ID.

        On iOS the XCUITest ``mobile: touchAndHold`` command expects
        *seconds* rather than milliseconds, so we convert accordingly.
        The element key is ``element`` (not ``elementId``).
        """
        try:
            if self._ios:
                self._driver.execute_script(
                    "mobile: touchAndHold",
                    {"element": element_id, "duration": duration_ms / 1000},
                )
            else:
                self._driver.execute_script(
                    "mobile: longClickGesture",
                    {"elementId": element_id, "duration": duration_ms},
                )
            return True
        except Exception as e:
            self._logger.debug("long_press failed: %s", e)
            return False

    def swipe_down(
        self, left: int, top: int, width: int, height: int, percent: float = 0.8
    ) -> bool:
        """Swipe down within bounds."""
        return self._swipe("down", left, top, width, height, percent)

    def swipe_up(
        self, left: int, top: int, width: int, height: int, percent: float = 0.8
    ) -> bool:
        """Swipe up within bounds."""
        return self._swipe("up", left, top, width, height, percent)

    def _swipe(
        self,
        direction: str,
        left: int,
        top: int,
        width: int,
        height: int,
        percent: float,
    ) -> bool:
        """Platform-aware swipe implementation.

        Android uses ``mobile: swipeGesture`` with bounding-box params.
        iOS uses ``mobile: swipe`` with a ``direction`` and optional
        ``velocity`` (pixels-per-second).
        """
        try:
            if self._ios:
                # iOS swipe needs a rough velocity; percent maps loosely
                velocity = int(percent * 1500)
                self._driver.execute_script(
                    "mobile: swipe",
                    {"direction": direction, "velocity": velocity},
                )
            else:
                self._driver.execute_script(
                    "mobile: swipeGesture",
                    {
                        "left": left,
                        "top": top,
                        "width": width,
                        "height": height,
                        "direction": direction,
                        "percent": percent,
                    },
                )
            return True
        except Exception as e:
            self._logger.debug("swipe_%s failed: %s", direction, e)
            return False

    def element_tap(self, element) -> bool:
        """Tap element using its element ID."""
        try:
            if self._ios:
                self._driver.execute_script(
                    "mobile: tap", {"element": element.id}
                )
            else:
                self._driver.execute_script(
                    "mobile: clickGesture", {"elementId": element.id}
                )
            return True
        except Exception as e:
            self._logger.debug("element_tap failed: %s", e)
            return False

    def element_center_tap(self, element) -> bool:
        """Tap center of element using calculated coordinates."""
        try:
            rect = element.rect
            x = int(rect["x"] + rect["width"] / 2)
            y = int(rect["y"] + rect["height"] / 2)
            return self.tap(x, y)
        except Exception as e:
            self._logger.debug("element_center_tap failed: %s", e)
            return False

    def double_tap(self, x: int, y: int) -> bool:
        """Double-tap at coordinates; fallback to two single taps."""
        try:
            if self._ios:
                self._driver.execute_script(
                    "mobile: doubleTap", {"x": x, "y": y}
                )
            else:
                self._driver.execute_script(
                    "mobile: clickGesture", {"x": x, "y": y, "count": 2}
                )
            return True
        except Exception:
            try:
                self.tap(x, y)
                self.tap(x, y)
                return True
            except Exception as e:
                self._logger.debug("double_tap(%d, %d) failed: %s", x, y, e)
                return False

    def element_double_tap(self, element) -> bool:
        """Double-tap on element; fallback to two element taps."""
        try:
            if self._ios:
                self._driver.execute_script(
                    "mobile: doubleTap", {"element": element.id}
                )
            else:
                self._driver.execute_script(
                    "mobile: clickGesture", {"elementId": element.id, "count": 2}
                )
            return True
        except Exception:
            try:
                self.element_tap(element)
                self.element_tap(element)
                return True
            except Exception as e:
                self._logger.debug("element_double_tap failed: %s", e)
                return False
