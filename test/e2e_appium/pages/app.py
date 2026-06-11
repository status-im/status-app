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
        return self.click_settings_button()

    def click_messages_button(self) -> bool:
        self.logger.info("Clicking Messages button")
        if self.active_section() == "messaging":
            self.logger.info("Already in Messages section — skipping nav")
            return True
        from utils.screen_identity import SCREEN_ANCHORS
        return self._click_drawer_nav_with_verify(
            nav_locator=self.locators.LEFT_NAV_MESSAGES,
            landmark_locator=SCREEN_ANCHORS["messages"],
            nav_name="Messages",
        )

    def click_communities_button(self) -> bool:
        self.logger.info("Clicking Communities button")
        self._ensure_main_nav_visible()
        return self._click_nav_item(self.locators.LEFT_NAV_COMMUNITIES)

    def click_wallet_button(self) -> bool:
        self.logger.info("Clicking Wallet button")
        if self.active_section() == "wallet":
            self.logger.info("Already in Wallet section — skipping nav")
            return True
        from utils.screen_identity import SCREEN_ANCHORS
        return self._click_drawer_nav_with_verify(
            nav_locator=self.locators.LEFT_NAV_WALLET,
            landmark_locator=SCREEN_ANCHORS["wallet"],
            nav_name="Wallet",
        )

    def click_market_button(self) -> bool:
        self.logger.info("Clicking Market button")
        self._ensure_main_nav_visible()
        return self._click_nav_item(self.locators.LEFT_NAV_MARKET)

    def _click_nav_item(
        self,
        locator: tuple,
        timeout: int = 10,
        strategy: str = "w3c",
    ) -> bool:
        # Branch on app layout (side-nav visible?), not device orientation —
        # wide tablets in portrait still render the side-nav which never
        # disappears, so the drawer-close wait below would never succeed.
        if self.is_element_visible(self.locators.LEFT_NAV_ANY, timeout=1):
            return self.safe_click(locator, timeout=timeout, max_attempts=2)

        for attempt in range(1, 4):
            el = self.find_element_safe(locator, timeout=timeout)
            if el is None:
                self.logger.warning(
                    "Nav item not found on attempt %d", attempt
                )
                self.dump_page_source(f"nav_item_not_found_a{attempt}")
                # Try re-opening the drawer in case it closed between
                # _ensure_main_nav_visible and the lookup.
                if attempt < 3:
                    self._ensure_main_nav_visible()
                    time.sleep(0.5)
                    continue
                return False
            rect = el.rect
            cx = int(rect["x"] + rect["width"] / 2)
            cy = int(rect["y"] + rect["height"] / 2)

            try:
                if strategy == "native":
                    self.logger.info(
                        "Nav-item mobile:clickGesture attempt %d at (%d,%d)",
                        attempt, cx, cy,
                    )
                    self.driver.execute_script(
                        "mobile: clickGesture", {"elementId": el.id},
                    )
                else:
                    self.logger.info(
                        "Nav-item W3C-pointer click attempt %d at (%d,%d)",
                        attempt, cx, cy,
                    )
                    if not self.gestures.tap(cx, cy):
                        raise RuntimeError("gestures.tap returned False")
            except Exception as exc:
                self.logger.warning(
                    "Nav-item click failed on attempt %d: %s", attempt, exc
                )
                continue

            if self.wait_for_invisibility(self.locators.LEFT_NAV_ANY, timeout=5):
                # Drawer closed → tap registered. Allow destination page to
                # begin rendering after drawer animation.
                time.sleep(0.5)
                return True

            self.logger.warning(
                "Drawer still open after nav-item click attempt %d — retrying",
                attempt,
            )

        return False

    def _ensure_main_nav_visible(self) -> bool:
        """Ensure the left navigation bar is visible.

        Detect layout by side-nav visibility — don't trust device orientation;
        the app's QML picks layout based on width, so wide tablets in portrait
        still get the always-visible side-nav.
        """
        if self.is_element_visible(self.locators.LEFT_NAV_SETTINGS, timeout=2):
            return True

        if self.is_element_visible(self.locators.LEFT_NAV_ANY, timeout=1):
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
        from utils.screen_identity import SCREEN_ANCHORS
        return self._click_drawer_nav_with_verify(
            nav_locator=self.locators.LEFT_NAV_SETTINGS,
            landmark_locator=SCREEN_ANCHORS["settings"],
            nav_name="Settings",
        )

    def _click_drawer_nav_with_verify(
        self,
        nav_locator: tuple,
        landmark_locator: tuple,
        nav_name: str,
    ) -> bool:
        """Drawer nav click + landmark verify, retrying with strategy variation.

        On BS portrait the nav-item tap can close the drawer without firing
        onClicked. We verify by destination-page landmark and retry, varying
        strategy so a deterministic gesture race doesn't pin us at the same
        failure mode. ``activate_app()`` between attempts unsticks the
        drawer's gesture handler.
        """
        # W3C first: native clickGesture taps by elementId and inherits the
        # a11y-bounds/rendered-rail mismatch on phone portrait, so it can
        # mis-target a neighbouring item. The W3C pointer taps computed
        # coordinates and survives it; native stays as the late fallback.
        strategies = ["w3c", "w3c", "native", "native"]
        pkg = self.driver.capabilities.get("appPackage") or "app.status.mobile"

        # On a second call within ~1min of a successful first, the
        # drawer's gesture handler stays wedged and consumes taps
        # without firing onClicked. activate_app shakes it loose.
        def _shake_app():
            try:
                self.driver.activate_app(pkg)
            except Exception as exc:
                self.logger.debug("activate_app suppressed: %s", exc)

        # BACK closes the drawer cleanly when activate_app's foregrounding
        # alone fails to unstick a wedged gesture handler. Status Mobile
        # is a single-Activity app (StatusQtActivity), so BACK at the
        # chat-list root with no drawer open exits the Activity to the
        # system home screen, backgrounding Status. The subsequent
        # activate_app doesn't always re-foreground in time before the
        # next gesture lands on the launcher. So only press BACK when
        # the drawer is actually open.
        def _reset_drawer_state():
            if self.is_element_visible(self.locators.LEFT_NAV_ANY, timeout=1):
                try:
                    self.driver.press_keycode(4)  # KEYCODE_BACK
                except Exception as exc:
                    self.logger.debug("press_keycode(BACK) suppressed: %s", exc)
            else:
                self.logger.debug(
                    "drawer already closed — skipping BACK to keep Status foreground"
                )
            time.sleep(0.5)

        _shake_app()
        time.sleep(0.6)  # let activate_app foregrounding settle

        from utils.screen_identity import dismiss_backup_modal

        slug = nav_name.lower().replace(" ", "_")
        for attempt in range(1, len(strategies) + 1):
            if attempt > 1:
                _reset_drawer_state()
                _shake_app()
                time.sleep(1.0)  # longer settle on retry — the drawer
                # state we're recovering from is already wedged

            # The on-device-backup popup can appear mid-test (first Messages
            # entry) and blocks the drawer entirely — clear it every attempt.
            if dismiss_backup_modal(self, timeout=1):
                self.logger.warning(
                    "click_%s_button: dismissed backup modal on attempt %d",
                    slug, attempt,
                )
            self._ensure_main_nav_visible()
            # Drawer slide-in keeps animating for ~200-400ms after the
            # locator is in the AT tree; mid-animation taps land on stale
            # bounds and trigger CloseOnPressOutside instead of onClicked.
            time.sleep(0.6)
            strategy = strategies[attempt - 1]
            if not self._click_nav_item(nav_locator, strategy=strategy):
                self.logger.warning(
                    "click_%s_button: nav-item click did not register on "
                    "attempt %d (strategy=%s)", slug, attempt, strategy,
                )
                self.dump_page_source(f"{slug}_nav_no_click_a{attempt}_{strategy}")
                self.take_screenshot(f"{slug}_nav_no_click_a{attempt}_{strategy}")
                continue
            # Brief settle before the 15s landmark check — Qt layout
            # sometimes lags a frame behind the SwipeView transition.
            time.sleep(0.5)
            if self.is_element_visible(landmark_locator, timeout=15):
                if attempt > 1:
                    self.logger.warning(
                        "click_%s_button: rescued on attempt %d (strategy=%s)"
                        " — primary nav path failed",
                        slug, attempt, strategy,
                    )
                return True
            self.logger.warning(
                "click_%s_button: drawer closed but %s page not "
                "visible on attempt %d (strategy=%s)",
                slug, nav_name, attempt, strategy,
            )
            self.dump_page_source(f"{slug}_drawer_closed_no_page_a{attempt}_{strategy}")
            self.take_screenshot(f"{slug}_drawer_closed_no_page_a{attempt}_{strategy}")
        return False

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
        endtime = time.time() + duration
        while time.time() < endtime:
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
