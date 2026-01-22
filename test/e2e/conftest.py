import logging
import configs
import os
import allure
import pytest
import shortuuid
import sys
import subprocess

from tests import test_data
from PIL import ImageGrab
from configs.system import get_platform
from fixtures.path import generate_test_info
from scripts.utils.system_path import SystemPath

# Send logs to pytest.log as well
# Ensure log directory exists
log_dir = os.path.dirname(configs.PYTEST_LOG)
os.makedirs(log_dir, exist_ok=True)
handler = logging.FileHandler(filename=configs.PYTEST_LOG)
logging.basicConfig(
    level=os.getenv('LOG_LEVEL', 'INFO'),
    format='[%(asctime)s] (%(filename)18s:%(lineno)-3s) [%(levelname)-7s] --- %(message)s',
    handlers=[handler],
)
LOG = logging.getLogger(__name__)

pytest_plugins = [
    'fixtures.aut',
    'fixtures.path',
    'fixtures.squish',
]


def get_git_commit():
    """Get git commit hash from parent repository"""
    # Try to get git commit from parent repository (status-app)
    try:
        # Get parent directory (status-app)
        parent_repo = configs.testpath.ROOT.parent.parent
        result = subprocess.run(
            ['git', 'rev-parse', 'HEAD'],
            cwd=str(parent_repo),
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            commit_hash = result.stdout.strip()
            return commit_hash
    except (subprocess.TimeoutExpired, FileNotFoundError, Exception) as e:
        LOG.debug(f'Could not get git commit: {e}')
    
    return None


def get_status_go_commit():
    """Get git commit hash from status-go repository"""
    # Try to get git commit from status-go repository (vendor/status-go)
    try:
        # Get status-go directory (vendor/status-go)
        status_go_repo = configs.testpath.ROOT.parent.parent / 'vendor' / 'status-go'
        result = subprocess.run(
            ['git', 'rev-parse', 'HEAD'],
            cwd=str(status_go_repo),
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            commit_hash = result.stdout.strip()
            return commit_hash
    except (subprocess.TimeoutExpired, FileNotFoundError, Exception) as e:
        LOG.debug(f'Could not get status-go git commit: {e}')
    
    return None


@pytest.fixture(scope='session', autouse=True)
def generate_allure_environment():
    """Generate allure environment.properties with dynamic platform information"""
    env_dir = configs.testpath.ROOT / 'ext' / 'allure_files'
    env_file = env_dir / 'environment.properties'
    
    # Ensure directory exists
    env_dir.mkdir(parents=True, exist_ok=True)
    
    platform_name = get_platform()
    python_version = f"Python {sys.version_info.major}.{sys.version_info.minor}"
    git_commit = get_git_commit()
    status_go_commit = get_status_go_commit()
    
    lines = [f"os_platform = {platform_name}"]
    
    if git_commit:
        lines.append(f"status app commit hash = {git_commit}")
    
    if status_go_commit:
        lines.append(f"status-go commit hash = {status_go_commit}")
    
    lines.append(f"python_version = {python_version}")
    
    content = "\n".join(lines) + "\n"
    
    env_file.write_text(content)
    LOG.info(f'Generated allure environment.properties with platform={platform_name}, status app commit hash={git_commit}, status-go commit hash={status_go_commit}, python={python_version}')
    yield


@pytest.fixture(scope='session', autouse=True)
def setup_session_scope(
        generate_allure_environment,
        prepare_test_directory,
        start_squish_server
):
    LOG.info('Session startup...')
    yield


@pytest.fixture(autouse=True)
def setup_function_scope(
        caplog,
        generate_test_data,
        application_logs,
        launch_keycard_controller
):
    # FIXME: broken due to KeyError: <_pytest.stash.StashKey object at 0x7fd1ba6d78c0>
    # caplog.set_level(configs.LOG_LEVEL)
    yield


def pytest_runtest_setup(item):
    test_data.test_name = item.name

    test_data.error = []
    test_data.steps = []


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    rep = outcome.get_result()
    setattr(item, 'rep_' + rep.when, rep)

    if rep.when == 'call':
        if rep.failed:
            test_data.error = rep.longreprtext
        elif rep.outcome == 'passed':
            if test_data.error:
                rep.outcome = 'failed'
                error_text = str()
                for line in test_data.error:
                    error_text += f"{line}; \n ---- soft assert ---- \n\n"
                rep.longrepr = error_text
    elif rep.failed:
        test_data.error = rep.longreprtext


def pytest_exception_interact(node):
    test_path, test_name, test_params = generate_test_info(node)
    node_dir: SystemPath = configs.testpath.RUN / test_path / test_name / test_params
    node_dir.mkdir(parents=True, exist_ok=True)
    screenshot = node_dir / f'screenshot_{shortuuid.ShortUUID().random(length=10)}.png'
    try:
        ImageGrab.grab(xdisplay=configs.system.DISPLAY if get_platform() == "Linux" else None).save(screenshot)
        allure.attach(
            name='Screenshot on fail',
            body=screenshot.read_bytes(),
            attachment_type=allure.attachment_type.PNG
        )
    except FileNotFoundError:
        print("Screenshot was not generated or saved")
