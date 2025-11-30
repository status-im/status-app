"""Utility helpers for formatting test names for BrowserStack reporting."""

from typing import Optional


def format_test_name_for_browserstack(
    nodeid: str,
    device_name: Optional[str] = None,
) -> str:
    """Return a compact BrowserStack session name."""

    parts = nodeid.split("::") if nodeid else []

    if len(parts) >= 3:
        # e.g. tests/test_file.py::TestClass::test_method
        class_name = parts[-2]
        method_name = parts[-1]
        test_name = f"{class_name}.{method_name}"
    elif len(parts) == 2:
        # e.g. tests/test_file.py::test_function
        test_name = parts[-1]
    else:
        # Fallback to file stem or raw nodeid when nothing else is available
        file_path = parts[0] if parts else nodeid
        test_name = file_path.split("/")[-1].replace(".py", "")

    if device_name:
        test_name = f"{test_name} [{device_name}]"

    return test_name

