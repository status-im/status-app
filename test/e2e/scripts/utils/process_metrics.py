import logging
import threading
from dataclasses import dataclass

import psutil

LOG = logging.getLogger(__name__)


@dataclass
class ProcessSampleStats:
    avg_cpu_percent: float
    avg_ram_mb: float
    max_cpu_percent: float
    max_ram_mb: float
    sample_count: int


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
            return ProcessSampleStats(0.0, 0.0, 0.0, 0.0, 0)
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

    def _sample_once(self) -> tuple[float, float]:
        cpu_total = 0.0
        ram_total_bytes = 0
        for proc in self._iter_processes():
            try:
                cpu_total += proc.cpu_percent(None)
                ram_total_bytes += proc.memory_info().rss
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        return cpu_total, ram_total_bytes / (1024 * 1024)

    def _sample_loop(self) -> None:
        for proc in self._iter_processes():
            try:
                proc.cpu_percent(None)
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue

        while not self._stop_event.is_set():
            cpu, ram_mb = self._sample_once()
            self._cpu_samples.append(cpu)
            self._ram_samples.append(ram_mb)
            self._stop_event.wait(self._interval_sec)
