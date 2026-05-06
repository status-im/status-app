from __future__ import annotations

import logging
import subprocess
from typing import Optional

from appium import webdriver
from appium.options.common import AppiumOptions

from .base import Provider, SessionMetadata
from ..environment import ConfigurationError, DeviceConfig

logger = logging.getLogger(__name__)

# PR builds use "app.status.mobile.pr", release/nightly use "app.status.mobile".
# Order matters: check the more specific suffix first.
_STATUS_PACKAGES = ("app.status.mobile.pr", "app.status.mobile")


def _detect_installed_package(udid: Optional[str] = None) -> Optional[str]:
    """Query ADB for the first installed Status package on the device."""
    for pkg in _STATUS_PACKAGES:
        if _is_package_installed(udid, pkg):
            return pkg
    return None


def _is_package_installed(udid: Optional[str], package: str) -> bool:
    """Return True if the given package is installed on the device."""
    cmd = ["adb"]
    if udid:
        cmd += ["-s", udid]
    cmd += ["shell", "pm", "list", "packages", package]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        return f"package:{package}" in out.stdout
    except Exception:
        return False


class LocalProvider(Provider):
    """Provider implementation targeting a locally hosted Appium server."""

    def create_driver(
        self,
        device: DeviceConfig,
        metadata: Optional[SessionMetadata] = None,
    ) -> webdriver.Remote:
        capabilities = self.build_capabilities(device, metadata)

        app_cfg = self.env_config.get_provider_option("app", {})
        path_template = app_cfg.get("path_template")
        resolved_app_path = ""
        if path_template:
            resolved_app_path = self.env_config.resolve_path(path_template)
            if resolved_app_path:
                capabilities.setdefault("app", resolved_app_path)

        if not capabilities.get("app") and not capabilities.get("noReset", False):
            raise ConfigurationError(
                "Local provider requires either an app path (set LOCAL_APP_PATH or "
                "update path_template) or noReset=true for preinstalled apps."
            )

        self._align_package_to_device(capabilities)

        options = AppiumOptions()
        options.load_capabilities(capabilities)

        server_url = device.provider_overrides.get(
            "server_url",
            self.env_config.get_provider_option("server_url", "http://localhost:4723"),
        )
        return webdriver.Remote(server_url, options=options)

    @staticmethod
    def _align_package_to_device(capabilities: dict) -> None:
        """Pick the right Status package when both PR (``app.status.mobile.pr``)
        and release (``app.status.mobile``) builds are installed.

        Honour the configured ``appPackage`` if installed, else fall back to
        the first detected one. A mismatch silently breaks ``noReset: false``.
        """
        udid = capabilities.get("appium:udid") or capabilities.get("udid")
        configured = capabilities.get("appPackage")
        detected = _detect_installed_package(udid)

        if configured and _is_package_installed(udid, configured):
            if detected and detected != configured:
                logger.debug(
                    "Multiple Status packages installed (configured=%s, also-detected=%s); "
                    "honouring configured value",
                    configured, detected,
                )
            capabilities["appPackage"] = configured
            return

        if not detected:
            return

        if configured and configured != detected:
            logger.info(
                "appPackage configured=%s not installed on device; using detected=%s",
                configured, detected,
            )
        capabilities["appPackage"] = detected
