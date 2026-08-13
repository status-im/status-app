import logging
import os
import threading
from dataclasses import dataclass

import psutil

from scripts.utils import local_system

LOG = logging.getLogger(__name__)


@dataclass
class ProcessSampleStats:
    avg_cpu_percent: float
    avg_ram_mb: float
    max_cpu_percent: float
    max_ram_mb: float
    sample_count: int


def resolve_monitored_pid(pid: int, app_path=None, app_data=None) -> int:
    """Use the real AUT process when pid points at an idle startaut wrapper."""
    if app_path is None:
        return pid

    exe_name = os.path.basename(str(app_path))
    try:
        root = psutil.Process(pid)
        if root.is_running():
            if root.children(recursive=True):
                return pid
            if root.name() == exe_name:
                return pid
    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
        pass

    if app_data is not None:
        matched = local_system.get_pid_by_process_name(exe_name, str(app_data))
        if matched:
            return matched[-1]

    candidate_pids = local_system.get_pid_by_process_name(exe_name) or []
    if candidate_pids:
        return candidate_pids[-1]
    return pid


class ProcessMonitor:
    """Sample CPU % and RSS (MB) for an AUT process tree while a benchmark action runs."""

    def __init__(self, pid: int, interval_sec: float = 0.1):
        self._pid = pid
        self._interval_sec = interval_sec
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None
        self._cpu_samples: list[float] = []
        self._ram_samples: list[float] = []

    def __enter__(self) -> 'ProcessMonitor':
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._sample_loop, daemon=True)
        self._thread.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(timeout=2)

    def stats(self) -> ProcessSampleStats:
        if not self._cpu_samples:
            raise RuntimeError(
                f'No valid CPU/RAM samples collected for AUT process tree pid={self._pid}'
            )
        return ProcessSampleStats(
            avg_cpu_percent=sum(self._cpu_samples) / len(self._cpu_samples),
            avg_ram_mb=sum(self._ram_samples) / len(self._ram_samples),
            max_cpu_percent=max(self._cpu_samples),
            max_ram_mb=max(self._ram_samples),
            sample_count=len(self._cpu_samples),
        )

    def _iter_processes(self) -> list[psutil.Process]:
        processes: list[psutil.Process] = []
        try:
            root = psutil.Process(self._pid)
            processes = [root, *root.children(recursive=True)]
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            LOG.debug('AUT process tree unavailable for pid=%s', self._pid)
        return processes

    def _sample_once(self) -> tuple[float, float] | None:
        processes = self._iter_processes()
        if not processes:
            return None

        for proc in processes:
            try:
                proc.cpu_percent(None)
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue

        if self._stop_event.wait(self._interval_sec):
            return None

        cpu_percent = 0.0
        ram_total_bytes = 0
        sampled_processes = 0
        for proc in processes:
            try:
                cpu_percent += proc.cpu_percent(None)
                ram_total_bytes += proc.memory_info().rss
                sampled_processes += 1
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        if sampled_processes == 0 or ram_total_bytes == 0:
            return None
        cpu_count = psutil.cpu_count(logical=True) or 1
        return min(cpu_percent / cpu_count, 100.0), ram_total_bytes / (1024 * 1024)

    def _sample_loop(self) -> None:
        while not self._stop_event.is_set():
            sample = self._sample_once()
            if sample is None:
                self._stop_event.wait(self._interval_sec)
                continue
            cpu, ram_mb = sample
            self._cpu_samples.append(cpu)
            self._ram_samples.append(ram_mb)
