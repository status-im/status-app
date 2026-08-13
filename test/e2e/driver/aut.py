import os

import allure
import logging
import squish

import configs
import driver
import shortuuid
from tests import test_data
from datetime import datetime
from configs.system import get_platform
from driver import context
from driver.server import SquishServer
from scripts.utils import system_path, local_system
from scripts.utils.failure_screenshot import attach_failure_screenshot
from scripts.utils.system_path import SystemPath
from scripts.utils.wait_for_port import wait_for_port
import psutil

LOG = logging.getLogger(__name__)

# When set (e.g. in CI), startaut adds local Waku flags and passes STATUS_FLEET / STATUS_FLEET_CONFIG_FILE to the AUT.
_LOCAL_WAKU_ENV_VALUES = ('1', 'true', 'yes')


class AUT:
    def __init__(
            self,
            app_path: system_path.SystemPath = configs.AUT_PATH,
            user_data: SystemPath = None
    ):
        self.path = app_path
        self.ctx = None
        self.pid = None
        self.port = None
        self.aut_id = f'AUT_{datetime.now():%H%M%S}'
        self.app_data = configs.testpath.STATUS_DATA / f'app_{shortuuid.ShortUUID().random(length=10)}'
        if user_data is not None:
            user_data.copy_to(self.app_data / 'data')
        self.options = ''
        driver.testSettings.setWrappersForApplication(self.aut_id, ['Qt'])

    def __str__(self):
        return type(self).__qualname__

    def __enter__(self):
        return self.launch()

    def __exit__(self, exc_type, exc_value, traceback):
        if exc_type:
            try:
                self.attach()
                configs.testpath.TEST.mkdir(parents=True, exist_ok=True)
                screenshot = configs.testpath.TEST / f'{self.aut_id}.png'
                attach_failure_screenshot(screenshot, f'Screenshot on fail: {self.aut_id}')
                test_data.aut_screenshot_attached = True
            except Exception as err:
                LOG.error(err)

        self.stop()

    def detach_context(self):
        if self.ctx is None:
            return
        driver.currentApplicationContext().detach()
        self.ctx = None

    @allure.step('Attach Squish to Test Application')
    def attach(self):
        LOG.info('Attaching to AUT: localhost:%d', self.port)

        try:
            SquishServer().add_attachable_aut(self.aut_id, self.port)
            if self.ctx is None:
                self.ctx = context.get_context(self.aut_id)
            driver.setApplicationContext(self.ctx)
            timeout = configs.timeouts.PROCESS_TIMEOUT_SEC_WINDOWS if get_platform() == "Windows" else configs.timeouts.PROCESS_TIMEOUT_SEC
            assert squish.waitFor(lambda: self.ctx.isRunning, timeout)
        except Exception as err:
            LOG.error('Failed to attach AUT: %s', err)
            self.stop()
            raise err
        LOG.info('Successfully attached AUT!')
        return self

    @allure.step('Start AUT')
    def startaut(self):
        LOG.info('Launching AUT: %s', self.path)
        self.port = local_system.find_free_port(configs.squish.AUT_PORT, 100)
        command = [
            str(configs.testpath.SQUISH_DIR / 'bin/startaut'),
            '--verbose',
            f'--port={self.port}',
            str(self.path),
            f'--datadir={self.app_data}',
        ]
        child_env = None
        use_local_waku = os.environ.get('E2E_LOCAL_WAKU_FLEET', '').lower() in _LOCAL_WAKU_ENV_VALUES
        if use_local_waku:
            repo_root = configs.testpath.ROOT.parent.parent
            local_config = (repo_root / 'assets' / 'local-waku-fleets-config.json').resolve()
            local_fleet = os.environ.get('STATUS_FLEET', 'status-app.test')
            command.extend(
                [
                    '--enable-fleet-selection',
                    f'--waku-fleet={local_fleet}',
                    f'--waku-fleets-config={local_config}',
                ]
            )
            child_env = os.environ.copy()
            child_env['STATUS_FLEET'] = local_fleet
            child_env['STATUS_FLEET_CONFIG_FILE'] = str(local_config)
        command.extend(
            [
                f'--LOG_LEVEL={configs.testpath.LOG_LEVEL}',
                '--api-logging',
            ]
        )
        LOG.info('AUT startaut argv (%d parts): %s', len(command), command)
        try:
            with open(configs.AUT_LOG_FILE, "ab") as log:
                self.pid = local_system.execute(command, stderr=log, stdout=log, env=child_env)
        except Exception as err:
            LOG.error('Failed to start AUT: %s', err)
            self.stop()
            raise err
        LOG.info('Launched AUT under PID: %d', self.pid)
        return self

    @allure.step('Close application')
    def stop(self):
        LOG.info('Stopping AUT: %s', self.path)
        self.detach_context()
        if not self.pid:
            return

        app_pids = local_system.get_pid_by_process_name(
            os.path.basename(str(self.path)),
            str(self.app_data),
        ) or []
        pids = {self.pid, *app_pids}
        processes = []
        for pid in pids:
            try:
                processes.append(psutil.Process(pid))
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                pass
            local_system.kill_process(pid)

        _, alive = psutil.wait_procs(processes, timeout=5)
        if alive:
            LOG.warning(
                'AUT processes may still be running: %s',
                [proc.pid for proc in alive],
            )
        self.pid = None

    @allure.step("Start and attach AUT")
    def launch(self) -> 'AUT':
        self.startaut()
        self.wait()
        self.attach()
        return self

    @allure.step('Waiting for port')
    def wait(self, timeout: int = None, retries: int = None):
        # Increase timeout/retries on Windows CI due to slower startup
        if timeout is None:
            timeout = 2 if get_platform() == "Windows" else 1
        if retries is None:
            retries = 20 if get_platform() == "Windows" else 10
        
        LOG.info('Waiting for AUT port localhost:%d... (timeout=%ds, retries=%d)', self.port, timeout, retries)
        try:
            wait_for_port('localhost', self.port, timeout, retries)
        except TimeoutError as err:
            LOG.error('Wait for AUT port timed out: %s', err)
            # Check if process is still running
            if self.pid and psutil:
                try:
                    proc = psutil.Process(self.pid)
                    if proc.is_running():
                        LOG.warning('AUT process %d is still running but port is not available', self.pid)
                    else:
                        LOG.warning('AUT process %d has exited', self.pid)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            self.stop()
            raise err
        LOG.info('AUT port available!')

    @allure.step('Restart application')
    def restart(self):
        self.stop()
        self.launch()
