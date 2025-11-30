from __future__ import annotations

import json
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from appium.webdriver.webdriver import WebDriver

from ..environment import DeviceConfig, EnvironmentConfig


@dataclass
class SessionMetadata:
    test_name: Optional[str] = None
    build_name: Optional[str] = None
    project_name: Optional[str] = None
    tags: List[str] = field(default_factory=list)


class Provider(ABC):
    def __init__(self, env_config: EnvironmentConfig) -> None:
        self.env_config = env_config

    @property
    def name(self) -> str:
        return self.env_config.provider.name

    def build_capabilities(
        self, device: DeviceConfig, metadata: Optional[SessionMetadata] = None
    ) -> Dict[str, Any]:
        defaults = self.env_config.device_defaults.get("capabilities", {})
        capabilities = device.merged_capabilities(defaults)

        provider_overrides = device.provider_overrides.get(self.name, {})
        capabilities = self._deep_merge(capabilities, provider_overrides)
        return self._resolve_templates(capabilities)

    @abstractmethod
    def create_driver(
        self,
        device: DeviceConfig,
        metadata: Optional[SessionMetadata] = None,
    ) -> WebDriver: ...

    def report_session_status(
        self,
        driver: WebDriver,
        status: str,
        reason: Optional[str] = None,
    ) -> None:
        """Default implementation does nothing."""
        return None

    def report_session_status_via_api(
        self,
        session_id: Optional[str],
        status: str,
        reason: Optional[str] = None,
    ) -> None:
        """Default REST API reporting implementation does nothing."""
        return None

    def cleanup_driver(self, driver: Optional[WebDriver]) -> None:
        if driver:
            driver.quit()

    def _deep_merge(self, base: Dict[str, Any], override: Any) -> Dict[str, Any]:
        if not override:
            return dict(base)

        result = dict(base)
        if isinstance(override, dict):
            for key, value in override.items():
                if (
                    key in result
                    and isinstance(result[key], dict)
                    and isinstance(value, dict)
                ):
                    result[key] = self._deep_merge(result[key], value)
                else:
                    result[key] = value
        else:
            raise TypeError(
                "Provider overrides must be dictionaries compatible with capabilities"
            )
        return result

    def _send_executor_command(
        self, driver: Optional[WebDriver], command: Dict[str, Any]
    ) -> None:
        if not driver:
            return
        try:
            driver.execute_script(f"browserstack_executor: {json.dumps(command)}")
        except Exception:
            # Intentionally swallow errors to avoid masking test failures
            return

    def _resolve_templates(self, value: Any) -> Any:
        if isinstance(value, dict):
            return {key: self._resolve_templates(val) for key, val in value.items()}
        if isinstance(value, list):
            return [self._resolve_templates(item) for item in value]
        if isinstance(value, str):
            return self.env_config.resolve_template(value)
        return value
