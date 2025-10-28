import os
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
from uuid import uuid4

from core.config_manager import ConfigurationManager, EnvironmentSwitcher
from core.environment import DeviceConfig, EnvironmentConfig


@dataclass
class TestConfig:
    environment: EnvironmentConfig
    device: DeviceConfig
    capabilities: Dict[str, Any]
    app_reference: str
    provider_name: str
    reports_dir: str
    logs_dir: str
    screenshots_dir: str
    enable_xml_report: bool
    enable_html_report: bool
    enable_junit_report: bool
    logging_level: str
    concurrency: Dict[str, int]
    pytest_addopts: List[str]
    run_id: str
    provider_options: Dict[str, Any] = field(default_factory=dict)

    @property
    def environment_name(self) -> str:
        return self.environment.name

    @property
    def device_name(self) -> str:
        return self.capabilities.get("deviceName", self.device.display_name or "")

    @property
    def platform_name(self) -> str:
        return self.capabilities.get("platformName", "")

    @property
    def platform_version(self) -> str:
        return self.capabilities.get("platformVersion", "")


_CONFIG_CACHE: Optional[TestConfig] = None


def _ensure_run_id() -> str:
    run_id = os.getenv("E2E_RUN_ID")
    if run_id:
        return run_id
    generated = f"local-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}-{uuid4().hex[:6]}"
    os.environ["E2E_RUN_ID"] = generated
    return generated


def _select_device(env_config: EnvironmentConfig) -> DeviceConfig:
    device_id = os.getenv("TEST_DEVICE_ID")
    tag_env = os.getenv("TEST_DEVICE_TAGS", "")
    tags = [tag.strip() for tag in tag_env.split(",") if tag.strip()]

    if device_id:
        return env_config.get_device(device_id)

    if tags:
        matches = env_config.find_devices_by_tags(tags)
        if matches:
            return matches[0]

    return env_config.get_device()


def _resolve_app_reference(env_config: EnvironmentConfig) -> str:
    app_cfg = env_config.get_provider_option("app", {})
    if app_cfg.get("path_template"):
        return env_config.resolve_template(app_cfg.get("path_template"))
    if app_cfg.get("app_id_template"):
        return env_config.resolve_template(app_cfg.get("app_id_template"))
    return ""


def _ensure_directories(*paths: str) -> None:
    for path in paths:
        if path:
            Path(path).mkdir(parents=True, exist_ok=True)


def load_config() -> TestConfig:
    run_id = _ensure_run_id()
    env_name = os.getenv("TEST_ENVIRONMENT")
    manager = ConfigurationManager()
    if not env_name:
        auto = EnvironmentSwitcher().auto_detect_environment()
        env_name = os.getenv("E2E_PROVIDER", auto)
    env_config = manager.load_environment(env_name)

    device = _select_device(env_config)
    capabilities = device.merged_capabilities(
        env_config.device_defaults.get("capabilities", {})
    )

    reports_dir = env_config.resolve_template(
        env_config.directories.get("reports", "reports")
    )
    logs_dir = env_config.resolve_template(
        env_config.directories.get("logs", "logs")
    )
    screenshots_dir = env_config.resolve_template(
        env_config.directories.get("screenshots", "screenshots")
    )
    _ensure_directories(reports_dir, logs_dir, screenshots_dir)

    execution = env_config.execution or {}
    pytest_addopts = execution.get("pytest", {}).get("addopts", [])

    logging_config = env_config.logging or {}

    config = TestConfig(
        environment=env_config,
        device=device,
        capabilities=capabilities,
        app_reference=_resolve_app_reference(env_config),
        provider_name=env_config.provider.name,
        reports_dir=reports_dir,
        logs_dir=logs_dir,
        screenshots_dir=screenshots_dir,
        enable_xml_report=logging_config.get("enable_xml_report", True),
        enable_html_report=logging_config.get("enable_html_report", True),
        enable_junit_report=logging_config.get("enable_junit_report", True),
        logging_level=logging_config.get("level", "INFO"),
        concurrency=env_config.concurrency_limits(),
        pytest_addopts=pytest_addopts,
        run_id=run_id,
        provider_options=env_config.provider.options,
    )
    return config


def get_config(refresh: bool = False) -> TestConfig:
    global _CONFIG_CACHE
    if _CONFIG_CACHE is None or refresh:
        _CONFIG_CACHE = load_config()
    return _CONFIG_CACHE
