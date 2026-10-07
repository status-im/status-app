import logging
import os
import threading
import time
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
        self._samples_lock = threading.Lock()
        self._cpu_samples: list[float] = []
        self._ram_samples: list[float] = []
        self._primed: list[psutil.Process] = []
        self._opened_at = 0.0
        self._opened_wall = 0.0

    def __enter__(self) -> 'ProcessMonitor':
        self._stop_event.clear()
        with self._samples_lock:
            self._cpu_samples.clear()
            self._ram_samples.clear()
        self._primed = []
        for proc in self._iter_processes():
            try:
                proc.cpu_percent(None)
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
            self._primed.append(proc)
        self._opened_at = time.perf_counter()
        self._opened_wall = time.time()
        self._thread = threading.Thread(target=self._sample_loop, daemon=True)
        self._thread.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        # End the interval opened above before stopping the sampler, so join time stays outside it.
        action_sample = self._read_action_sample(time.perf_counter() - self._opened_at)
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(timeout=2)
        if action_sample is None:
            return
        cpu, ram_mb = action_sample
        with self._samples_lock:
            if not self._cpu_samples:
                self._cpu_samples.append(cpu)
                self._ram_samples.append(ram_mb)

    def stats(self) -> ProcessSampleStats:
        with self._samples_lock:
            if not self._cpu_samples:
                raise RuntimeError(
                    f'No valid CPU/RAM samples collected for AUT process tree pid={self._pid}'
                )
            cpu_samples = list(self._cpu_samples)
            ram_samples = list(self._ram_samples)
        return ProcessSampleStats(
            avg_cpu_percent=sum(cpu_samples) / len(cpu_samples),
            avg_ram_mb=sum(ram_samples) / len(ram_samples),
            max_cpu_percent=max(cpu_samples),
            max_ram_mb=max(ram_samples),
            sample_count=len(cpu_samples),
        )

    def _iter_processes(self) -> list[psutil.Process]:
        processes: list[psutil.Process] = []
        try:
            root = psutil.Process(self._pid)
            processes = [root, *root.children(recursive=True)]
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            LOG.debug('AUT process tree unavailable for pid=%s', self._pid)
        return processes

    def _read_usage(self, processes: list[psutil.Process]) -> tuple[float, float] | None:
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

    def _read_action_sample(self, elapsed_sec: float) -> tuple[float, float] | None:
        """Read the tree as it is now.

        Processes primed in __enter__ keep that CPU baseline. A process created
        during the action has no baseline: its CPU time since creation is
        attributed to the action window. Anything else contributes RSS only.
        """
        primed_by_pid: dict[int, psutil.Process] = {}
        for proc in self._primed:
            try:
                primed_by_pid[proc.pid] = proc
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue

        current = self._iter_processes() or list(primed_by_pid.values())
        cpu_percent = 0.0
        ram_total_bytes = 0
        sampled_processes = 0
        seen: set[int] = set()
        for proc in current:
            try:
                pid = proc.pid
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
            if pid in seen:
                continue
            seen.add(pid)
            baseline = primed_by_pid.get(pid)
            try:
                if baseline is not None:
                    cpu_percent += baseline.cpu_percent(None)
                    ram_total_bytes += baseline.memory_info().rss
                else:
                    cpu_percent += self._new_process_cpu_percent(proc, elapsed_sec)
                    ram_total_bytes += proc.memory_info().rss
                sampled_processes += 1
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        if sampled_processes == 0 or ram_total_bytes == 0:
            return None
        cpu_count = psutil.cpu_count(logical=True) or 1
        return min(cpu_percent / cpu_count, 100.0), ram_total_bytes / (1024 * 1024)

    def _new_process_cpu_percent(self, proc: psutil.Process, elapsed_sec: float) -> float:
        if elapsed_sec <= 0:
            return 0.0
        try:
            created_during_action = proc.create_time() >= self._opened_wall - 0.05
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            return 0.0
        if not created_during_action:
            return 0.0
        times = proc.cpu_times()
        cpu_seconds = times.user + times.system
        return cpu_seconds / elapsed_sec * 100.0

    def _sample_once(self) -> tuple[float, float] | None:
        if self._stop_event.is_set():
            return None
        processes = self._iter_processes()
        if not processes:
            return None

        for proc in processes:
            try:
                proc.cpu_percent(None)
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue

        if self._stop_event.wait(self._interval_sec) or self._stop_event.is_set():
            return None
        return self._read_usage(processes)

    def _sample_loop(self) -> None:
        while not self._stop_event.is_set():
            sample = self._sample_once()
            if sample is None:
                if self._stop_event.is_set():
                    return
                self._stop_event.wait(self._interval_sec)
                continue
            cpu, ram_mb = sample
            with self._samples_lock:
                if self._stop_event.is_set():
                    return
                self._cpu_samples.append(cpu)
                self._ram_samples.append(ram_mb)
