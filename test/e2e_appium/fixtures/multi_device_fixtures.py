"""Multi-device pytest fixtures."""

from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

import pytest_asyncio

from config.logging_config import get_logger
from core.config_manager import ConfigurationManager
from core.device_context import DeviceContext
from core.multi_device_context import MultiDeviceContext
from core.session_pool import PoolConfig, SessionPool
from core.stash_keys import MULTI_DEVICE_MANAGERS_KEY
from utils.generators import generate_account_name
from utils.exceptions import SessionManagementError


DEFAULT_DEVICE_COUNT = 1


def _resolve_count_marker(marker, *, default: int) -> int:
    if not marker:
        return default
    if marker.args:
        return int(marker.args[0])
    if "count" in marker.kwargs:
        return int(marker.kwargs["count"])
    if "value" in marker.kwargs:
        return int(marker.kwargs["value"])
    return default


def _resolve_minimum_marker(marker) -> Optional[int]:
    if not marker:
        return None
    if marker.args:
        return int(marker.args[0])
    if "count" in marker.kwargs:
        return int(marker.kwargs["count"])
    if "value" in marker.kwargs:
        return int(marker.kwargs["value"])
    return None


def _extract_marker_list(marker, key: str) -> Optional[List[Any]]:
    if not marker:
        return None
    if marker.args:
        return list(marker.args)
    value = marker.kwargs.get(key)
    if value is None:
        return None
    if isinstance(value, (list, tuple)):
        return list(value)
    return [value]


def _local_env_overrides(device_count: int) -> Optional[List[Dict[str, Any]]]:
    """Derive local device overrides from environment variables when provided."""
    udids_raw = os.getenv("LOCAL_DEVICE_UDIDS", "")
    udids = [value.strip() for value in udids_raw.split(",") if value.strip()]
    if len(udids) < device_count:
        return None

    urls_raw = os.getenv("LOCAL_APPIUM_URLS", "")
    urls = [value.strip() for value in urls_raw.split(",") if value.strip()]

    overrides: List[Dict[str, Any]] = []

    for index in range(device_count):
        override: Dict[str, Any] = {
            "capabilities": {
                "appium:udid": udids[index],
                "appium:systemPort": 8200 + index,
            }
        }
        if index < len(urls):
            override["server_url"] = urls[index]
        overrides.append(override)

    return overrides


def _parse_device_markers(request, test_environment) -> tuple:
    """
    Extract device configuration from pytest markers.

    Returns:
        Tuple of (device_count, device_overrides, device_tags)
    """
    count_marker = request.node.get_closest_marker("device_count")
    tags_marker = request.node.get_closest_marker("device_tags")
    overrides_marker = request.node.get_closest_marker("device_overrides")

    device_count = _resolve_count_marker(count_marker, default=DEFAULT_DEVICE_COUNT)
    device_tags = _extract_marker_list(tags_marker, "tags")
    device_overrides = _extract_marker_list(overrides_marker, "devices")

    if device_overrides:
        device_overrides = list(device_overrides)[:device_count]
    elif test_environment == "local":
        device_overrides = _local_env_overrides(device_count)

    if device_tags and not device_overrides:
        cfg_mgr = ConfigurationManager()
        env_cfg = cfg_mgr.load_environment(test_environment)
        available = env_cfg.available_devices or []
        tag_filter = set(device_tags)
        device_overrides = [
            device for device in available if tag_filter.issubset(set(device.get("tags", [])))
        ][:device_count]

    return device_count, device_overrides, device_tags


@pytest_asyncio.fixture(scope="function")
async def devices(request, test_environment):
    """
    Unified device fixture - provisions and optionally onboards devices.

    By default, devices are onboarded. Use @pytest.mark.raw_devices to skip onboarding.

    Markers:
        @pytest.mark.raw_devices: Skip onboarding (for testing onboarding flows)
        @pytest.mark.device_count(n): Number of devices (default: 1)
        @pytest.mark.minimum_required(n): Minimum successful onboards required
        @pytest.mark.device_tags(["tag1", "tag2"]): Filter devices by tags
        @pytest.mark.device_overrides([{...}]): Device configuration overrides
    """
    logger = get_logger("devices_fixture")

    skip_onboarding = request.node.get_closest_marker("raw_devices") is not None
    device_count, device_overrides, device_tags = _parse_device_markers(request, test_environment)

    logger.info(
        "Provisioning %d device(s) for environment %s (onboard=%s)",
        device_count,
        test_environment,
        not skip_onboarding,
    )

    # Setup phase - capture any errors but always store for cleanup
    pool = None
    multi_ctx = None
    device_names = []
    setup_error = None

    try:
        # Create session pool
        pool_config = PoolConfig.from_environment(
            test_environment,
            device_overrides=device_overrides,
            device_tags=device_tags if not device_overrides else None,
            parallel=True,
        )
        pool = SessionPool(config=pool_config)

        # Create sessions
        drivers = await pool.create_sessions(
            count=device_count,
            test_nodeid=request.node.nodeid,
        )

        # Create device contexts
        contexts = {
            name: DeviceContext(driver=driver, device_id=name)
            for name, driver in drivers.items()
        }
        multi_ctx = MultiDeviceContext(contexts)
        device_names = list(contexts.keys())

        # Onboard users unless skipped
        if not skip_onboarding:
            minimum_marker = request.node.get_closest_marker("minimum_required")
            minimum_required = _resolve_minimum_marker(minimum_marker)
            if minimum_required is None:
                minimum_required = device_count

            display_names = [generate_account_name(12) for _ in range(device_count)]
            require_all = minimum_required == device_count

            users = await multi_ctx.onboard_users_parallel(
                display_names=display_names, require_all=require_all
            )
            successful_count = sum(1 for u in users if u is not None)
            if successful_count < minimum_required:
                raise SessionManagementError(
                    f"Only {successful_count} device(s) onboarded successfully, "
                    f"but {minimum_required} required"
                )

    except Exception as exc:
        logger.error("Setup failed: %s", exc)
        setup_error = exc

    # SINGLE STORAGE POINT: Always store for hook-based cleanup/reporting
    if pool:
        session_managers = {}
        for name in device_names:
            session_manager = pool.get_session_manager(name)
            if session_manager:
                session_managers[name] = session_manager

        if session_managers:
            logger.info(
                "Storing %d session manager(s) for deferred cleanup (env=%s)",
                len(session_managers),
                test_environment,
            )
            # Store tuple: (session_managers, pool, environment)
            request.node.stash.setdefault(MULTI_DEVICE_MANAGERS_KEY, []).append(
                (session_managers, pool, test_environment)
            )

    # Re-raise setup error after storing
    if setup_error:
        raise setup_error

    yield multi_ctx
