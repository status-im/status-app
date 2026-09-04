import time

from config.logging_config import get_logger
from support.gestures import Gestures

class KeyboardManager:

    def __init__(self, driver):
        self.driver = driver
        self.gestures = Gestures(driver)
        self.logger = get_logger("keyboard_manager")

    def hide_keyboard(self, retries: int = 3, delay: float = 0.5) -> bool:
        try:
            if not self.driver.is_keyboard_shown():
                self.logger.debug("Keyboard not shown, nothing to hide")
                return True

            for attempt in range(1, retries + 1):
                try:
                    self.driver.hide_keyboard()
                    time.sleep(delay)  # let UI settle
                    if not self.driver.is_keyboard_shown():
                        self.logger.info(f"Keyboard hidden using hide_keyboard() (attempt {attempt})")
                        return True
                    else:
                        self.logger.debug(f"hide_keyboard() attempt {attempt} executed but keyboard still visible")
                except Exception as e:
                    self.logger.debug(f"hide_keyboard() attempt {attempt} failed: {e}")
                time.sleep(delay)

            try:
                size = self.driver.get_window_size()
                center_x = size["width"] // 2
                start_y = int(size["height"] * 0.4)
                end_y = int(size["height"] * 0.2)

                self.logger.debug(f"Swiping from ({center_x},{start_y}) to ({center_x},{end_y}) to dismiss keyboard")
                self.gestures.swipe_down(center_x, start_y, 20, end_y, 0.8)
                time.sleep(delay)
                if not self.driver.is_keyboard_shown():
                    self.logger.info("Keyboard hidden using swipe gesture")
                    return True
                else:
                    self.logger.debug("Swipe executed but keyboard still visible")
            except Exception as e:
                self.logger.debug(f"Swipe gesture failed: {e}")

            self.logger.warning("All keyboard hiding strategies failed")
            return False

        except Exception as e:
            self.logger.error(f"Unexpected error hiding keyboard: {e}")
            return False

    def ensure_element_visible(
        self, locator, is_element_visible_func, timeout=10
    ) -> bool:
        try:
            if is_element_visible_func(locator, timeout=2):
                return True

            self.logger.info("Element not visible, attempting to hide keyboard")
            if self.hide_keyboard():
                return is_element_visible_func(locator, timeout=timeout)

            return False

        except Exception as e:
            self.logger.error(f"Error ensuring element visibility: {e}")
            return False

    def dismiss_keyboard_in_modal(
        self, modal_root_locator, find_element_safe_func
    ) -> bool:
        """Dismiss keyboard by tapping within modal header area (avoids Back navigation)."""
        try:
            root = find_element_safe_func(modal_root_locator, timeout=1)
            if not root:
                try:
                    size = self.driver.get_window_size()
                    self.gestures.swipe_down(
                        int(size["width"] * 0.5) - 10,
                        int(size["height"] * 0.3),
                        20,
                        int(size["height"] * 0.2),
                        0.6,
                    )
                    return True
                except Exception:
                    return False

            rect = root.rect
            x = int(rect.get("x", 0)) + int(rect.get("width", 800)) // 2
            y = int(rect.get("y", 0)) + 24

            try:
                self.gestures.tap(x, y)
                return True
            except Exception:
                return False

        except Exception:
            return False
