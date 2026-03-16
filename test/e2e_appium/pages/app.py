import time

from locators.app_locators import AppLocators
from utils.element_state_checker import ElementStateChecker
from utils.screenshot import save_page_source

from .base_page import BasePage


class App(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = AppLocators()

    def has_left_nav(self, timeout: int | None = 1) -> bool:
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
        self._ensure_main_nav_visible()
        return self._click_nav_item(self.locators.LEFT_NAV_SETTINGS)

    def click_messages_button(self) -> bool:
        self.logger.info("Clicking Messages button")
        if self.active_section() == "messaging":
            self.logger.info("Already in Messages section — skipping nav")
            return True
        self._ensure_main_nav_visible()
        return self._click_nav_item(self.locators.LEFT_NAV_MESSAGES)

    def click_communities_button(self) -> bool:
        self.logger.info("Clicking Communities button")
        self._ensure_main_nav_visible()
        return self._click_nav_item(self.locators.LEFT_NAV_COMMUNITIES)

    def click_wallet_button(self) -> bool:
        self.logger.info("Clicking Wallet button")
        if self.active_section() == "wallet":
            self.logger.info("Already in Wallet section — skipping nav")
            return True
        self._ensure_main_nav_visible()
        return self._click_nav_item(self.locators.LEFT_NAV_WALLET)

    def click_market_button(self) -> bool:
        self.logger.info("Clicking Market button")
        self._ensure_main_nav_visible()
        return self._click_nav_item(self.locators.LEFT_NAV_MARKET)

    def _click_nav_item(self, locator: tuple, timeout: int = 10) -> bool:
        """Click a nav-bar item and, in portrait mode, wait for the drawer to close.

        After the click the PrimaryNavSidebar drawer plays a close animation.
        If the caller checks for the target section immediately it may not be
        visible yet.  This helper waits for the nav bar to disappear before
        returning.
        """
        clicked = self.safe_click(locator, timeout=timeout, max_attempts=2)
        if not clicked:
            return False

        if self.is_portrait_mode():
            # Wait for the drawer to close — nav items should disappear
            self.wait_for_invisibility(self.locators.LEFT_NAV_ANY, timeout=5)
            # Allow destination page to begin rendering after drawer animation
            time.sleep(0.5)

        return True

    def _ensure_main_nav_visible(self) -> bool:
        """Ensure the left navigation bar is visible.

        In landscape the nav bar is always visible.  In portrait it is a
        drawer that slides from the left edge.  This method first presses
        back buttons to unwind deep navigation, then swipes from the left
        edge to open the drawer.
        """
        if self.is_element_visible(self.locators.LEFT_NAV_SETTINGS, timeout=2):
            return True

        if not self.is_portrait_mode():
            return self.is_element_visible(self.locators.LEFT_NAV_SETTINGS, timeout=5)

        # Phase 1: unwind deep navigation stack via back button
        for _ in range(5):
            if self.is_element_visible(self.locators.LEFT_NAV_SETTINGS, timeout=1):
                return True
            if not self.is_element_visible(
                self.locators.TOOLBAR_BACK_BUTTON, timeout=1
            ):
                break
            self.safe_click(self.locators.TOOLBAR_BACK_BUTTON, timeout=2)

        if self.is_element_visible(self.locators.LEFT_NAV_SETTINGS, timeout=1):
            return True

        # Phase 2: drag the drawer handle to open the nav drawer
        for attempt in range(3):
            if self._open_nav_drawer():
                break
            self.logger.debug("Nav drawer open attempt %d did not reveal nav", attempt + 1)

        return self.is_element_visible(self.locators.LEFT_NAV_SETTINGS, timeout=5)

    # Locator for the drawer swipe-indicator handle visible in portrait mode.
    NAV_DRAWER_HANDLE = (
        "xpath",
        "//android.view.View[@clickable='true' and @bounds]"
        "[number(substring-before(substring-after(@bounds,'['),','))<=10]",
    )

    def _open_nav_drawer(self) -> bool:
        """Open the left navigation drawer in portrait mode.

        Strategies tried in order:
        1. mobile: dragGesture with elementId (Pixel-friendly).
        2. W3C pointer actions from handle position (Samsung-friendly,
           avoids system gesture zones).
        3. Coordinate-based drag fallback.
        """
        try:
            size = self.driver.get_window_size()
            w = size["width"]
            h = size["height"]

            # Strategy 1: element-based mobile: dragGesture
            handle = self.find_element_safe(self.NAV_DRAWER_HANDLE, timeout=2)
            if handle:
                handle_rect = handle.rect
                try:
                    self.driver.execute_script("mobile: dragGesture", {
                        "elementId": handle.id,
                        "endX": int(w * 0.7),
                        "endY": int(handle_rect["y"] + handle_rect["height"] / 2),
                    })
                    if self.is_element_visible(self.locators.LEFT_NAV_ANY, timeout=3):
                        return True
                except Exception as e:
                    self.logger.debug("Strategy 1 (element drag) failed: %s", e)

                # Strategy 2: W3C touch actions from handle centre
                try:
                    from selenium.webdriver.common.actions import interaction
                    from selenium.webdriver.common.actions.action_builder import ActionBuilder
                    from selenium.webdriver.common.actions.pointer_input import PointerInput

                    start_x = int(handle_rect["x"] + handle_rect["width"] / 2)
                    start_y = int(handle_rect["y"] + handle_rect["height"] / 2)
                    end_x = int(w * 0.7)

                    actions = ActionBuilder(
                        self.driver,
                        mouse=PointerInput(interaction.POINTER_TOUCH, "finger"),
                    )
                    actions.pointer_action.move_to_location(start_x, start_y)
                    actions.pointer_action.pointer_down()
                    actions.pointer_action.pause(0.1)
                    actions.pointer_action.move_to_location(end_x, start_y)
                    actions.pointer_action.pause(0.05)
                    actions.pointer_action.pointer_up()
                    actions.perform()

                    if self.is_element_visible(self.locators.LEFT_NAV_ANY, timeout=3):
                        return True
                except Exception as e:
                    self.logger.debug("Strategy 2 (W3C actions) failed: %s", e)

            # Strategy 3: coordinate-based drag from left-centre area
            try:
                self.driver.execute_script("mobile: dragGesture", {
                    "startX": int(w * 0.08),
                    "startY": int(h * 0.5),
                    "endX": int(w * 0.7),
                    "endY": int(h * 0.5),
                })
                if self.is_element_visible(self.locators.LEFT_NAV_ANY, timeout=3):
                    return True
            except Exception as e:
                self.logger.debug("Strategy 3 (coordinate drag) failed: %s", e)

            return False
        except Exception as e:
            self.logger.debug("_open_nav_drawer failed: %s", e)
            return False

    def click_settings_button(self) -> bool:
        self.logger.info("Clicking Settings button")
        if self.active_section() == "settings":
            self.logger.info("Already in Settings section — skipping nav")
            return True
        self._ensure_main_nav_visible()
        return self._click_nav_item(self.locators.LEFT_NAV_SETTINGS)

    def open_profile_menu(self) -> bool:
        self.logger.info("Opening profile menu from main navigation")
        self._ensure_main_nav_visible()
        return self.safe_click(self.locators.PROFILE_NAV_BUTTON, timeout=5)

    def copy_profile_link_from_menu(self, timeout: int = 5) -> str | None:
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
        expected_substring: str | None = None,
        timeout: float = 6.0,
        poll_interval: float = 0.2,
        stability: float = 0.0,
    ) -> str | None:
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
        last_seen: str | None = None

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

    def is_toast_present(self, timeout: int | None = 3) -> bool:
        return self.wait_for_toast(timeout=timeout or 3.0) is not None

    def get_toast_content_desc(self, timeout: int | None = 3) -> str | None:
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
