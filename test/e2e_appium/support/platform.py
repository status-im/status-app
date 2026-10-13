"""Platform detection utilities for cross-platform test support.

Provides lightweight helpers that read ``platformName`` from the Appium
driver's capabilities at runtime so that framework code can branch on
Android vs iOS without hard-coding assumptions.
"""

import os


def get_platform(driver) -> str:
    """Return the normalised platform name from driver capabilities.

    Returns ``"android"`` or ``"ios"`` (lowercase).  Falls back to
    ``"android"`` when the capability is missing or empty — this keeps
    existing behaviour unchanged for tests that predate iOS support.
    """
    caps = getattr(driver, "capabilities", None) or {}
    return (caps.get("platformName") or "android").lower()


def is_ios(driver) -> bool:
    """Return ``True`` when the driver session targets an iOS device."""
    return get_platform(driver) == "ios"


def is_android(driver) -> bool:
    """Return ``True`` when the driver session targets an Android device."""
    return get_platform(driver) in ("android", "")


def target_platform(environment: str) -> str:
    """The platform a run will drive, read from its device config before any
    session exists: the device ``TEST_DEVICE_ID`` names, else the
    environment's default device. ``"android"`` when it cannot be resolved,
    matching ``get_platform``."""
    from core.config_manager import ConfigurationManager

    try:
        env_cfg = ConfigurationManager().load_environment(environment, validate=False)
        device = env_cfg.get_device(os.getenv("TEST_DEVICE_ID") or None)
        caps = device.merged_capabilities(env_cfg.device_defaults.get("capabilities", {}))
        return (caps.get("platformName") or "android").lower()
    except Exception:
        return "android"


def ios_bundle_id(driver, default: str = "app.status.mobile") -> str:
    """The app's bundle identifier from whichever capability key the session
    reports; BrowserStack sessions built from an uploaded app may report none."""
    caps = getattr(driver, "capabilities", None) or {}
    return (
        caps.get("appium:bundleId")
        or caps.get("bundleId")
        or caps.get("CFBundleIdentifier")
        or default
    )
