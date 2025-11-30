from __future__ import annotations

from typing import Optional

from appium import webdriver
from appium.options.common import AppiumOptions

from .base import Provider, SessionMetadata
from ..environment import ConfigurationError, DeviceConfig


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
                "Local provider requires either an APK path (set LOCAL_APP_PATH or "
                "update path_template) or noReset=true for preinstalled apps."
            )

        options = AppiumOptions()
        options.load_capabilities(capabilities)

        server_url = device.provider_overrides.get(
            "server_url",
            self.env_config.get_provider_option("server_url", "http://localhost:4723"),
        )
        return webdriver.Remote(server_url, options=options)
