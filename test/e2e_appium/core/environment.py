import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional


class ConfigurationError(Exception):
    """Raised when environment configuration is invalid."""


@dataclass(frozen=True)
class ProviderConfig:
    name: str
    options: Dict[str, Any] = field(default_factory=dict)


@dataclass
class DeviceConfig:
    id: str
    display_name: Optional[str] = None
    capabilities: Dict[str, Any] = field(default_factory=dict)
    tags: List[str] = field(default_factory=list)
    provider_overrides: Dict[str, Any] = field(default_factory=dict)

    def merged_capabilities(
        self, defaults: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        merged: Dict[str, Any] = {}
        if defaults:
            merged.update(defaults)
        merged.update(self.capabilities)
        return merged


@dataclass
class EnvironmentConfig:
    name: str
    description: str
    provider: ProviderConfig
    execution: Dict[str, Any]
    timeouts: Dict[str, Any]
    logging: Dict[str, Any]
    directories: Dict[str, Any]
    device_defaults: Dict[str, Any]
    devices: Dict[str, DeviceConfig]
    default_device_id: Optional[str] = None
    config_root: Path = Path(".")

    def validate(self) -> None:
        if self.default_device_id and self.default_device_id not in self.devices:
            raise ConfigurationError(
                f"Default device '{self.default_device_id}' not declared in device matrix"
            )

        if not self.devices:
            raise ConfigurationError("No devices configured for environment")

        for device in self.devices.values():
            caps = device.merged_capabilities(self.device_defaults.get("capabilities"))
            if "platformName" not in caps:
                raise ConfigurationError(
                    f"Device '{device.id}' missing required capability 'platformName'"
                )
            if "deviceName" not in caps:
                raise ConfigurationError(
                    f"Device '{device.id}' missing required capability 'deviceName'"
                )

        provider_name = self.provider.name.lower()
        if provider_name == "local":
            self._validate_local()
        elif provider_name == "browserstack":
            self._validate_browserstack()

    def _validate_local(self) -> None:
        server_url = self.provider.options.get("server_url", "http://localhost:4723")

        try:
            import requests

            response = requests.get(f"{server_url.rstrip('/')}/status", timeout=5)
            if response.status_code != 200:
                raise ConfigurationError("Appium server not responding correctly")
        except ImportError:
            # If requests is unavailable, skip connectivity validation
            return
        except requests.RequestException as exc:  # type: ignore[attr-defined]
            raise ConfigurationError(
                f"Cannot connect to Appium server at {server_url}: {exc}"
            ) from exc

    def _validate_browserstack(self) -> None:
        auth_cfg = self.provider.options.get("auth", {})
        username = self.resolve_template(auth_cfg.get("username", ""))
        access_key = self.resolve_template(auth_cfg.get("access_key", ""))

        if not username or not access_key:
            raise ConfigurationError(
                "BrowserStack credentials missing. Set BROWSERSTACK_USERNAME and "
                "BROWSERSTACK_ACCESS_KEY or provide overrides in config."
            )

        app_cfg = self.provider.options.get("app", {})
        app_id = self.resolve_template(app_cfg.get("app_id_template", ""))
        if not app_id:
            raise ConfigurationError(
                "BrowserStack app id missing. Provide BROWSERSTACK_APP_ID or set"
                " provider.options.app.app_id_template."
            )

    def resolve_template(self, template: Optional[str]) -> str:
        if not template:
            return ""

        def replace_var(match: re.Match) -> str:
            var_name = match.group(1)
            default_part = (
                match.group(2) if len(match.groups()) > 1 and match.group(2) else ""
            )

            if default_part.startswith("${") and default_part.endswith("}"):
                default = self.resolve_template(default_part)
            else:
                default = default_part

            return os.getenv(var_name, default)

        pattern = r"\$\{([^}:-]+)(?::-([^${}]*(?:\$\{[^}]*\}[^${}]*)*))?\}"
        result = template
        while "${" in result:
            new_result = re.sub(pattern, replace_var, result)
            if new_result == result:
                break
            result = new_result
        return result

    def resolve_path(self, template: Optional[str]) -> str:
        resolved = self.resolve_template(template)
        if not resolved:
            return ""

        path = Path(resolved)
        if not path.is_absolute():
            path = (self.config_root / path).resolve()
        return str(path)

    def get_device(self, device_id: Optional[str] = None) -> DeviceConfig:
        if device_id:
            try:
                return self.devices[device_id]
            except KeyError as exc:
                raise ConfigurationError(
                    f"Device '{device_id}' not found in environment '{self.name}'"
                ) from exc

        if self.default_device_id:
            return self.devices[self.default_device_id]

        # fallback to first declared
        return next(iter(self.devices.values()))

    def find_devices_by_tags(self, tags: List[str]) -> List[DeviceConfig]:
        if not tags:
            return list(self.devices.values())

        tag_set = {tag.lower() for tag in tags}
        matched = []
        for device in self.devices.values():
            device_tags = {tag.lower() for tag in device.tags}
            if tag_set.issubset(device_tags):
                matched.append(device)
        return matched

    @property
    def available_devices(self) -> List[Dict[str, Any]]:
        devices: List[Dict[str, Any]] = []
        defaults = self.device_defaults.get("capabilities", {})
        for device in self.devices.values():
            devices.append(
                {
                    "id": device.id,
                    "display_name": device.display_name or device.id,
                    "tags": list(device.tags),
                    "capabilities": device.merged_capabilities(defaults),
                }
            )
        return devices

    def concurrency_limits(self) -> Dict[str, int]:
        concurrency = self.execution.get("concurrency", {})
        return {
            "max_sessions": concurrency.get("max_sessions", 1),
            "per_device_limit": concurrency.get("per_device_limit", 1),
        }

    def get_provider_option(self, key: str, default: Any = None) -> Any:
        return self.provider.options.get(key, default)

    def get_reports_directory(self) -> str:
        return self.directories.get("reports", "reports")

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "provider": self.provider.name,
            "execution": self.execution,
            "timeouts": self.timeouts,
            "logging": self.logging,
            "directories": self.directories,
            "devices": self.available_devices,
        }
