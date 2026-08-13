import hashlib
import json
import logging
import os
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, TypeVar

import allure
from allure_commons.types import AttachmentType
from allure_commons._allure import step

from driver.aut import AUT
from scripts.utils.process_metrics import ProcessSampleStats, ProcessMonitor, resolve_monitored_pid

LOG = logging.getLogger(__name__)

T = TypeVar('T')
BENCHMARK_RESULTS_ENV = 'BENCHMARK_RESULTS_DIR'
BENCHMARK_SCHEMA_VERSION = 1


@dataclass(frozen=True)
class BenchmarkMetricReport:
    attachment_prefix: str
    filename: str
    line_subject: str
    unit: str
    values: list[float]


@dataclass
class BenchmarkScenarioSamples:
    load_times: list[float] = field(default_factory=list)
    cpu_percents: list[float] = field(default_factory=list)
    ram_mb: list[float] = field(default_factory=list)

    def record(self, load_time: float, stats: ProcessSampleStats) -> None:
        self.load_times.append(load_time)
        self.cpu_percents.append(stats.avg_cpu_percent)
        self.ram_mb.append(stats.avg_ram_mb)


def build_metric_report_lines(line_subject: str, unit: str, values: list[float]) -> list[str]:
    lines = []
    total_runs = len(values)
    for index, value in enumerate(values, start=1):
        line = f'[{index}/{total_runs}] {line_subject}: {value:.3f} {unit}'
        lines.append(line)
        LOG.info(line)

    average = sum(values) / total_runs if values else 0.0
    average_line = f'Average {line_subject} over {total_runs} runs: {average:.3f} {unit}'
    LOG.info(average_line)
    lines.append(average_line)
    return lines


def attach_metric_report(
    tmp_path: Path,
    report_lines: list[str],
    attachment_prefix: str,
    filename: str,
) -> None:
    report_text = '\n'.join(report_lines)
    report_file = tmp_path / filename
    report_file.write_text(report_text, encoding='utf-8')
    allure.attach(report_text, name=f'{attachment_prefix} (text)', attachment_type=AttachmentType.TEXT)
    allure.attach.file(str(report_file), name=f'{attachment_prefix} (file)', attachment_type=AttachmentType.TEXT)


def attach_benchmark_metrics(tmp_path: Path, metrics: list[BenchmarkMetricReport]) -> None:
    record_structured_benchmark_metrics(metrics)
    for metric in metrics:
        report_lines = build_metric_report_lines(metric.line_subject, metric.unit, metric.values)
        with step(f'Attach {metric.attachment_prefix} to Allure'):
            attach_metric_report(tmp_path, report_lines, metric.attachment_prefix, metric.filename)


def _current_test_identity() -> tuple[str, str]:
    nodeid = os.environ.get('PYTEST_CURRENT_TEST', '').split(' (', 1)[0]
    test_name = nodeid.rsplit('::', 1)[-1] if nodeid else 'unknown'
    return nodeid, test_name


def _result_path(nodeid: str) -> Path | None:
    results_dir = os.environ.get(BENCHMARK_RESULTS_ENV, '').strip()
    if not results_dir:
        return None
    digest = hashlib.sha256(nodeid.encode('utf-8')).hexdigest()[:16]
    path = Path(results_dir)
    path.mkdir(parents=True, exist_ok=True)
    return path / f'{digest}.json'


def _load_result(path: Path, nodeid: str, test_name: str) -> dict:
    if path.exists():
        return json.loads(path.read_text(encoding='utf-8'))
    return {
        'schema_version': BENCHMARK_SCHEMA_VERSION,
        'nodeid': nodeid,
        'test_name': test_name,
        'status': 'unknown',
        'duration_ms': 0,
        'retries_count': 0,
        'flaky': False,
        'attempts': 0,
        'metrics': [],
    }


def _write_result(path: Path, result: dict) -> None:
    path.write_text(json.dumps(result, indent=2, sort_keys=True), encoding='utf-8')


