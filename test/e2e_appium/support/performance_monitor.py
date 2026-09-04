
import time
from typing import Dict, Any
from contextlib import contextmanager
from datetime import datetime

from config.logging_config import get_logger


class PerformanceMonitor:

    def __init__(self, logger_name: str = "performance"):
        self.logger = get_logger(logger_name)
        self.metrics: Dict[str, Any] = {}
        self.start_times: Dict[str, float] = {}

    @contextmanager
    def measure_operation(self, operation_name: str):
        start_time = time.time()
        self.start_times[operation_name] = start_time

        try:
            yield
        finally:
            duration = time.time() - start_time
            self.metrics[operation_name] = {
                "duration_ms": int(duration * 1000),
                "timestamp": datetime.now().isoformat(),
            }
            self.logger.debug(f"⏱️ {operation_name}: {duration:.3f}s")

    def start_timer(self, operation_name: str) -> None:
        self.start_times[operation_name] = time.time()

    def end_timer(self, operation_name: str) -> float:
        if operation_name not in self.start_times:
            self.logger.warning(f"No start time found for {operation_name}")
            return 0.0

        duration = time.time() - self.start_times[operation_name]
        self.metrics[operation_name] = {
            "duration_ms": int(duration * 1000),
            "timestamp": datetime.now().isoformat(),
        }
        del self.start_times[operation_name]
        return duration

    def get_summary(self) -> Dict[str, Any]:
        if not self.metrics:
            return {"total_operations": 0}

        durations = [m["duration_ms"] for m in self.metrics.values()]
        return {
            "total_operations": len(self.metrics),
            "total_duration_ms": sum(durations),
            "average_duration_ms": sum(durations) // len(durations),
            "slowest_operation": max(
                self.metrics.items(), key=lambda x: x[1]["duration_ms"]
            ),
            "operations": self.metrics,
        }
