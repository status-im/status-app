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

    def is_ready(self, timeout: Optional[int] = None) -> bool:
        return self.is_element_visible(
            self.locators.LEFT_NAV_ANY, timeout=timeout
        ) or self.is_element_visible(self.locators.HOME_DOCK_CONTAINER, timeout=timeout)

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

    def navigate_to(self, section: str, timeout: int = 30) -> bool:
        section = section.lower()
        if self.has_left_nav(timeout=1):
            target = {
                "home": self.locators.LEFT_NAV_HOME,
                "wallet": self.locators.LEFT_NAV_WALLET,
                "market": self.locators.LEFT_NAV_MARKET,
                "messaging": self.locators.LEFT_NAV_MESSAGES,
                "messages": self.locators.LEFT_NAV_MESSAGES,
                "communities": self.locators.LEFT_NAV_COMMUNITIES,
                "settings": self.locators.LEFT_NAV_SETTINGS,
            }.get(section)
            if not target:
                return False
            return self.safe_click(target)
        target = {
            "home": self.locators.HOME_DOCK_CONTAINER,
            "wallet": self.locators.DOCK_WALLET,
            "market": self.locators.DOCK_MARKET,
            "messaging": self.locators.DOCK_MESSAGES,
            "messages": self.locators.DOCK_MESSAGES,
            "communities": self.locators.DOCK_COMMUNITIES,
            "settings": self.locators.DOCK_SETTINGS,
        }.get(section)
        if not target:
            return False
        if section == "home":
            return self.is_element_visible(
                self.locators.HOME_DOCK_CONTAINER, timeout=timeout
            )
        return self.safe_click(target)

    # Convenience wrappers
    def click_home(self) -> bool:
        return self.navigate_to("home")

    def click_wallet(self) -> bool:
        return self.navigate_to("wallet")

    def click_messages(self) -> bool:
        return self.navigate_to("messaging")

    def click_communities(self) -> bool:
        return self.navigate_to("communities")

    def click_market(self) -> bool:
        return self.navigate_to("market")

    def click_settings(self) -> bool:
        return self.navigate_to("settings", timeout=4, max_attempts=2)

    def click_settings_left_nav(self) -> bool:
        return self.safe_click(
            self.locators.LEFT_NAV_SETTINGS, timeout=4, max_attempts=2
        )

    def wait_for_toast(
        self,
        expected_substring: Optional[str] = None,
        timeout: float = 6.0,
        poll_interval: float = 0.2,
        stability: float = 0.0,
    ) -> Optional[str]:
        """Poll for a toast message and optionally match its content."""

        deadline = time.time() + (timeout or 0)
        last_seen: Optional[str] = None

        while time.time() < deadline:
            remaining = max(deadline - time.time(), 0.3)
            desc = self.get_toast_content_desc(timeout=remaining)
            if desc:
                last_seen = desc
                matches = (
                    not expected_substring or expected_substring.lower() in desc.lower()
                )
                if matches:
                    if stability > 0:
                        stable_until = time.time() + stability
                        while time.time() < stable_until:
                            if not self.is_element_visible(
                                self.locators.ANY_TOAST, timeout=0.1
                            ):
                                break
                            time.sleep(0.05)
                        else:
                            self.logger.info(f"Toast detected text='{desc}'")
                            try:
                                save_page_source(
                                    self.driver, self._screenshots_dir, "toast"
                                )
                            except Exception as e:
                                self.logger.debug(f"Toast page source save failed: {e}")
                            return desc
                    else:
                        self.logger.info(f"Toast detected text='{desc}'")
                        try:
                            save_page_source(
                                self.driver, self._screenshots_dir, "toast"
                            )
                        except Exception as e:
                            self.logger.debug(f"Toast page source save failed: {e}")
                        return desc

            time.sleep(min(poll_interval, max(deadline - time.time(), 0.1)))

        if last_seen:
            self.logger.debug(
                "Toast detected but did not match expectation: '%s'", last_seen
            )
        return None

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
