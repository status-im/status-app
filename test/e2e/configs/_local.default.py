import logging

LOG_LEVEL = logging.DEBUG
DEV_BUILD = False

# AUT_PATH: CI build or local dev binary on every platform.

# Linux — run scripts/setup_linux_squish.sh once, then source .venv/bin/activate.
# AUT_PATH = "/path/to/Status.AppImage"
# AUT_PATH = "/path/to/status-app/bin/nim_status_client"

# Windows — run scripts/setup_windows_squish.ps1 once, then .\.venv\Scripts\Activate.ps1.
# Packaged / CI: StatusApp\bin\Status.exe. Local make: StatusDev.exe.
# AUT_PATH = "C:\\Users\\you\\AppData\\Local\\StatusApp\\bin\\Status.exe"
# AUT_PATH = "C:\\path\\to\\status-app\\bin\\StatusDev.exe"

# macOS — CI DMG (Squish entitlements) is Status.app; local make is StatusDev.app.
# Run scripts/setup_mac_squish.sh once, then source .venv/bin/activate.
# AUT_PATH = "/Users/you/Downloads/Status.app"
# AUT_PATH = "/Users/you/status-app/bin/StatusDev.app"

AUT_PATH = "path to the application (.app or .AppImage)"
