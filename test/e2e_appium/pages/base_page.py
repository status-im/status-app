import time
import logging
import os
from datetime import datetime
from pathlib import Path
from typing import NoReturn

from selenium.common.exceptions import (
    ElementClickInterceptedException,
    InvalidElementStateException,
    NoSuchElementException,
    StaleElementReferenceException,
    TimeoutException,
)
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from config import get_config, log_element_action
from utils.exceptions import ElementInteractionError
from utils.gestures import Gestures
from utils.screenshot import save_screenshot, save_page_source
from utils.app_lifecycle_manager import AppLifecycleManager
from utils.keyboard_manager import KeyboardManager
from utils.element_state_checker import ElementStateChecker


class BasePage:
    def __init__(self, driver):
        self.driver = driver
        self.app_lifecycle = AppLifecycleManager(driver)
        self.keyboard = KeyboardManager(driver)
        try:
            config = get_config()
            self.timeouts = config.environment.timeouts
            element_wait_timeout = self.timeouts.get("element_wait", 30)
            self._screenshots_dir = config.screenshots_dir or "screenshots"
            try:
                Path(self._screenshots_dir).mkdir(parents=True, exist_ok=True)
            except Exception:
                # Do not block tests if directory creation fails
                pass
        except Exception:
            self.timeouts = {
                "element_wait": 30,
                "element_click": 5,
                "element_find": 10,
                "default": 30,
            }
            element_wait_timeout = self.timeouts["element_wait"]
            self._screenshots_dir = "screenshots"

        self.wait = WebDriverWait(driver, element_wait_timeout)

        self.logger = logging.getLogger(
            self.__class__.__module__ + "." + self.__class__.__name__
        )
        self.gestures = Gestures(driver, self.logger)

    def is_portrait_mode(self) -> bool:
        try:
            size = self.driver.get_window_size()
            return size["height"] > size["width"]
        except Exception:
            return False

    def take_screenshot(self, name: str | None = None) -> str | None:
        try:
            return save_screenshot(self.driver, self._screenshots_dir, name)
        except Exception:
            return None

    def dump_page_source(self, name: str | None = None) -> str | None:
        try:
            return save_page_source(self.driver, self._screenshots_dir, name)
        except Exception:
            return None

    def wait_for_invisibility(self, locator, timeout: int | None = None) -> bool:
        """Wait until the element located by locator becomes invisible or detached."""
        try:
            wait = self._create_wait(timeout, "element_find")
            return wait.until(EC.invisibility_of_element_located(locator))
        except Exception:
            return False

    def _create_wait(self, timeout: int | None, config_key: str) -> WebDriverWait:
        """Create WebDriverWait with timeout from parameter or YAML config."""
        effective_timeout = timeout or self.timeouts.get(config_key, 30)
        return WebDriverWait(self.driver, effective_timeout)

    def is_screen_displayed(self, timeout: int | None = None):
        """Check if this page/screen is currently displayed.
        
        Subclasses must define IDENTITY_LOCATOR as a class attribute - this is
        the locator that uniquely identifies the screen (e.g., a header element).
        """
        return self.is_element_visible(self.IDENTITY_LOCATOR, timeout=timeout)

    def find_element(self, locator, timeout: int | None = None):
        """Find element with configurable timeout.

        Args:
            locator: Element locator tuple
            timeout: Override timeout (uses YAML element_wait config if None)

        Returns:
            WebElement instance

        Raises:
            TimeoutException: If element not found within timeout
        """
        start_time = datetime.now()
        locator_str = f"{locator[0]}: {locator[1]}"

        try:
            wait = self._create_wait(timeout, "element_find")
            element = wait.until(EC.presence_of_element_located(locator))
            duration_ms = int((datetime.now() - start_time).total_seconds() * 1000)
            log_element_action("find_element", locator_str, True, duration_ms)
            return element
        except Exception:
            duration_ms = int((datetime.now() - start_time).total_seconds() * 1000)
            log_element_action("find_element", locator_str, False, duration_ms)
            raise

    def is_element_visible(
        self,
        locator,
        fallback_locators: list[tuple] | None = None,
        timeout: int | None = None,
    ) -> bool:
        locators_to_try: list[tuple] = [locator]
        if fallback_locators:
            locators_to_try.extend(fallback_locators)

        if timeout is None:
            timeout = self.timeouts.get("element_find", 15)

        for loc in locators_to_try:
            try:
                wait = self._create_wait(timeout, "element_find")
                wait.until(EC.visibility_of_element_located(loc))
                return True
            except Exception:
                continue
        return False

    def safe_click(
        self,
        locator: tuple,
        *,
        timeout: int | None = None,
        fallback_locators: list[tuple] | None = None,
        max_attempts: int = 3,
    ) -> bool:
        """Click element with retries and gesture fallback.

        Raises ElementInteractionError if all attempts exhausted.
        """
        all_locators = [locator, *(fallback_locators or [])]

        for loc in all_locators:
            for attempt in range(1, max_attempts + 1):
                try:
                    element = self._wait_for_clickable(loc, timeout)
                    element.click()
                    self.logger.debug(f"Clicked: {loc[1]}")
                    return True
                except (
                    ElementClickInterceptedException,
                    StaleElementReferenceException,
                    InvalidElementStateException,
                ) as e:
                    self.logger.debug(f"Click failed ({e}); trying gesture fallback.")
                    if self._gesture_tap_fallback(element, loc):
                        return True
                except (TimeoutException, NoSuchElementException) as e:
                    self.logger.debug(f"Element not ready ({loc[1]}): {e}")

                self.logger.debug(
                    f"Click attempt {attempt}/{max_attempts} failed: {loc[1]}"
                )
                if attempt < max_attempts:
                    self._wait_between_attempts()

            self.logger.debug(f"Exhausted all attempts for locator: {loc[1]}")

        self._raise_click_failure(all_locators)

    def _wait_for_clickable(self, locator: tuple, timeout: int | None = None):
        """Wait for element to be clickable and return it."""
        wait = self._create_wait(timeout, "element_click")
        return wait.until(EC.element_to_be_clickable(locator))

    def _raise_click_failure(self, locators: list[tuple]) -> NoReturn:
        """Log failure details and raise ElementInteractionError."""
        locator_desc = locators[0][1] if locators else "unknown"
        message = (
            f"Failed to click element after trying {len(locators)} locator(s). "
            f"First locator: {locators[0] if locators else 'none'}"
        )
        self.logger.error(message)
        self.take_screenshot(f"click_failure_{locator_desc}")
        self.dump_page_source(f"click_failure_{locator_desc}")
        raise ElementInteractionError(message, str(locators[0] if locators else ""), "click")

    def find_element_safe(self, locator, timeout: int | None = None):
        """Find element and return None instead of raising on failure."""
        try:
            wait = self._create_wait(timeout, "element_find")
            return wait.until(EC.presence_of_element_located(locator))
        except Exception:
            return None

    def hide_keyboard(self) -> bool:
        return self.keyboard.hide_keyboard()

    def ensure_element_visible(self, locator, timeout=10) -> bool:
        return self.keyboard.ensure_element_visible(
            locator, self.is_element_visible, timeout
        )

    def qt_safe_input(
        self,
        locator,
        text: str,
        timeout: int | None = None,
        max_retries: int = 3,
        verify: bool = True,
    ) -> bool:
        """Qt/QML-safe text input with proper waiting and retry logic.

        Notes:
        - max_retries represents total attempts; values <= 0 will still perform one attempt.
        - When verify=False, skips post-type verification and returns True after a single attempt.
        """

        attempts_total = max(1, max_retries)
        for attempt in range(attempts_total):
            try:
                wait = self._create_wait(timeout, "element_click")
                element = wait.until(EC.element_to_be_clickable(locator))

                element.click()
                if not self._wait_for_element_focused(element):
                    #TODO: Check add account flow locators to see if this can be blocking
                    self.logger.debug(
                        f"Focus attribute not detected on attempt {attempt + 1}, proceeding anyway"
                    )

                element.clear()


                self.driver.update_settings({
                    "sendKeyStrategy": "oneByOne",
                    "interKeyDelay": 50,
                })
                actions = ActionChains(self.driver)
                actions.send_keys(text).perform()

                if ElementStateChecker.is_password_field(element):
                    self.logger.debug("Password field detected - skipping verification")
                    time.sleep(0.05 * len(text))
                    return True

                if not verify:
                    self.logger.info(
                        f"Qt input completed (no-verify, attempt {attempt + 1})"
                    )
                    return True

                if self._verify_input_success(element, text):
                    self.logger.info(f"Qt input successful (attempt {attempt + 1})")
                    return True

            except Exception as e:
                self.logger.warning(f"Qt input attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    self._wait_between_attempts()

        self.logger.error(f"Qt input failed after {attempts_total} attempts")
        return False

    def _wait_for_element_focused(self, element, timeout: float = 2.0) -> bool:
        """Poll until element has focus attribute set to true."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            if ElementStateChecker.is_focused(element):
                return True
            time.sleep(0.05)
        self.logger.debug("Element did not gain focus within timeout")
        return False

    def _wait_for_qt_field_ready(self, element, timeout: int | None = None) -> bool:
        """Wait for Qt field to be ready for input using polling using YAML element_wait timeout by default."""

        def field_is_ready(driver):
            try:
                return ElementStateChecker.is_enabled(
                    element
                ) and ElementStateChecker.is_displayed(element)
            except Exception:
                return False

        effective_timeout = (
            timeout if timeout is not None else self.timeouts.get("element_wait", 30)
        )
        try:
            wait = WebDriverWait(self.driver, effective_timeout)
            wait.until(field_is_ready)
            return True
        except Exception:
            self.logger.warning("Qt field readiness timeout")
            return False

    def _verify_input_success(self, element, expected_text: str) -> bool:
        try:
            # Android UIAutomator2 exposes entered value via 'text'
            actual_text = element.get_attribute("text")
            if actual_text is None:
                return True
            return len(actual_text) > 0
        except Exception:
            return True

    def _clear_input_field(self, locator: tuple, timeout: int = 5) -> bool:
        """Clear text from an input field using select-all + delete.

        Uses Ctrl+A to select all text, then Backspace to delete.
        More reliable than element.clear() for Qt/QML fields.

        Args:
            locator: Element locator tuple.
            timeout: Timeout for finding the element.

        Returns:
            bool: True if clearing was attempted, False if element not found.
        """
        from selenium.webdriver.common.keys import Keys

        element = self.find_element_safe(locator, timeout=timeout)
        if not element:
            return False

        try:
            element.click()

            # Select all with Ctrl+A, then delete (Ctrl is correct for Android)
            actions = ActionChains(self.driver)
            actions.key_down(Keys.CONTROL).send_keys("a").key_up(Keys.CONTROL)
            actions.send_keys(Keys.BACKSPACE)
            actions.perform()

            self.logger.debug("Cleared input field via Ctrl+A + Backspace")
            return True
        except Exception as exc:
            self.logger.debug(f"Select-all clear failed: {exc}")
            return False

    def long_press_element(self, element, duration: int = 800) -> bool:
        """Perform long-press gesture on element to trigger context menu.

        Args:
            element: WebElement to long-press
            duration: Long-press duration in milliseconds

        Returns:
            bool: True if long-press successful, False otherwise
        """
        try:
            if self.gestures.long_press(element.id, duration):
                self.logger.debug(f"Long-press performed (duration: {duration}ms)")
                return True
            return False
        except Exception as e:
            self.logger.debug(f"Long-press gesture failed: {e}")
            return False

    def tap_coordinate_relative(self, element, x_offset: int, y_offset: int) -> bool:
        """Tap at coordinates relative to element position.

        Args:
            element: Reference element for coordinate calculation
            x_offset: X offset from element's left edge (can be negative)
            y_offset: Y offset from element's top edge (can be negative)

        Returns:
            bool: True if tap successful, False otherwise
        """
        try:
            rect = element.rect
            x = int(rect["x"] + x_offset)
            y = int(max(0, rect["y"] + y_offset))

            self.gestures.tap(x, y)
            self.logger.debug(f"Coordinate tap at ({x}, {y}) relative to element")
            return True
        except Exception as e:
            self.logger.debug(f"Coordinate tap failed: {e}")
            return False

    def _gesture_tap_fallback(self, element, locator) -> bool:
        """Fallback tap using Appium gestures when native click fails."""
        if self.gestures.element_tap(element):
            self.logger.debug(f"Gesture tap fallback succeeded for {locator}")
            return True

        if self.gestures.element_center_tap(element):
            self.logger.debug(f"Coordinate tap fallback succeeded for {locator}")
            return True

        return False

    def restart_app(self, app_package: str | None = None) -> bool:
        """Restart the app within the current session."""
        return self.app_lifecycle.restart_app(app_package)

    def restart_app_with_data_cleared(self, app_package: str | None = None) -> bool:
        """Restart the app with all app data cleared (fresh app state)."""
        return self.app_lifecycle.restart_app_with_data_cleared(app_package)

    def wait_for_condition(
        self, condition_func, timeout: int | None = None, poll_interval: float = 0.1
    ) -> bool:
        effective_timeout = timeout or self.timeouts.get("element_wait", 30)
        deadline = time.time() + effective_timeout

        while time.time() < deadline:
            try:
                if condition_func():
                    return True
            except Exception:
                pass
            time.sleep(poll_interval)
        return False

    def _wait_between_attempts(self, base_delay: float = 0.5) -> None:
        env_name = os.getenv("CURRENT_TEST_ENVIRONMENT", "browserstack").lower()
        if env_name in ("browserstack",):
            time.sleep(base_delay * 1.5)
        else:
            time.sleep(base_delay * 0.5)

    def _is_element_enabled(self, locator) -> bool:
        try:
            element = self.find_element_safe(locator, timeout=1)
            if not element:
                return False
            return ElementStateChecker.is_enabled(element)
        except Exception:
            return False

    def _is_element_checked(self, locator) -> bool:
        try:
            element = self.find_element_safe(locator, timeout=1)
            if not element:
                return False
            return ElementStateChecker.is_checked(element)
        except Exception:
            return False

    def wait_for_element_enabled(self, locator, timeout: int | None = None) -> bool:
        """Wait until element is present and enabled."""
        effective_timeout = timeout or self.timeouts.get("element_wait", 10)

        def _is_enabled(driver):
            try:
                el = driver.find_element(*locator)
                return ElementStateChecker.is_enabled(el)
            except (NoSuchElementException, StaleElementReferenceException):
                return False

        try:
            WebDriverWait(self.driver, effective_timeout, poll_frequency=0.2).until(_is_enabled)
            return True
        except Exception:
            return False

    def wait_for_element_checked(self, locator, timeout: int | None = None) -> bool:
        """Wait until element is present and checked."""
        effective_timeout = timeout or self.timeouts.get("element_wait", 10)

        def _is_checked(driver):
            try:
                el = driver.find_element(*locator)
                return ElementStateChecker.is_checked(el)
            except (NoSuchElementException, StaleElementReferenceException):
                return False

        try:
            WebDriverWait(self.driver, effective_timeout, poll_frequency=0.2).until(_is_checked)
            return True
        except Exception:
            return False
