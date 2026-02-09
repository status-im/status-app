import logging
import os
import signal
import subprocess
import typing

import allure
import psutil

import configs
from configs.system import get_platform

LOG = logging.getLogger(__name__)


def find_process_by_port(port: int) -> typing.List[int]:
    pid_list = []
    for proc in psutil.process_iter():
        try:
            for conns in proc.connections(kind='inet'):
                if conns.laddr.port == port:
                    pid_list.append(proc.pid)
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return pid_list


def find_free_port(start: int, step: int):
    while find_process_by_port(start):
        start += step
    return start


@allure.step('Kill process')
def kill_process(pid, timeout_sec=5):
    LOG.debug(f'Terminating process {pid}')

    try:
        if get_platform() == "Windows":
            # Use subprocess.run with timeout to prevent hanging on Windows CI
            subprocess.run(
                f"taskkill /F /T /PID {str(pid)}",
                shell=True,
                timeout=timeout_sec,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        elif get_platform() in ["Linux", "Darwin"]:
            os.kill(pid, signal.SIGKILL)
        else:
            raise NotImplementedError(f"Unsupported platform: {get_platform()}")
    except subprocess.TimeoutExpired:
        LOG.warning(f'taskkill timed out after {timeout_sec}s for process {pid}')
    except Exception as e:
        LOG.warning(f"Failed to terminate process {pid}: {e}")


@allure.step('System execute command')
def execute(
        command: list,
        stderr=subprocess.STDOUT,
        stdout=subprocess.STDOUT,
        shell=False,
):
    LOG.info('Executing: %s', command)
    process = subprocess.Popen(command, shell=shell, stderr=stderr, stdout=stdout)
    return process.pid


@allure.step('System run command')
def run(
        command: list,
        stderr=subprocess.STDOUT,
        stdout=subprocess.STDOUT,
        shell=False,
        timeout_sec=configs.timeouts.PROCESS_TIMEOUT_SEC
):
    LOG.info('Running: %s', command)
    process = subprocess.run(
        command,
        shell=shell,
        stderr=stderr,
        stdout=stdout,
        timeout=timeout_sec,
        check=True
    )


@allure.step('Get pid by process name')
def get_pid_by_process_name(name):
    pid_list = []
    for proc in psutil.process_iter():
        try:
            if proc.name() == name and proc.status() != 'zombie':
                pid_list.append(proc.pid)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return pid_list if len(pid_list) > 0 else None
