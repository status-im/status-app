import json
import logging
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import allure
import configs
import driver
from eth_account import Account
from eth_account.messages import encode_defunct
from helpers.wallet_helper import open_wallet_account
from web3 import Web3

LOG = logging.getLogger(__name__)

_DAPP_DIR = configs.testpath.ROOT / 'scripts' / 'wallet_connect_dapp'
_DAPP_SCRIPT = _DAPP_DIR / 'run_wc_dapp.js'
_SIGN_CLIENT_PACKAGE = _DAPP_DIR / 'node_modules/@walletconnect/sign-client/package.json'


@allure.step('Connect WalletConnect dApp and request personal_sign')
def request_personal_sign(main_window, dapp: 'WalletConnectDapp', address: str) -> None:
    dapp.start(address)
    wallet_account = open_wallet_account(main_window)
    uri = dapp.wait_for_uri()
    dapps_workflow = wallet_account.open_dapps_connect_flow()
    dapps_workflow.pair_with_uri(uri).approve_connection_and_close()
    dapp.wait_until_connected()
    dapps_workflow.approve_sign_request()


_NODE_REQUIREMENT = 'Node.js 20.19–20.x or 22+'


def _node_fallback_paths() -> tuple[Path, ...]:
    if os.name == 'nt':
        paths = []
        if nvm_symlink := os.getenv('NVM_SYMLINK'):
            paths.append(Path(nvm_symlink) / 'node.exe')
        if program_files := os.getenv('ProgramFiles'):
            paths.append(Path(program_files) / 'nodejs' / 'node.exe')
        return tuple(paths)

    paths = [
        Path('/usr/local/bin/node'),
        Path('/usr/bin/node'),
        *Path.home().joinpath('.nvm', 'versions', 'node').glob('*/bin/node'),
    ]
    if sys.platform == 'darwin':
        paths.extend((
            Path('/opt/homebrew/bin/node'),
            *Path('/opt/homebrew/opt').glob('node*/bin/node'),
        ))
    return tuple(paths)


def _node_version(node_path: str) -> tuple[int, int] | None:
    try:
        output = subprocess.check_output(
            [node_path, '-v'],
            text=True,
            timeout=5,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    parts = output.strip().lstrip('v').split('.')
    try:
        return int(parts[0]), int(parts[1])
    except (ValueError, IndexError):
        return None


def _is_supported_node(node_path: str) -> bool:
    version = _node_version(node_path)
    if version is None:
        return False
    major, minor = version
    return (major == 20 and minor >= 19) or major >= 22


def _resolve_node_binary() -> str:
    if configured_node := os.getenv('NODE_BIN'):
        node_path = Path(configured_node).expanduser()
        if not node_path.is_file():
            raise FileNotFoundError(f'NODE_BIN does not point to a file: {node_path}')
        resolved = str(node_path)
        if not _is_supported_node(resolved):
            raise FileNotFoundError(
                f'NODE_BIN {resolved} is not {_NODE_REQUIREMENT}'
            )
        return resolved

    candidates = []
    if node_on_path := shutil.which('node'):
        candidates.append(Path(node_on_path))
    candidates.extend(_node_fallback_paths())

    supported = []
    seen = set()
    for candidate in candidates:
        resolved = str(candidate)
        if resolved in seen:
            continue
        seen.add(resolved)
        if candidate.is_file() and os.access(candidate, os.X_OK) and _is_supported_node(resolved):
            supported.append(resolved)

    if supported:
        return max(supported, key=lambda path: _node_version(path) or (0, 0))

    raise FileNotFoundError(
        f'{_NODE_REQUIREMENT} not found. Install it or set NODE_BIN, then run:\n'
        f'  cd {_DAPP_DIR} && npm ci'
    )


class WalletConnectDapp:

    def __init__(self, message: str = 'Status e2e WC sign'):
        self._process: subprocess.Popen | None = None
        self._status_file: Path | None = None
        self._message = message

    def __enter__(self) -> 'WalletConnectDapp':
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.stop()

    @allure.step('Start WalletConnect test dApp for {address}')
    def start(self, address: str) -> 'WalletConnectDapp':
        if self._process is not None:
            raise RuntimeError('WalletConnect dApp is already running')

        if not _SIGN_CLIENT_PACKAGE.is_file():
            raise FileNotFoundError(
                'WalletConnect dApp dependencies are missing. Run:\n'
                f'  cd {_DAPP_DIR} && npm ci'
            )

        node_binary = _resolve_node_binary()
        handle = tempfile.NamedTemporaryFile(prefix='wc_dapp_status_', suffix='.json', delete=False)
        handle.close()
        self._status_file = Path(handle.name)

        command = [
            node_binary,
            str(_DAPP_SCRIPT),
            '--address', address,
            '--message', self._message,
            '--status-file', str(self._status_file),
        ]
        LOG.info('Starting WalletConnect dApp: %s', command)
        self._process = subprocess.Popen(
            command,
            cwd=str(_DAPP_DIR),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return self

    def _read_status(self) -> dict:
        if self._status_file is None or not self._status_file.exists():
            return {}
        try:
            return json.loads(self._status_file.read_text(encoding='utf-8').strip() or '{}')
        except json.JSONDecodeError:
            return {}

    def _wait_for_phase(self, phase: str, timeout_msec: int) -> dict:
        process = self._process
        if process is None:
            raise RuntimeError('WalletConnect dApp is not running')

        process_error: str | None = None

        def _phase_reached() -> bool:
            nonlocal process_error
            status = self._read_status()
            current_phase = status.get('phase')
            if current_phase == phase:
                return True
            if current_phase == 'error':
                process_error = f'WalletConnect dApp failed: {status.get("error", status)}'
                return True
            if process.poll() is not None:
                process_error = (
                    f'WalletConnect dApp exited with code {process.returncode} '
                    f'before phase {phase!r}'
                )
                return True
            return False

        reached = driver.waitFor(_phase_reached, timeout_msec)
        if process_error:
            raise AssertionError(process_error)
        assert reached, (
            f'WalletConnect dApp did not reach phase {phase!r}, got {self._read_status()}'
        )
        return self._read_status()

    @allure.step('Wait for WalletConnect pairing URI')
    def wait_for_uri(self, timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC) -> str:
        status = self._wait_for_phase('uri_ready', timeout_msec)
        uri = status.get('uri', '')
        assert uri.startswith('wc:'), f'Unexpected WalletConnect URI: {uri!r}'
        return uri

    @allure.step('Wait until WalletConnect dApp is connected')
    def wait_until_connected(self, timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC):
        self._wait_for_phase('session_approved', timeout_msec)

    @allure.step('Verify personal_sign recovered the expected address')
    def assert_signed_by(self, address: str, timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC):
        status = self._wait_for_phase('sign_complete', timeout_msec)
        signature = str(status.get('signature', ''))
        assert signature.startswith('0x'), f'Unexpected signature: {signature!r}'
        recovered = Web3.to_checksum_address(
            Account.recover_message(encode_defunct(text=self._message), signature=signature)
        )
        expected = Web3.to_checksum_address(address)
        assert recovered == expected, (
            f'personal_sign recovered {recovered}, expected {expected}; signature={signature}'
        )

    @allure.step('Stop WalletConnect test dApp')
    def stop(self):
        if self._process is not None:
            if self._process.poll() is None:
                self._process.terminate()
                try:
                    self._process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self._process.kill()
                    self._process.wait(timeout=5)
            self._process = None

        if self._status_file is not None:
            self._status_file.unlink(missing_ok=True)
            self._status_file = None
