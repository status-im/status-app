import time

from config.logging_config import get_logger
from core.models import TestAppState


class AppStateManager:

    def __init__(self, driver):
        self.driver = driver
        self.logger = get_logger("app_state_manager")
        self.state = TestAppState()

    def detect_current_state(self) -> TestAppState:
        self.logger.debug("🔍 Detecting app state...")

        if self._is_welcome_screen_displayed():
            self._set_welcome_state()
        elif self._is_welcome_back_displayed():
            self._set_welcome_back_state()
        elif self._is_app_section_loaded():
            self._set_app_section_state()
        elif self._is_home_loaded():
            self._set_home_state()
        else:
            self._set_unknown_state()

        return self.state

    def wait_for_app_ready(self, timeout: int = 30, poll_interval: float = 0.5) -> bool:
        deadline = time.time() + timeout
        last_screen = None
        last_requires_auth = None
        last_home_loaded = None
        while time.time() < deadline:
            try:
                self.detect_current_state()
                screen = self.state.current_screen
                requires_auth = self.state.requires_authentication
                home_loaded = self.state.is_home_loaded

                if (
                    screen != last_screen
                    or requires_auth != last_requires_auth
                    or home_loaded != last_home_loaded
                ):
                    self.logger.debug(
                        "wait_for_app_ready poll: screen=%s requires_auth=%s home_loaded=%s",
                        screen,
                        requires_auth,
                        home_loaded,
                    )
                    last_screen = screen
                    last_requires_auth = requires_auth
                    last_home_loaded = home_loaded

                if home_loaded or requires_auth:
                    return True
            except Exception as err:
                self.logger.debug("wait_for_app_ready poll raised: %s", err)
            time.sleep(poll_interval)
        self.logger.warning(
            "wait_for_app_ready timeout after %.1fs; last state screen=%s requires_auth=%s home_loaded=%s",
            timeout,
            last_screen,
            last_requires_auth,
            last_home_loaded,
        )
        return False

    def _is_welcome_screen_displayed(self) -> bool:
        try:
            from pages.onboarding import WelcomePage

            welcome = WelcomePage(self.driver)
            return welcome.is_screen_displayed(timeout=3)
        except Exception:
            return False

    def _is_welcome_back_displayed(self) -> bool:
        try:
            from pages.onboarding import WelcomeBackPage

            welcome_back = WelcomeBackPage(self.driver)
            return welcome_back.is_welcome_back_screen_displayed(timeout=5)
        except Exception:
            return False

    def _is_app_section_loaded(self) -> bool:
        try:
            from pages.app import App

            app = App(self.driver)
            section = app.active_section()
            return section in (
                "home",
                "messaging",
                "wallet",
                "communities",
                "market",
                "settings",
            )
        except Exception:
            return False

    def _is_home_loaded(self) -> bool:
        try:
            from pages.onboarding import HomePage

            main_app = HomePage(self.driver)
            return main_app.is_home_loaded()
        except Exception:
            return False

    def _set_welcome_state(self):
        self.state.is_home_loaded = False
        self.state.current_screen = "welcome"
        self.state.requires_authentication = False
        self.state.has_existing_profiles = False
        self.logger.debug("✓ Welcome screen detected")

    def _set_welcome_back_state(self):
        self.state.has_existing_profiles = True
        self.state.current_screen = "welcome_back"
        self.state.requires_authentication = True
        self.logger.debug("✓ Welcome back screen detected")

    def _set_app_section_state(self):
        try:
            from pages.app import App

            app = App(self.driver)
            section = app.active_section()
            if section == "home":
                self.state.is_home_loaded = True
                self.state.current_screen = "home"
                self.state.requires_authentication = False
                self.logger.debug("✓ Home detected (container)")
            else:
                self.state.is_home_loaded = False
                self.state.current_screen = section
                self.state.requires_authentication = False
                self.logger.debug(f"✓ Section detected: {section}")
        except Exception:
            self._set_unknown_state()

    def _set_home_state(self):
        self.state.is_home_loaded = True
        self.state.current_screen = "home"
        self.state.requires_authentication = False
        self.logger.debug("✓ Home detected (fallback)")

    def _set_unknown_state(self):
        self.state.current_screen = "unknown"
        self.logger.debug("? Unknown app state detected")
