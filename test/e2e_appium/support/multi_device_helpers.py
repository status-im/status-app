"""Multi-device test helpers.

Standalone utilities for multi-device tests.
"""

from __future__ import annotations

from contextlib import contextmanager, asynccontextmanager
from typing import TYPE_CHECKING, Union

import pytest

from config.logging_config import get_logger

if TYPE_CHECKING:
    from core.device_context import DeviceContext
    from core.multi_device_context import MultiDeviceContext


def _resolve_device_name(device: Union[str, "DeviceContext"]) -> str:
    """Extract device name from DeviceContext or return string as-is."""
    if hasattr(device, "device_id"):
        return device.device_id
    return str(device)


@contextmanager
def device_step(
    devices: "MultiDeviceContext",
    device: Union[str, "DeviceContext"],
    description: str,
    logger=None,
):
    """
    Context manager for device-specific operations with error logging.

    Args:
        devices: MultiDeviceContext managing all devices
        device: Device identifier or DeviceContext instance
        description: Description of the step
        logger: Optional logger instance (uses default if not provided)

    Yields:
        None

    Raises:
        Exception: Re-raises any exception after logging and marking device failed
    """
    device_name = _resolve_device_name(device)
    log = logger or get_logger("device_step")

    try:
        yield
    except Exception as exc:
        log.error(
            "Device step failed [%s]: %s - %s",
            device_name,
            description,
            exc,
        )
        if devices is not None:
            devices.mark_device_failed(device_name, str(exc))
        raise


@asynccontextmanager
async def async_device_step(
    devices: "MultiDeviceContext",
    device: Union[str, "DeviceContext"],
    description: str,
    logger=None,
):
    """
    Async context manager for device-specific operations with error logging.

    Args:
        devices: MultiDeviceContext managing all devices
        device: Device identifier or DeviceContext instance
        description: Description of the step
        logger: Optional logger instance (uses default if not provided)

    Yields:
        None

    Raises:
        Exception: Re-raises any exception after logging and marking device failed
    """
    device_name = _resolve_device_name(device)
    log = logger or get_logger("device_step")

    try:
        yield
    except Exception as exc:
        log.error(
            "Device step failed [%s]: %s - %s",
            device_name,
            description,
            exc,
        )
        if devices is not None:
            devices.mark_device_failed(device_name, str(exc))
        raise


def require_devices(devices: "MultiDeviceContext", count: int = 2):
    """
    Validate and return required number of devices from context.

    Args:
        devices: MultiDeviceContext to validate
        count: Minimum number of devices required

    Returns:
        Tuple of DeviceContext instances

    Raises:
        AssertionError: If devices context is invalid or insufficient
    """
    from core.multi_device_context import MultiDeviceContext

    assert isinstance(devices, MultiDeviceContext), "Multi-device context not attached"
    assert len(devices) >= count, f"Expected at least {count} onboarded devices, got {len(devices)}"

    return tuple(devices[f"device_{i}"] for i in range(count))


class StepMixin:
    """
    Mixin providing step() helper and auto-initialized device context.

    Usage:
        class TestFoo(StepMixin):
            async def test_bar(self):
                async with self.step(self.device, "Do something"):
                    page = SomePage(self.device.driver)
                    ...

            # Multi-device: use get_device() and @pytest.mark.device_count(2)
            @pytest.mark.device_count(2)
            async def test_multi(self):
                sender = self.device  # or self.get_device(0)
                receiver = self.get_device(1)

            # Raw devices (no onboarding): use @pytest.mark.raw_devices
            @pytest.mark.raw_devices
            async def test_onboarding_flow(self):
                # self.device.driver is available but user not onboarded
                ...
    """

    devices: "MultiDeviceContext" = None
    device: "DeviceContext" = None
    _logger = None

    @pytest.fixture(autouse=True)
    def _setup_devices(self, devices: "MultiDeviceContext"):
        """Auto-attach device context from the unified devices fixture."""
        self.devices = devices
        self.device = devices["device_0"]

    @property
    def logger(self):
        """Auto-initialize logger on first access."""
        if self._logger is None:
            self._logger = get_logger(self.__class__.__name__)
        return self._logger

    @logger.setter
    def logger(self, value):
        self._logger = value

    def get_device(self, index: int) -> "DeviceContext":
        """Get device by index for multi-device tests."""
        return self.devices[f"device_{index}"]

    def step(self, device: Union[str, "DeviceContext"], description: str):
        """Shorthand for async_device_step with bound devices and logger."""
        return async_device_step(self.devices, device, description, self.logger)

