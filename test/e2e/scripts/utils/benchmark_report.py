import logging
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, TypeVar

import allure
from allure_commons.types import AttachmentType
from allure_commons._allure import step

from scripts.utils.process_metrics import ProcessSampleStats, ProcessMonitor

LOG = logging.getLogger(__name__)

T = TypeVar('T')


@dataclass(frozen=True)
class BenchmarkMetricReport:
    attachment_prefix: str
    filename: str
    line_subject: str
    unit: str
    values: list[float]


@dataclass
class CommunityOpenSamples:
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
    for metric in metrics:
        report_lines = build_metric_report_lines(metric.line_subject, metric.unit, metric.values)
        with step(f'Attach {metric.attachment_prefix} to Allure'):
            attach_metric_report(tmp_path, report_lines, metric.attachment_prefix, metric.filename)


def enable_benchmark_mode() -> None:
    os.environ['STATUS_RUNTIME_TEST_MODE'] = 'True'  # to omit banners


def attach_load_time_report(
    tmp_path: Path,
    *,
    attachment_prefix: str,
    line_subject: str,
    filename: str,
    load_times: list[float],
) -> None:
    attach_benchmark_metrics(tmp_path, [
        BenchmarkMetricReport(
            attachment_prefix=attachment_prefix,
            filename=filename,
            line_subject=line_subject,
            unit='seconds',
            values=load_times,
        ),
    ])


def attach_community_scenario_reports(tmp_path: Path, scenario: str, samples: CommunityOpenSamples) -> None:
    subject = f'Status community {scenario}'
    slug = scenario.replace(' ', '_')
    attach_benchmark_metrics(tmp_path, [
        BenchmarkMetricReport(
            attachment_prefix=f'{subject} load times',
            filename=f'status_community_{slug}_load_times.txt',
            line_subject=f'{subject} load time',
            unit='seconds',
            values=samples.load_times,
        ),
        BenchmarkMetricReport(
            attachment_prefix=f'{subject} CPU usage',
            filename=f'status_community_{slug}_cpu_usage.txt',
            line_subject=f'{subject} CPU usage',
            unit='percent',
            values=samples.cpu_percents,
        ),
        BenchmarkMetricReport(
            attachment_prefix=f'{subject} RAM usage',
            filename=f'status_community_{slug}_ram_usage.txt',
            line_subject=f'{subject} RAM usage',
            unit='MB',
            values=samples.ram_mb,
        ),
    ])


def monitored_call(pid: int, action: Callable[[], T], interval_sec: float = 0.1) -> tuple[T, ProcessSampleStats]:
    with ProcessMonitor(pid, interval_sec=interval_sec) as monitor:
        result = action()
    return result, monitor.stats()
