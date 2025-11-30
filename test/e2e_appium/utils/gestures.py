from config.logging_config import get_logger


class Gestures:
    """Touch gesture operations for mobile UI automation."""

    def __init__(self, driver, logger=None):
        self._driver = driver
        self._logger = logger or get_logger("gestures")

    def tap(self, x: int, y: int) -> bool:
        """Tap at screen coordinates."""
        try:
            self._driver.execute_script("mobile: clickGesture", {"x": x, "y": y})
            return True
        except Exception as e:
            self._logger.debug("tap(%d, %d) failed: %s", x, y, e)
            return False

    def long_press(self, element_id: str, duration_ms: int = 800) -> bool:
        """Long press on element by ID."""
        try:
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
        try:
            self._driver.execute_script(
                "mobile: swipeGesture",
                {
                    "left": left,
                    "top": top,
                    "width": width,
                    "height": height,
                    "direction": "down",
                    "percent": percent,
                },
            )
            return True
        except Exception as e:
            self._logger.debug("swipe_down failed: %s", e)
            return False

    def swipe_up(
        self, left: int, top: int, width: int, height: int, percent: float = 0.8
    ) -> bool:
        """Swipe up within bounds."""
        try:
            self._driver.execute_script(
                "mobile: swipeGesture",
                {
                    "left": left,
                    "top": top,
                    "width": width,
                    "height": height,
                    "direction": "up",
                    "percent": percent,
                },
            )
            return True
        except Exception as e:
            self._logger.debug("swipe_up failed: %s", e)
            return False

    def element_tap(self, element) -> bool:
        """Tap element using its element ID."""
        try:
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
            self._driver.execute_script(
                "mobile: clickGesture", {"x": x, "y": y, "count": 2}
            )
            return True
        except Exception:
            try:
                self._driver.execute_script("mobile: clickGesture", {"x": x, "y": y})
                self._driver.execute_script("mobile: clickGesture", {"x": x, "y": y})
                return True
            except Exception as e:
                self._logger.debug("double_tap(%d, %d) failed: %s", x, y, e)
                return False

    def element_double_tap(self, element) -> bool:
        """Double-tap on element; fallback to two element taps."""
        try:
            self._driver.execute_script(
                "mobile: clickGesture", {"elementId": element.id, "count": 2}
            )
            return True
        except Exception:
            try:
                self._driver.execute_script(
                    "mobile: clickGesture", {"elementId": element.id}
                )
                self._driver.execute_script(
                    "mobile: clickGesture", {"elementId": element.id}
                )
                return True
            except Exception as e:
                self._logger.debug("element_double_tap failed: %s", e)
                return False
