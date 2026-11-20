import os
import typing
from datetime import datetime

from scripts.utils.system_path import SystemPath

ROOT: SystemPath = SystemPath(__file__).resolve().parent.parent
REPO_ROOT: SystemPath = ROOT.parent.parent
KEYCARD_SIMULATOR_DIR: SystemPath = (
    REPO_ROOT / 'vendor' / 'status-keycard-qt' / 'test' / 'keycard-simulator'
)
LOCAL_WAKU_FLEETS_CONFIG: SystemPath = REPO_ROOT / 'assets' / 'local-waku-fleets-config.json'

# Runtime initialisation
TEST: typing.Optional[SystemPath] = None
TEST_VP: typing.Optional[SystemPath] = None
TEST_ARTIFACTS: typing.Optional[SystemPath] = None

# Test Directories
RUN_ID = os.getenv('RUN_DIR', f'run_{datetime.today().strftime("%Y-%m-%d %H-%M-%S")}')
RESULTS: SystemPath = ROOT / 'local_run_results'
RUN: SystemPath = RESULTS / RUN_ID
VP: SystemPath = ROOT / 'ext' / 'vp'
TEST_FILES: SystemPath = ROOT / 'ext' / 'test_files'
TEST_IMAGES: SystemPath = ROOT / 'ext' / 'test_images'
TEST_USER_DATA: SystemPath = ROOT / 'ext' / 'user_data'

# Directory that holds generic/libqmlinspector.so, the plugin the driver talks to
INSPECTOR_PLUGINS_RAW = os.getenv('INSPECTOR_PLUGINS')
assert INSPECTOR_PLUGINS_RAW is not None, 'Set INSPECTOR_PLUGINS, see README.md'
INSPECTOR_PLUGINS = SystemPath(INSPECTOR_PLUGINS_RAW)

# Status Application
STATUS_DATA: SystemPath = RUN

# Sets log level, can be one of: "ERROR", "WARN", "INFO", "DEBUG", "TRACE". "INFO"
LOG_LEVEL = 'DEBUG'