def record_structured_benchmark_metrics(metrics: list[BenchmarkMetricReport]) -> None:
    """Write versioned raw samples independently of the Allure report."""
    nodeid, test_name = _current_test_identity()
    path = _result_path(nodeid)
    if path is None:
        return
    result = _load_result(path, nodeid, test_name)
    by_name = {metric['name']: metric for metric in result.get('metrics', [])}
    for metric in metrics:
        by_name[metric.attachment_prefix] = {
            'name': metric.attachment_prefix,
            'unit': metric.unit,
            'values': metric.values,
        }
    result['metrics'] = list(by_name.values())
    _write_result(path, result)


def finalize_structured_benchmark_result(
    nodeid: str,
    test_name: str,
    *,
    status: str,
    duration_seconds: float,
) -> None:
    """Record final pytest status and retries for a benchmark test attempt."""
    path = _result_path(nodeid)
    if path is None:
        return
    result = _load_result(path, nodeid, test_name)
    previous_status = result.get('status', 'unknown')
    attempts = int(result.get('attempts', 0)) + 1
    result.update({
        'status': status,
        'duration_ms': round(float(result.get('duration_ms', 0)) + duration_seconds * 1000),
        'attempts': attempts,
        'retries_count': max(0, attempts - 1),
        'flaky': status == 'passed' and previous_status in {'failed', 'broken'},
    })
    _write_result(path, result)


def enable_benchmark_mode() -> None:
    os.environ['STATUS_RUNTIME_TEST_MODE'] = 'True'  # to omit banners


def _resource_metric_reports(
    subject: str,
    slug: str,
    samples: BenchmarkScenarioSamples,
) -> list[BenchmarkMetricReport]:
    return [
        BenchmarkMetricReport(
            attachment_prefix=f'{subject} CPU usage',
            filename=f'{slug}_cpu_usage.txt',
            line_subject=f'{subject} CPU usage',
            unit='percent',
            values=samples.cpu_percents,
        ),
        BenchmarkMetricReport(
            attachment_prefix=f'{subject} RAM usage',
            filename=f'{slug}_ram_usage.txt',
            line_subject=f'{subject} RAM usage',
            unit='MB',
            values=samples.ram_mb,
        ),
    ]


def attach_resource_reports(
    tmp_path: Path,
    *,
    subject: str,
    slug: str,
    samples: BenchmarkScenarioSamples,
) -> None:
    attach_benchmark_metrics(tmp_path, _resource_metric_reports(subject, slug, samples))


def attach_scenario_reports(
    tmp_path: Path,
    *,
    subject: str,
    slug: str,
    samples: BenchmarkScenarioSamples,
) -> None:
    attach_benchmark_metrics(tmp_path, [
        BenchmarkMetricReport(
            attachment_prefix=f'{subject} load times',
            filename=f'{slug}_load_times.txt',
            line_subject=f'{subject} load time',
            unit='seconds',
            values=samples.load_times,
        ),
        *_resource_metric_reports(subject, slug, samples),
    ])


def monitored_call(aut: AUT, action: Callable[[], T], interval_sec: float = 0.1) -> tuple[T, ProcessSampleStats]:
    monitor_pid = resolve_monitored_pid(aut.pid, aut.path, aut.app_data)
    with ProcessMonitor(monitor_pid, interval_sec=interval_sec) as monitor:
        result = action()
    return result, monitor.stats()


def monitored_timed_call(
    aut: AUT,
    action: Callable[[], T],
    interval_sec: float = 0.1,
) -> tuple[T, float, ProcessSampleStats]:
    def timed_action() -> tuple[T, float]:
        started_at = time.perf_counter()
        result = action()
        return result, time.perf_counter() - started_at

    (result, load_time), stats = monitored_call(
        aut,
        timed_action,
        interval_sec=interval_sec,
    )
    return result, load_time, stats
