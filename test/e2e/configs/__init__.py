import logging
import os

from os import path
from scripts.utils.system_path import SystemPath
from . import testpath, timeouts, squish, system
from .system import get_platform

LOG = logging.getLogger(__name__)

try:
    from ._local import *
except ImportError:
    exit(
        'Config file: "_local.py" not found in "./configs".\n'
        'Please use template "_.local.default.py" to create file or execute command: \n'
        rf'cp {testpath.ROOT}/configs/_local.default.py {testpath.ROOT}/configs/_local.py'
    )

def _resolve_aut_path(aut_path: str) -> SystemPath:
    """Resolve AUT_PATH to the launchable binary.

    macOS accepts:
    - /path/to/Status.app
    - /path/to/Status.app/Contents/MacOS/nim_status_client
    - /path/to/status-app/bin/nim_status_client
    """
    resolved = SystemPath(aut_path)
    if get_platform() != 'Darwin':
        return resolved

    if resolved.suffix == '.app':
        if not resolved.is_dir():
            exit(f'AUT_PATH .app bundle not found: {resolved}')
        binary = resolved / 'Contents' / 'MacOS' / 'nim_status_client'
        if not binary.is_file():
            exit(f'AUT_PATH bundle has no binary at {binary}')
        return binary

    if resolved.is_file():
        return resolved

    exit(
        f'AUT_PATH not found: {resolved}\n'
        'On macOS set AUT_PATH to one of:\n'
        '  /path/to/Status.app\n'
        '  /path/to/Status.app/Contents/MacOS/nim_status_client\n'
        '  /path/to/status-app/bin/nim_status_client'
    )


if AUT_PATH is None:
    exit('Please add "AUT_PATH" in ./configs/_local.py')
if get_platform() == "Windows" and 'Status' not in AUT_PATH:
    exit('Please use launcher from "Status" folder in "AUT_PATH"')
AUT_PATH = _resolve_aut_path(AUT_PATH)
WALLET_SEED = os.getenv('WALLET_TEST_USER_SEED')

# Application and Squish logs (all platforms).
LOG_DIR = testpath.RESULTS
LOG_DIR.mkdir(parents=True, exist_ok=True)
PYTEST_LOG = path.join(LOG_DIR, 'pytest.log')
AUT_LOG_FILE = path.join(LOG_DIR, 'aut.log')
SQUISH_LOG_FILE = path.join(LOG_DIR, 'squish.log')
