import logging
import time
import typing

import configs.testpath
from scripts.utils import local_system
from scripts.utils.wait_for_port import wait_for_port

_PROCESS_NAME = '_squishserver'

LOG = logging.getLogger(__name__)


class SquishServer:
    __instance = None
    path = configs.testpath.SQUISH_DIR / 'bin' / 'squishserver'
    config = configs.testpath.ROOT / 'squish.ini'
    host = '127.0.0.1'
    port = None
    pid = None

    def __new__(cls):
        if not SquishServer.__instance:
            SquishServer.__instance = super(SquishServer, cls).__new__(cls)
        return SquishServer.__instance

    @classmethod
    def start(cls):
        cls.port = local_system.find_free_port(configs.squish.SERVER_PORT, 100)
        LOG.info('Starting Squish Server on port: %d', cls.port)
        cmd = [
            str(cls.path),
            '--verbose',
            f'--configfile={cls.config}',
            f'--host={cls.host}',
            f'--port={cls.port}',
        ]
        with open(configs.SQUISH_LOG_FILE, "ab") as log:
            cls.pid = local_system.execute(cmd, stderr=log, stdout=log)

    @classmethod
    def stop(cls):
        if cls.pid is None:
            return
        LOG.info('Stopping Squish Server with PID: %d', cls.pid)
        local_system.kill_process(cls.pid)
        time.sleep(1) # FIXME: Implement waiting for process to actually exit.
        cls.pid = None
        cls.port = None

    @classmethod
    def wait(cls, timeout: int = 1, retries: int = 10):
        LOG.info('Waiting for Squish server port %s:%d...', cls.host, cls.port)
        wait_for_port(cls.host, cls.port, timeout, retries)
        LOG.info('Squish server port available!')

    # https://doc-snapshots.qt.io/squish/cli-squishserver.html
    @classmethod
    def configuring(cls, action: str, options: typing.Union[int, str, list]):
        LOG.info('Configuring Squish server config: %s', cls.config)
        cmd = [
            str(cls.path),
            f'--configfile={cls.config}',
            f'--config={action}',
        ] + options
        with open(configs.SQUISH_LOG_FILE, "ab") as log:
            rval = local_system.run(cmd, stdout=log, stderr=log)

    @classmethod
    def add_attachable_aut(cls, aut_id: str, port: int):
        cls.configuring('addAttachableAUT', [aut_id, f'127.0.0.1:{port}'])
