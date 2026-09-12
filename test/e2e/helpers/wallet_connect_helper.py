import json
import logging
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import allure

import configs
import driver

LOG = logging.getLogger(__name__)

_DAPP_DIR = configs.testpath.ROOT / 'scripts' / 'wallet_connect_dapp'
_DAPP_SCRIPT = _DAPP_DIR / 'run_wc_dapp.js'
_NODE_MODULES = _DAPP_DIR / 'node_modules'


def _resolve_node_binary() -> str:
    node_bin = os.getenv('NODE_BIN')
    if node_bin:
        node_path = Path(node_bin).expanduser()
        if not node_path.is_file():
            raise FileNotFoundError(f'NODE_BIN does not point to a file: {node_path}')
        return str(node_path)

    node_on_path = shutil.which('node')
    if node_on_path:
        return node_on_path

    raise FileNotFoundError(
        'Node.js not found. Install Node.js or set NODE_BIN, then run:\n'
        f'  cd {_DAPP_DIR} && npm ci'
    )


class WalletConnectDapp:

    def __init__(self):
        self._process: subprocess.Popen | None = None
        self._status_file: Path | None = None

    @allure.step('Start WalletConnect test dApp for {address}')
    def start(self, address: str, message: str = 'Status e2e WC sign') -> 'WalletConnectDapp':
        if self._process is not None:
            raise RuntimeError('WalletConnect dApp is already running')

        if not _NODE_MODULES.is_dir():
            raise FileNotFoundError(
                'WalletConnect dApp dependencies are missing. Run:\n'
                f'  cd {_DAPP_DIR} && npm ci'
            )

        node_binary = _resolve_node_binary()
        handle = tempfile.NamedTemporaryFile(prefix='wc_dapp_status_', suffix='.json', delete=False)
        handle.close()
        self._status_file = Path(handle.name)
        self._write_status({'phase': 'launching'})

        command = [
            node_binary,
            str(_DAPP_SCRIPT),
            '--address', address,
            '--message', message,
            '--status-file', str(self._status_file),
        ]
        LOG.info('Starting WalletConnect dApp: %s', command)
        self._process = subprocess.Popen(
            command,
            cwd=str(_DAPP_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return self

    def _read_status(self) -> dict:
        if self._status_file is None or not self._status_file.exists():
            return {}
        try:
            return json.loads(self._status_file.read_text(encoding='utf-8').strip() or '{}')
        except json.JSONDecodeError:
            return {}

    def _write_status(self, payload: dict):
        if self._status_file is None:
            return
        self._status_file.write_text(json.dumps(payload), encoding='utf-8')

    @allure.step('Wait for WalletConnect dApp phase {phase}')
    def wait_for_phase(self, phase: str, timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC) -> dict:
        def _phase_reached() -> bool:
            status = self._read_status()
            current_phase = status.get('phase')
            if current_phase == 'error':
                raise AssertionError(
                    f'WalletConnect dApp failed: {status.get("error", status)}'
                )
            return current_phase == phase

        assert driver.waitFor(_phase_reached, timeout_msec), (
            f'WalletConnect dApp did not reach phase {phase!r}, got {self._read_status()}'
        )
        return self._read_status()

    @allure.step('Wait for WalletConnect pairing URI')
    def wait_for_uri(self, timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC) -> str:
        status = self.wait_for_phase('uri_ready', timeout_msec)
        uri = status.get('uri', '')
        assert uri.startswith('wc:'), f'Unexpected WalletConnect URI: {uri!r}'
        return uri

    @allure.step('Wait for WalletConnect personal_sign signature')
    def wait_for_signature(self, timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC) -> str:
        status = self.wait_for_phase('sign_complete', timeout_msec)
        signature = str(status.get('signature', ''))
        assert signature.startswith('0x'), f'Unexpected signature: {signature!r}'
        return signature

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
            if self._process.returncode not in (0, None):
                stderr = (self._process.stderr.read() if self._process.stderr else '') or ''
                stdout = (self._process.stdout.read() if self._process.stdout else '') or ''
                LOG.warning(
                    'WalletConnect dApp exited with code %s\nstdout: %s\nstderr: %s',
                    self._process.returncode,
                    stdout,
                    stderr,
                )
            self._process = None

        if self._status_file is not None and self._status_file.exists():
            self._status_file.unlink(missing_ok=True)
            self._status_file = None
