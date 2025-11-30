from typing import Any, Dict, List, Optional

from appium.webdriver.webdriver import WebDriver

from config import get_logger, log_session_info
from core import EnvironmentSwitcher, ConfigurationError

from .environment import DeviceConfig
from .providers import SessionMetadata, create_provider


class SessionManager:
    """Manages Appium sessions across different providers and device types."""

    def __init__(
        self,
        environment: str = "browserstack",
        device_override: Optional[Dict[str, Any]] = None,
        device_id: Optional[str] = None,
        device_tags: Optional[List[str]] = None,
    ):
        self.environment = environment
        self.logger = get_logger("session")
        self.driver: Optional[WebDriver] = None
        self._session_id: Optional[str] = None
        self._device_override = device_override or None
        self._explicit_device_id = device_id
        self._device_tags = device_tags or []
        self.metadata = SessionMetadata()

        switcher = EnvironmentSwitcher()
        self.env_config = switcher.switch_to(environment)
        self.provider = create_provider(self.env_config)
        self.device_config = self._select_device()

        merged_caps = self._get_merged_capabilities(self.device_config)
        self.logger.info(
            "OK Configuration loaded",
            extra={
                "environment": environment,
                "device": merged_caps.get("deviceName"),
                "platform": merged_caps.get("platformName"),
                "platform_version": merged_caps.get("platformVersion"),
            },
        )

    def _select_device(self) -> DeviceConfig:
        device: DeviceConfig
        if self._explicit_device_id:
            device = self.env_config.get_device(self._explicit_device_id)
        elif self._device_tags:
            matches = self.env_config.find_devices_by_tags(self._device_tags)
            if not matches:
                raise ConfigurationError(
                    f"No devices matched tags {self._device_tags} for environment {self.environment}"
                )
            device = matches[0]
        else:
            device = self.env_config.get_device()

        if self._device_override:
            device = self._apply_device_override(device, self._device_override)
        return device

    def _apply_device_override(
        self, base_device: DeviceConfig, override: Dict[str, Any]
    ) -> DeviceConfig:
        base_caps = self._get_merged_capabilities(base_device)
        new_caps = dict(base_caps)
        capability_mapping = {
            "name": "deviceName",
            "deviceName": "deviceName",
            "platform_name": "platformName",
            "platformName": "platformName",
            "platform_version": "platformVersion",
            "platformVersion": "platformVersion",
        }
        for key, target in capability_mapping.items():
            if key in override:
                new_caps[target] = override[key]

        if "capabilities" in override and isinstance(override["capabilities"], dict):
            new_caps.update(override["capabilities"])

        tags = list({*base_device.tags, *override.get("tags", [])})

        provider_overrides = dict(base_device.provider_overrides)
        if "server_url" in override:
            provider_overrides["server_url"] = override["server_url"]

        return DeviceConfig(
            id=f"{base_device.id}-override",
            display_name=override.get("display_name", base_device.display_name),
            capabilities=new_caps,
            tags=tags,
            provider_overrides=provider_overrides,
        )

    def _get_merged_capabilities(self, device: DeviceConfig) -> Dict[str, Any]:
        return device.merged_capabilities(
            self.env_config.device_defaults.get("capabilities", {})
        )

    def get_driver(self, metadata: Optional[SessionMetadata] = None) -> WebDriver:
        if self.driver:
            return self.driver

        if metadata:
            self.metadata = metadata

        try:
            self.driver = self.provider.create_driver(self.device_config, self.metadata)
            self._session_id = getattr(self.driver, "session_id", None)
            log_session_info(self._session_id or "unknown", "created", environment=self.environment)
            return self.driver
        except Exception as exc:
            self.logger.error("Failed to create driver: %s", exc)
            raise

    def report_result(self, status: str, reason: Optional[str] = None) -> None:
        """
        Report test result to BrowserStack.

        Prefers the WebDriver executor when the driver is still active, but
        falls back to the BrowserStack REST API (when credentials allow) after
        cleanup so sessions can always be marked finished.

        Args:
            status: Test status ('passed' or 'failed')
            reason: Optional reason message
        """
        driver_reported = False

        if self.driver:
            try:
                self.provider.report_session_status(self.driver, status, reason)
                driver_reported = True
            except Exception as exc:  # pragma: no cover - defensive
                self.logger.debug(
                    "Failed to report session status via driver: %s",
                    exc,
                )

        if driver_reported:
            return

        if self._session_id:
            try:
                self.provider.report_session_status_via_api(
                    self._session_id,
                    status,
                    reason,
                )
                return
            except Exception as exc:  # pragma: no cover - defensive
                truncated_id = (
                    self._session_id[:8]
                    if len(self._session_id) > 8
                    else self._session_id
                )
                self.logger.debug(
                    "Failed to report session status via REST API for session %s: %s",
                    truncated_id,
                    exc,
                )
        else:
            self.logger.debug("Cannot report result: no driver and no session_id")

    def cleanup_driver(self) -> None:
        if self.driver:
            session_id = getattr(self.driver, "session_id", "unknown")
            log_session_info(session_id, "cleanup", environment=self.environment)
            try:
                self.provider.cleanup_driver(self.driver)
            finally:
                self.driver = None

    @property
    def session_id(self) -> Optional[str]:
        """Get the session ID if available."""
        return self._session_id

    @property
    def concurrency_limit(self) -> Dict[str, int]:
        return self.env_config.concurrency_limits()

    @property
    def capabilities(self) -> Dict[str, Any]:
        return self._get_merged_capabilities(self.device_config)
