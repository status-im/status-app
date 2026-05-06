import json
import os
from pathlib import Path
from typing import Any, Dict, List

import yaml

from .environment import (
    ConfigurationError,
    DeviceConfig,
    EnvironmentConfig,
    ProviderConfig,
)


class ConfigurationManager:
    def __init__(self, config_dir: Path = None) -> None:
        self.config_dir = config_dir or Path(__file__).parent.parent / "config"
        self.environments_dir = self.config_dir / "environments"
        self.schemas_dir = self.config_dir / "schemas"

    def load_environment(self, environment: str) -> EnvironmentConfig:
        base_config = self._load_yaml(self.environments_dir / "base.yaml")

        env_file = self.environments_dir / f"{environment}.yaml"
        if not env_file.exists():
            raise ConfigurationError(f"Environment '{environment}' not found")

        env_config = self._load_yaml(env_file)
        merged_config = self._deep_merge(base_config, env_config)

        # Apply a gitignored local override if it exists (e.g.
        # local.local.yaml for machine-specific device config).
        local_override = self.environments_dir / f"{environment}.local.yaml"
        if local_override.exists():
            override_config = self._load_yaml(local_override)
            merged_config = self._deep_merge(merged_config, override_config)

        self._validate_schema(merged_config)
        config = self._create_config_object(merged_config)
        config.validate()
        return config

    def list_available_environments(self) -> List[str]:
        env_files = self.environments_dir.glob("*.yaml")
        return [f.stem for f in env_files if f.stem != "base"]

    def _load_yaml(self, file_path: Path) -> Dict[str, Any]:
        try:
            with open(file_path, "r", encoding="utf-8") as handle:
                return yaml.safe_load(handle) or {}
        except yaml.YAMLError as exc:
            raise ConfigurationError(f"Invalid YAML in {file_path}: {exc}") from exc
        except FileNotFoundError as exc:
            raise ConfigurationError(
                f"Configuration file not found: {file_path}"
            ) from exc

    def _deep_merge(
        self, base: Dict[str, Any], override: Dict[str, Any]
    ) -> Dict[str, Any]:
        result = dict(base)

        for key, value in override.items():
            if key == "extends":
                continue

            if (
                key in result
                and isinstance(result[key], dict)
                and isinstance(value, dict)
            ):
                result[key] = self._deep_merge(result[key], value)
            else:
                result[key] = value

        return result

    def _validate_schema(self, config: Dict[str, Any]) -> None:
        schema_file = self.schemas_dir / "environment.json"
        if not schema_file.exists():
            return

        try:
            import jsonschema

            with open(schema_file, "r", encoding="utf-8") as handle:
                schema = json.load(handle)
            jsonschema.validate(config, schema)
        except ImportError:
            return
        except (jsonschema.ValidationError, jsonschema.SchemaError) as exc:
            raise ConfigurationError(f"Configuration validation failed: {exc}") from exc

    def _create_config_object(self, config: Dict[str, Any]) -> EnvironmentConfig:
        metadata = config.get("metadata", {})
        provider_cfg = config.get("provider", {})
        execution = config.get("execution", {})
        device_defaults = config.get("device_defaults", {})
        devices_section = config.get("devices", {})
        device_matrix = devices_section.get("matrix", [])

        devices: Dict[str, DeviceConfig] = {}
        for entry in device_matrix:
            device_id = entry["id"]
            devices[device_id] = DeviceConfig(
                id=device_id,
                display_name=entry.get("display_name"),
                capabilities=entry.get("capabilities", {}),
                tags=entry.get("tags", []) or [],
                provider_overrides=entry.get("provider_overrides", {}),
            )

        env_config = EnvironmentConfig(
            name=metadata.get("name", "unknown"),
            description=metadata.get("description", ""),
            provider=ProviderConfig(
                name=provider_cfg.get("name", "local"),
                options=provider_cfg.get("options", {}),
            ),
            execution=execution,
            timeouts=config.get("timeouts", {}),
            logging=config.get("logging", {}),
            directories=config.get("directories", {}),
            device_defaults=device_defaults,
            devices=devices,
            default_device_id=devices_section.get("default"),
            config_root=self.config_dir.parent,
        )

        return env_config


class EnvironmentSwitcher:
    def __init__(self) -> None:
        self.config_manager = ConfigurationManager()

    def switch_to(self, environment: str) -> EnvironmentConfig:
        available = self.config_manager.list_available_environments()
        if environment not in available:
            raise ConfigurationError(
                f"Environment '{environment}' not found. "
                f"Available: {', '.join(available)}"
            )

        config = self.config_manager.load_environment(environment)
        os.environ["CURRENT_TEST_ENVIRONMENT"] = environment
        return config

    def auto_detect_environment(self) -> str:
        available = self.config_manager.list_available_environments()

        browserstack_creds_present = bool(
            os.getenv("BROWSERSTACK_USERNAME") and os.getenv("BROWSERSTACK_ACCESS_KEY")
        )
        if browserstack_creds_present and "browserstack" in available:
            return "browserstack"

        try:
            import requests

            requests.get("http://localhost:4723/status", timeout=2)
            if "local" in available:
                return "local"
        except Exception:
            pass

        if "local" in available:
            return "local"

        return available[0] if available else "local"
