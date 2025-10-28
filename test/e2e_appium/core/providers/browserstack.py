from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Dict, Optional

from appium import webdriver
from appium.options.common import AppiumOptions
from appium.webdriver.appium_connection import AppiumConnection
from selenium.webdriver.remote.client_config import ClientConfig

from .base import Provider, SessionMetadata
from ..environment import ConfigurationError, DeviceConfig


class BrowserStackProvider(Provider):
    """Provider implementation using BrowserStack App Automate."""

    HUB_URL = "https://hub-cloud.browserstack.com/wd/hub"

    def __init__(self, env_config):
        super().__init__(env_config)
        auth_cfg = env_config.get_provider_option("auth", {})
        self.username = env_config.resolve_template(auth_cfg.get("username", ""))
        self.access_key = env_config.resolve_template(auth_cfg.get("access_key", ""))
        if not self.username or not self.access_key:
            raise ConfigurationError(
                "BrowserStack credentials are required. Set BROWSERSTACK_USERNAME "
                "and BROWSERSTACK_ACCESS_KEY."
            )
        self.hub_url = env_config.get_provider_option("hub_url", self.HUB_URL)
        project_name_option = env_config.get_provider_option(
            "project_name", "Status E2E Appium"
        )
        if isinstance(project_name_option, str):
            self.project_name = env_config.resolve_template(project_name_option)
        else:
            self.project_name = project_name_option
        self.sdk_options = env_config.get_provider_option("sdk", {})

    def create_driver(
        self,
        device: DeviceConfig,
        metadata: Optional[SessionMetadata] = None,
    ) -> webdriver.Remote:
        metadata = metadata or SessionMetadata()
        capabilities = self.build_capabilities(device, metadata)

        app_cfg = self.env_config.get_provider_option("app", {})
        app_id = self.env_config.resolve_template(app_cfg.get("app_id_template", ""))
        if app_id:
            capabilities["app"] = app_id

        bstack_options = capabilities.setdefault("bstack:options", {})
        self._populate_metadata(bstack_options, metadata, device)

        options = AppiumOptions()
        options.load_capabilities(capabilities)

        client_config = ClientConfig(
            remote_server_addr=self.hub_url,
            username=self.username,
            password=self.access_key,
        )

        driver = webdriver.Remote(
            command_executor=AppiumConnection(client_config=client_config),
            options=options,
        )

        session_name = bstack_options.get("sessionName")
        if session_name:
            self._send_executor_command(
                driver,
                {
                    "action": "setSessionName",
                    "arguments": {"name": session_name},
                },
            )

        return driver

    def report_session_status(
        self,
        driver: webdriver.Remote,
        status: str,
        reason: Optional[str] = None,
    ) -> None:
        arguments: Dict[str, str] = {"status": status}
        if reason:
            arguments["reason"] = reason
        self._send_executor_command(
            driver,
            {"action": "setSessionStatus", "arguments": arguments},
        )

    def _populate_metadata(
        self,
        bstack_options: Dict[str, str],
        metadata: SessionMetadata,
        device: DeviceConfig,
    ) -> None:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        overrides = {"TIMESTAMP": timestamp}
        if metadata.test_name:
            overrides["TEST_NAME"] = metadata.test_name
        if metadata.build_name:
            overrides["BUILD_NAME"] = metadata.build_name

        build_template = self.env_config.get_provider_option(
            "build_name_template", "Status E2E - ${TIMESTAMP}"
        )
        session_template = self.env_config.get_provider_option(
            "session_name_template", "${TEST_NAME:-Status Test}"
        )
        identifier_template = self.env_config.get_provider_option(
            "build_identifier_template", "${BUILD_IDENTIFIER:-${TIMESTAMP}}"
        )

        build_name = self._resolve_with_overrides(build_template, overrides)
        overrides.setdefault("BUILD_IDENTIFIER", timestamp)
        build_identifier = self._resolve_with_overrides(identifier_template, overrides)
        session_name = self._resolve_with_overrides(session_template, overrides)

        bstack_options.setdefault(
            "projectName", metadata.project_name or self.project_name
        )
        bstack_options.setdefault("buildName", build_name)
        if build_identifier:
            bstack_options.setdefault("buildIdentifier", build_identifier)
        bstack_options.setdefault("sessionName", session_name)
        if metadata.tags:
            bstack_options.setdefault("appium:options", {})
            if isinstance(bstack_options["appium:options"], dict):
                bstack_options["appium:options"].setdefault("tags", metadata.tags)

        per_session_options = self.sdk_options.get("reporting", {})
        for key, value in per_session_options.items():
            bstack_options.setdefault(key, value)

        # Ensure device context is always present in options for reporting
        defaults = self.env_config.device_defaults.get("capabilities", {})
        merged_caps = device.merged_capabilities(defaults)
        bstack_options.setdefault("osVersion", merged_caps.get("platformVersion"))
        bstack_options.setdefault("deviceName", merged_caps.get("deviceName"))

    def _resolve_with_overrides(self, template: str, overrides: Dict[str, str]) -> str:
        original: Dict[str, Optional[str]] = {}
        try:
            for key, value in overrides.items():
                if key in os.environ:
                    original[key] = os.environ[key]
                os.environ[key] = value
            return self.env_config.resolve_template(template)
        finally:
            for key in overrides:
                if key in original:
                    os.environ[key] = original[key] or ""
                else:
                    os.environ.pop(key, None)
