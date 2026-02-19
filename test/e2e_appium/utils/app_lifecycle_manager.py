"""
App lifecycle management utilities.

Handles app restart, termination, and data clearing operations.
Extracted from BasePage to follow Single Responsibility Principle.
"""

import os
import subprocess
import time
from typing import Optional, Tuple

from config.logging_config import get_logger
from utils.platform import is_ios as _is_ios_driver


class AppLifecycleManager:
    STATE_LABELS = {
        0: "UNKNOWN",
        1: "NOT_RUNNING",
        2: "RUNNING_IN_BACKGROUND_SUSPENDED",
        3: "RUNNING_IN_BACKGROUND",
        4: "RUNNING_IN_FOREGROUND",
    }

    def __init__(self, driver):
        self.driver = driver
        self.logger = get_logger("app_lifecycle")
        self._is_ios = _is_ios_driver(driver)
        self._default_package, self._default_activity = self._resolve_app_identifiers()

    @property
    def default_package(self) -> Optional[str]:
        return self._default_package

    @property
    def default_activity(self) -> Optional[str]:
        return self._default_activity

    def restart_app(self, app_package: Optional[str] = None) -> bool:
        """
        Restart the app within the current session.

        Useful for testing session persistence, returning user scenarios,
        or app state recovery after restart.

        Args:
            app_package: App package name override. Falls back to detected capabilities.

        Returns:
            bool: True if restart was successful
        """
        package = self._resolve_package(app_package)
        if not package:
            return False

        self.logger.info("Restarting app: %s", package)
        if not self._restart_via_mobile_commands(package):
            self.logger.error("App restart failed")
            return False

        try:
            from services.app_initialization_manager import AppInitializationManager

            AppInitializationManager(self.driver).perform_initial_activation()
        except Exception as err:
            self.logger.error("UI activation failed after restart: %s", err)
            return False

        return True

    def restart_app_with_data_cleared(self, app_package: Optional[str] = None) -> bool:
        """
        Restart the app with all app data cleared (fresh app state).

        This completely removes app data and cache, then relaunches the app.
        Useful for testing fresh onboarding flows.

        Args:
            app_package: The app package identifier override.

        Returns:
            bool: True if restart successful, False otherwise
        """
        package = self._resolve_package(app_package)
        if not package:
            return False

        try:
            self.logger.info("Restarting app with data cleared...")

            # Cloud environments typically disallow ADB; skip and advise new session
            env_name = os.getenv("CURRENT_TEST_ENVIRONMENT", "browserstack").lower()
            if env_name in ("browserstack",):
                self.logger.warning(
                    "Cloud run detected; skipping ADB data clear. Use a new session with noReset=false/fullReset."
                )
                return False

            self.driver.terminate_app(package)
            self.logger.debug("App terminated")

            clear_data_result = subprocess.run(
                ["adb", "shell", "pm", "clear", package],
                capture_output=True,
                text=True,
            )

            if clear_data_result.returncode != 0:
                self.logger.warning(
                    "Clear app data failed: %s", clear_data_result.stderr
                )
            else:
                self.logger.debug("App data cleared")

            self._activate_app(package)

            # Optional activation tap
            try:
                from utils.gestures import Gestures

                gestures = Gestures(self.driver)
                gestures.tap(500, 300)
            except Exception:
                pass

            self.logger.info("App restart with data cleared completed successfully")
            return True

        except Exception as e:
            self.logger.error("App restart with data cleared failed: %s", e)
            return False

    def terminate_app(self, app_package: Optional[str] = None) -> bool:
        """Terminate the specified app."""
        package = self._resolve_package(app_package)
        if not package:
            return False

        try:
            self.driver.terminate_app(package)
            self.logger.debug("App terminated: %s", package)
            return True
        except Exception as e:
            self.logger.error("Failed to terminate app: %s", e)
            return False

    def activate_app(
        self, app_package: Optional[str] = None, app_activity: Optional[str] = None
    ) -> bool:
        """Activate the specified app."""
        package = self._resolve_package(app_package)
        if not package:
            return False

        activity = app_activity or self._default_activity
        try:
            self._activate_app(package)
            return True
        except Exception as e:
            # start_activity is Android-only; skip on iOS
            if self._is_ios:
                self.logger.error("activate_app failed on iOS for %s: %s", package, e)
                return False
            self.logger.debug(
                "activate_app failed for %s: %s; attempting start_activity", package, e
            )
            if activity:
                try:
                    self.driver.start_activity(package, activity)
                    self.logger.debug("App started via start_activity")
                    return True
                except Exception as start_err:
                    self.logger.error(
                        "Failed to start activity %s for %s: %s",
                        activity,
                        package,
                        start_err,
                    )
                    return False
            self.logger.error("Failed to activate app: %s", e)
            return False

    def activate_app_with_ui_ready(
        self,
        app_package: Optional[str] = None,
        activation_timeout: float = 15.0,
    ) -> bool:
        """
        Activate app and perform initial activation to expose UI components.

        Use after any restart where WelcomeScreen or WelcomeBackScreen is expected.
        Combines activate_app() with the activation tap sequence.
        """
        if not self.activate_app(app_package):
            return False

        try:
            from services.app_initialization_manager import AppInitializationManager

            AppInitializationManager(self.driver).perform_initial_activation(
                timeout=activation_timeout
            )
            return True
        except Exception as err:
            self.logger.error("UI activation failed after app activation: %s", err)
            return False

    def _activate_app(self, package: str) -> None:
        self.driver.activate_app(package)
        self.logger.debug("App activated: %s", package)

    def wait_for_app_not_running(
        self,
        app_package: Optional[str] = None,
        timeout: int = 30,
        poll_interval: float = 0.5,
    ) -> bool:
        """
        Poll the driver until the AUT reports NOT_RUNNING via queryAppState.
        """
        package = self._resolve_package(app_package)
        if not package:
            return False

        deadline = time.time() + timeout
        last_state = None

        while time.time() < deadline:
            state = self._query_app_state(package)
            if state is None:
                time.sleep(poll_interval)
                continue

            last_state = state
            if state == 1:
                self.logger.debug("Confirmed %s is NOT_RUNNING before relaunch", package)
                return True

            time.sleep(poll_interval)

        self.logger.warning(
            "Timed out waiting for %s to stop. Last observed state: %s",
            package,
            self.STATE_LABELS.get(last_state, last_state),
        )
        return False

    def _restart_via_mobile_commands(self, app_package: str) -> bool:
        """Restart the app using Appium mobile: terminateApp / activateApp.

        On Android, falls back to ``start_activity`` if ``activate_app``
        fails.  ``start_activity`` does not exist on iOS so the fallback
        is skipped there.
        """
        try:
            self.logger.debug("Attempting mobile restart for %s", app_package)
            try:
                self.driver.execute_script(
                    "mobile: terminateApp", {"appId": app_package}
                )
                self.logger.debug("App terminated via mobile: terminateApp")
            except Exception as terminate_err:
                self.logger.debug(
                    "mobile: terminateApp failed (non-fatal): %s", terminate_err
                )

            try:
                self.driver.activate_app(app_package)
                self.logger.info("App restart completed via activate_app")
                return True
            except Exception as activate_err:
                if self._is_ios:
                    self.logger.error(
                        "activate_app failed on iOS for %s: %s",
                        app_package,
                        activate_err,
                    )
                    return False
                self.logger.debug(
                    "activate_app failed for %s: %s; attempting start_activity",
                    app_package,
                    activate_err,
                )
                if self._default_activity:
                    self.driver.start_activity(app_package, self._default_activity)
                    self.logger.info("App restart completed via start_activity")
                    return True
                self.logger.error(
                    "No default activity available to restart %s", app_package
                )
                return False
        except Exception:
            self.logger.exception(
                "App restart failed for %s",
                app_package,
            )
            return False

    def _resolve_package(self, override: Optional[str]) -> Optional[str]:
        package = override or self._default_package
        if package:
            return package
        cap_hint = "bundleId" if self._is_ios else "appPackage"
        self.logger.error(
            "Unable to determine app identifier. Ensure %s capability is set.",
            cap_hint,
        )
        return None

    def _resolve_app_identifiers(self) -> Tuple[Optional[str], Optional[str]]:
        """Extract the application package/bundleId and activity from capabilities.

        On iOS the relevant identifier is ``bundleId`` (no activity concept).
        On Android the identifiers are ``appPackage`` and ``appActivity``.

        Returns:
            ``(package_or_bundle_id, activity_or_none)``
        """
        capability_sources = [
            getattr(self.driver, "capabilities", None),
            getattr(self.driver, "desired_capabilities", None),
        ]

        package = None
        activity = None

        for caps in capability_sources:
            if not caps:
                continue

            if self._is_ios:
                # iOS: read bundleId
                package = (
                    caps.get("appium:bundleId")
                    or caps.get("bundleId")
                    or caps.get("CFBundleIdentifier")
                    or package
                )
            else:
                # Android: read appPackage / appActivity
                package = (
                    caps.get("appium:appPackage")
                    or caps.get("appPackage")
                    or package
                )
                activity = (
                    caps.get("appium:appActivity")
                    or caps.get("appActivity")
                    or activity
                )

            if package and (self._is_ios or activity):
                break

        if package:
            id_type = "bundleId" if self._is_ios else "appPackage"
            self.logger.debug("Detected AUT %s from capabilities: %s", id_type, package)
        else:
            default = "app.status.mobile"
            self.logger.warning(
                "AUT identifier not found in capabilities; falling back to %s", default
            )
            package = default

        if activity:
            self.logger.debug("Detected AUT launch activity: %s", activity)

        return package, activity

    def _query_app_state(self, package: str) -> Optional[int]:
        try:
            if hasattr(self.driver, "query_app_state"):
                return self.driver.query_app_state(package)
            return self.driver.execute_script("mobile: queryAppState", {"appId": package})
        except Exception as err:
            self.logger.debug("query_app_state failed for %s: %s", package, err)
            return None
