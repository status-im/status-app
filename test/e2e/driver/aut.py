import os

import allure
import logging

import configs
import shortuuid
from tests import test_data
from configs.system import get_platform
from driver import session
from scripts.utils import local_system
from scripts.utils.failure_screenshot import attach_failure_screenshot
from scripts.utils.system_path import SystemPath
import psutil

LOG = logging.getLogger(__name__)

def _local_extras(
    app_path: SystemPath,
) -> tuple[list[str], dict[str, str]]:
    """Argv and env overrides for local repo `bin/` AUT (keycard sim dir, optional Waku fleet)."""
    env: dict[str, str] = {
        'STATUS_GO_DISABLE_SUPPORT_BOT_CONTACT_REQUEST': '1',
    }
    command_extras: list[str] = []
    local_bin = (configs.testpath.REPO_ROOT / 'bin').resolve()
    sim_dir = configs.testpath.KEYCARD_SIMULATOR_DIR
    if (
        not os.environ.get('STATUS_KEYCARD_SIM_DIR')
        and app_path.resolve().is_relative_to(local_bin)
        and sim_dir.is_dir()
    ):
        env['STATUS_KEYCARD_SIM_DIR'] = str(sim_dir.resolve())
        LOG.info('Local build: STATUS_KEYCARD_SIM_DIR=%s', env['STATUS_KEYCARD_SIM_DIR'])

    if os.environ.get('E2E_LOCAL_WAKU_FLEET', '').lower() in ('1', 'true', 'yes'):
        local_config = configs.testpath.LOCAL_WAKU_FLEETS_CONFIG.resolve()
        local_fleet = os.environ.get('STATUS_FLEET', 'status-app.test')
        command_extras = [
            '--enable-fleet-selection',
            f'--waku-fleet={local_fleet}',
            f'--waku-fleets-config={local_config}',
        ]
        env['STATUS_FLEET'] = local_fleet
        env['STATUS_FLEET_CONFIG_FILE'] = str(local_config)
    return command_extras, env


class AUT:
    def __init__(
            self,
            app_path: SystemPath = configs.AUT_PATH,
            user_data: SystemPath = None,
            test_mode: bool = True,
    ):
        self.path = app_path
        self.session = None
        self.pid = None
        self.port = None
        self.test_mode = test_mode
        self.aut_id = f'AUT_{shortuuid.ShortUUID().random(length=8)}'
        self.app_data = configs.testpath.STATUS_DATA / f'app_{shortuuid.ShortUUID().random(length=10)}'
        if user_data is not None:
            user_data.copy_to(self.app_data / 'data')
        self.options = ''

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

    def disconnect(self):
        if self.session is not None:
            self.session.close()
            self.session = None

    @allure.step('Attach to the application')
    def attach(self):
        """Makes this app the one that commands go to, connecting to it first if needed."""
        if self.session is None or not self.session.is_running:
            LOG.info('Connecting to AUT: 127.0.0.1:%d', self.port)
            timeout = configs.timeouts.PROCESS_TIMEOUT_SEC_WINDOWS if get_platform() == "Windows" else configs.timeouts.PROCESS_TIMEOUT_SEC
            try:
                self.session = session.connect(self.aut_id, self.port, timeout)
            except Exception as err:
                LOG.error('Failed to connect to AUT (process %s): %s', 'running' if psutil.pid_exists(self.pid) else 'exited', err)
                self.stop()
                raise err
            LOG.info('Connected to AUT!')
        session.activate(self.session)
        return self

    @allure.step('Start AUT')
    def start(self):
        LOG.info('Launching AUT: %s', self.path)
        self.port = local_system.find_free_port(configs.system.AUT_PORT, 100)
        command_extras, env_overrides = _local_extras(self.path)
        command = [
            str(self.path),
            f'--datadir={self.app_data}',
            *command_extras,
            f'--LOG_LEVEL={configs.testpath.LOG_LEVEL}',
            '--api-logging',
        ]
        plugin_root = str(configs.testpath.INSPECTOR_PLUGINS)
        plugin = ''
        for name in ('libqmlinspector.dylib', 'libqmlinspector.so', 'qmlinspector.dll'):
            candidate = os.path.join(plugin_root, 'generic', name)
            if os.path.isfile(candidate):
                plugin = candidate
                break
        if not plugin:
            raise RuntimeError(
                f'Inspector plugin not found under {plugin_root}/generic. '
                'Set INSPECTOR_PLUGINS to the directory that contains generic/.'
            )
        LOG.info('Inspector plugin: %s', plugin)
        child_env = {
            **os.environ,
            **env_overrides,
            'QT_PLUGIN_PATH': os.pathsep.join(filter(None, [plugin_root, os.environ.get('QT_PLUGIN_PATH')])),
            'QT_QPA_GENERIC_PLUGINS': f'qmlinspector:{self.port}',
            # The plugin's own switch, not STATUS_RUNTIME_TEST_MODE: some tests start the app with test mode off.
            'QML_INSPECTOR_ALLOW': '1',
        }
        if not self.test_mode:
            child_env['STATUS_RUNTIME_TEST_MODE'] = '0'
        LOG.info('AUT argv (%d parts): %s', len(command), command)
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
        self.disconnect()
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
        self.start()
        self.attach()
        return self

    @allure.step('Restart application')
    def restart(self):
        self.stop()
        self.launch()
