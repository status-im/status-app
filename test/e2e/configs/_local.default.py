import logging

LOG_LEVEL = logging.DEBUG
DEV_BUILD = False

# AUT_PATH: CI build or local dev binary on every platform.

# Linux — CI AppImage or local build:
# AUT_PATH = "/path/to/Status.AppImage"
# AUT_PATH = "/path/to/status-app/bin/nim_status_client"

# Windows — CI package or local build (use Status.exe from the StatusApp folder):
# AUT_PATH = "C:\\Users\\you\\AppData\\Local\\StatusApp\\bin\\Status.exe"
# AUT_PATH = "C:\\path\\to\\status-app\\bin\\Status.exe"

# macOS — CI DMG (Squish entitlements) or local build.
# Run scripts/setup_mac_squish.sh once, then source .venv/bin/activate.
# .app bundle or MacOS binary both work:
# AUT_PATH = "/Users/you/Downloads/Status.app"
# AUT_PATH = "/Users/you/Downloads/Status.app/Contents/MacOS/nim_status_client"
# AUT_PATH = "/Users/you/status-app/bin/nim_status_client"

AUT_PATH = "path to the application (.app or .AppImage)"
