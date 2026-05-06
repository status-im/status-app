"""Touch gesture primitives (Appium 3 + UIA2 / XCUITest).

- Coordinate primitives (tap, long-press, double-tap) use W3C
  ``ActionBuilder`` on Android, ``mobile: tap`` / ``touchAndHold`` on iOS.
- Element variants derive coords from ``element.rect`` and call the
  coordinate primitive. ``elementId``-based dispatch routes through
  ``AccessibilityNodeInfo.ACTION_CLICK`` and silently no-ops on QML
  widgets exposing ``clickable=false`` (SettingsList rows, wallet
  accounts, chat-input ChatIcons).
- Complex gestures (swipe, scroll, fling, pinch) keep ``mobile: *Gesture``.
- Never ``TouchAction`` / ``MultiTouchAction`` (removed in Appium 3).
"""

from selenium.webdriver.common.actions.action_builder import ActionBuilder
from selenium.webdriver.common.actions.interaction import POINTER_TOUCH
from selenium.webdriver.common.actions.pointer_input import PointerInput

from config.logging_config import get_logger
from utils.platform import is_ios


class Gestures:
    """Touch gesture operations for mobile UI automation."""

    def __init__(self, driver, logger=None):
        self._driver = driver
        self._logger = logger or get_logger("gestures")
        self._ios = is_ios(driver)

    # ── Coordinate-based primitives (W3C on Android, mobile: * on iOS) ──

    def tap(self, x: int, y: int) -> bool:
        """Single tap at screen coordinates.

        Android uses a no-pause W3C ``pointerDown`` → ``pointerUp`` sequence.
        Inserting a pause between down and up loses gesture races against
        sibling DragHandlers (e.g. PrimaryNavSidebar drawer-close) when
        running on cloud devices with appreciable network latency.
        """
        try:
            if self._ios:
                self._driver.execute_script("mobile: tap", {"x": x, "y": y})
            else:
                touch = PointerInput(POINTER_TOUCH, "finger")
                actions = ActionBuilder(self._driver, mouse=touch)
                actions.pointer_action.move_to_location(x, y)
                actions.pointer_action.pointer_down()
                actions.pointer_action.pointer_up()
                actions.perform()
            return True
        except Exception as e:
            self._logger.debug("tap(%d, %d) failed: %s", x, y, e)
            return False

    def long_press(self, x: int, y: int, duration_ms: int = 800) -> bool:
        """Long-press at screen coordinates.

        Uses ``mobile: longClickGesture`` on Android — the W3C
        ``pointerDown + pause + pointerUp`` path doesn't reliably trigger
        Qt's ``onPressAndHold`` at the 800ms threshold (registers as a tap).
        """
        try:
            if self._ios:
                self._driver.execute_script(
                    "mobile: touchAndHold",
                    {"x": x, "y": y, "duration": duration_ms / 1000},
                )
            else:
                self._driver.execute_script(
                    "mobile: longClickGesture",
                    {"x": x, "y": y, "duration": duration_ms},
                )
            return True
        except Exception as e:
            self._logger.debug(
                "long_press(%d, %d, %dms) failed: %s", x, y, duration_ms, e
            )
            return False

    def double_tap(self, x: int, y: int) -> bool:
        """Double-tap at screen coordinates."""
        try:
            if self._ios:
                self._driver.execute_script(
                    "mobile: doubleTap", {"x": x, "y": y}
                )
            else:
                touch = PointerInput(POINTER_TOUCH, "finger")
                actions = ActionBuilder(self._driver, mouse=touch)
                actions.pointer_action.move_to_location(x, y)
                actions.pointer_action.pointer_down()
                actions.pointer_action.pause(0.05)
                actions.pointer_action.pointer_up()
                actions.pointer_action.pause(0.06)
                actions.pointer_action.pointer_down()
                actions.pointer_action.pause(0.05)
                actions.pointer_action.pointer_up()
                actions.perform()
            return True
        except Exception as e:
            self._logger.debug("double_tap(%d, %d) failed: %s", x, y, e)
            return False

    # ── Convenience wrappers around primitives ──

    def activation_tap(self) -> bool:
        """Tap centre-of-screen to wake/activate the UI.

        Used at session start and after restarts to nudge the app into
        rendering. Centre coords are portrait/landscape-safe, away from
        the nav-drawer swipe handle, system edge-gesture zones, and the
        keyboard region.
        """
        try:
            size = self._driver.get_window_size()
            x = int(size["width"] * 0.5)
            y = int(size["height"] * 0.5)
        except Exception:
            # Fallback for typical 1080x2400 portrait phones.
            x, y = 540, 1200
        return self.tap(x, y)

    # ── Element-based gestures: derive coords from element.rect ──

    def element_tap(self, element) -> bool:
        """Tap centre of element. Derives coords from ``element.rect``."""
        try:
            rect = element.rect
            x = int(rect["x"] + rect["width"] / 2)
            y = int(rect["y"] + rect["height"] / 2)
            return self.tap(x, y)
        except Exception as e:
            self._logger.debug("element_tap failed: %s", e)
            return False

    # Backwards-compat alias (was previously a coord-based variant of
    # element_tap; now identical since element_tap also uses coords).
    element_center_tap = element_tap

    def element_long_press(self, element, duration_ms: int = 800) -> bool:
        """Long-press centre of element. Coords from ``element.rect``."""
        try:
            rect = element.rect
            x = int(rect["x"] + rect["width"] / 2)
            y = int(rect["y"] + rect["height"] / 2)
            return self.long_press(x, y, duration_ms)
        except Exception as e:
            self._logger.debug("element_long_press failed: %s", e)
            return False

    def element_double_tap(self, element) -> bool:
        """Double-tap centre of element. Coords from ``element.rect``."""
        try:
            rect = element.rect
            x = int(rect["x"] + rect["width"] / 2)
            y = int(rect["y"] + rect["height"] / 2)
            return self.double_tap(x, y)
        except Exception as e:
            self._logger.debug("element_double_tap failed: %s", e)
            return False

    # ── Complex gestures: keep mobile: *Gesture extensions (Android) ──

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
        """Bounding-box swipe.

        Android uses ``mobile: swipeGesture`` (driver extension; remains
        supported in Appium 3 + UIA2). iOS uses ``mobile: swipe`` with a
        ``direction`` + ``velocity``.
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
