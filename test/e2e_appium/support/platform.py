"""Platform detection utilities for cross-platform test support.

Provides lightweight helpers that read ``platformName`` from the Appium
driver's capabilities at runtime so that framework code can branch on
Android vs iOS without hard-coding assumptions.
"""


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
