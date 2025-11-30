from typing import Optional
import time

from .base_page import BasePage
from locators.app_locators import AppLocators
from utils.screenshot import save_page_source
from utils.element_state_checker import ElementStateChecker


class App(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = AppLocators()

    def has_left_nav(self, timeout: Optional[int] = 1) -> bool:
        return self.is_element_visible(self.locators.LEFT_NAV_ANY, timeout=timeout)

    def active_section(self) -> str:
        """Return current section: home, messaging, wallet, communities, market, settings, unknown."""
        if self.has_left_nav(timeout=1):
            mapping = {
                "home": self.locators.LEFT_NAV_HOME,
                "wallet": self.locators.LEFT_NAV_WALLET,
                "market": self.locators.LEFT_NAV_MARKET,
                "messaging": self.locators.LEFT_NAV_MESSAGES,
                "communities": self.locators.LEFT_NAV_COMMUNITIES,
                "settings": self.locators.LEFT_NAV_SETTINGS,
            }
            for name, locator in mapping.items():
                el = self.find_element_safe(locator, timeout=1)
                if el is not None:
                    try:
                        checked = ElementStateChecker.is_checked(el)
                        if checked:
                            return name
                    except Exception:
                        pass
            return "unknown"
        if self.is_element_visible(self.locators.HOME_DOCK_CONTAINER, timeout=1):
            return "home"
        return "unknown"

    def click_settings_left_nav(self) -> bool:
        self.gestures.tap(500, 200)
        return self.safe_click(
            self.locators.LEFT_NAV_SETTINGS, timeout=10, max_attempts=2
        )

    def click_messages_button(self) -> bool:
        self.logger.info("Clicking Messages button")
        return self.safe_click(self.locators.LEFT_NAV_MESSAGES)

    def _ensure_main_nav_visible(self) -> bool:
        if self.is_portrait_mode() and self.is_element_visible(
            self.locators.TOOLBAR_BACK_BUTTON, timeout=2
        ):
            self.safe_click(self.locators.TOOLBAR_BACK_BUTTON, timeout=2)
        return self.is_element_visible(self.locators.LEFT_NAV_SETTINGS, timeout=5)

    def click_settings_button(self) -> bool:
        self.logger.info("Clicking Settings button")
        self._ensure_main_nav_visible()
        return self.safe_click(self.locators.LEFT_NAV_SETTINGS, timeout=10)

    def open_profile_menu(self) -> bool:
        self.logger.info("Opening profile menu from main navigation")
        return self.safe_click(self.locators.PROFILE_NAV_BUTTON, timeout=5)

    def copy_profile_link_from_menu(self, timeout: int = 5) -> Optional[str]:
        if not self.open_profile_menu():
            self.logger.error("Failed to open profile menu")
            return None

        try:
            self.driver.set_clipboard_text("")
        except Exception as exc:
            self.logger.debug("Unable to reset clipboard before copy: %s", exc)

        if not self.safe_click(self.locators.COPY_PROFILE_LINK_ACTION, timeout=timeout):
            self.logger.error("Failed to trigger copy-link action from profile menu")
            return None

        def has_clipboard_value():
            try:
                return bool(self.driver.get_clipboard_text().strip())
            except Exception as exc:
                self.logger.debug("Clipboard polling failed: %s", exc)
                return False

        if not self.wait_for_condition(has_clipboard_value, timeout=timeout):
            self.logger.error("Clipboard did not receive profile link within timeout")
            return None

        try:
            return self.driver.get_clipboard_text().strip()
        except Exception as exc:
            self.logger.error("Failed to read profile link from clipboard: %s", exc)
            return None

    def wait_for_toast(
        self,
        expected_substring: Optional[str] = None,
        timeout: float = 6.0,
        poll_interval: float = 0.2,
        stability: float = 0.0,
    ) -> Optional[str]:
        """Poll for a toast message and optionally match its content.

        Args:
            expected_substring: Text to match (case-insensitive). If None, any toast matches.
            timeout: Max wait time in seconds.
            poll_interval: How often to check for toast.
            stability: Extra time toast must remain visible before accepting.

        Returns:
            Toast text if found and matched, None otherwise.
        """
        deadline = time.time() + timeout
        last_seen: Optional[str] = None

        while time.time() < deadline:
            desc = self.get_toast_content_desc(timeout=max(deadline - time.time(), 0.3))
            if not desc:
                time.sleep(min(poll_interval, max(deadline - time.time(), 0.1)))
                continue

            last_seen = desc
            matches = not expected_substring or expected_substring.lower() in desc.lower()
            if not matches:
                time.sleep(poll_interval)
                continue

            # Stability check: ensure toast stays visible
            if stability > 0 and not self._is_toast_stable(stability):
                continue

            self.logger.info("Toast detected text='%s'", desc)
            self._save_toast_debug()
            return desc

        if last_seen:
            self.logger.debug("Toast detected but did not match: '%s'", last_seen)
        return None

    def _is_toast_stable(self, duration: float) -> bool:
        """Check if toast remains visible for the specified duration."""
        end_time = time.time() + duration
        while time.time() < end_time:
            if not self.is_element_visible(self.locators.ANY_TOAST, timeout=0.1):
                return False
            time.sleep(0.05)
        return True

    def _save_toast_debug(self) -> None:
        """Save page source for toast debugging."""
        try:
            save_page_source(self.driver, self._screenshots_dir, "toast")
        except Exception as e:
            self.logger.debug("Toast page source save failed: %s", e)

    def is_toast_present(self, timeout: Optional[int] = 3) -> bool:
        return self.wait_for_toast(timeout=timeout or 3.0) is not None

    def get_toast_content_desc(self, timeout: Optional[int] = 3) -> Optional[str]:
        """Return toast's content-desc, polling until non-empty or timeout."""
        try:
            el = self.find_element_safe(self.locators.ANY_TOAST, timeout=timeout)
            if el is None:
                return None

            end = time.time() + (timeout or 0)
            last_val: str = ""
            while True:
                try:
                    val = el.get_attribute("content-desc") or ""
                    if val:
                        return val
                    last_val = val
                except Exception:
                    pass
                if time.time() >= end:
                    return last_val or None
                time.sleep(0.1)
        except Exception:
            return None
