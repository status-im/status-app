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
    """On macOS, accept a .app bundle path and resolve to the MacOS binary."""
    path = SystemPath(aut_path)
    if get_platform() != 'Darwin':
        return path
    if path.suffix == '.app' and path.is_dir():
        binary = path / 'Contents' / 'MacOS' / 'nim_status_client'
        if binary.is_file():
            return binary
        exit(f'AUT_PATH bundle has no binary at {binary}')
    if path.is_dir():
        exit(
            f'AUT_PATH must be Status.app or .../Contents/MacOS/nim_status_client, got: {path}'
        )
    return path


if AUT_PATH is None:
    exit('Please add "AUT_PATH" in ./configs/_local.py')
if get_platform() == "Windows" and 'Status' not in AUT_PATH:
    exit('Please use launcher from "Status" folder in "AUT_PATH"')
AUT_PATH = _resolve_aut_path(AUT_PATH)
if get_platform() == 'Darwin' and not AUT_PATH.is_file():
    exit(f'AUT_PATH must point to nim_status_client binary, got: {AUT_PATH}')
WALLET_SEED = os.getenv('WALLET_TEST_USER_SEED')

# Application and Squish logs (all platforms).
LOG_DIR = testpath.RESULTS
LOG_DIR.mkdir(parents=True, exist_ok=True)
PYTEST_LOG = path.join(LOG_DIR, 'pytest.log')
AUT_LOG_FILE = path.join(LOG_DIR, 'aut.log')
SQUISH_LOG_FILE = path.join(LOG_DIR, 'squish.log')
