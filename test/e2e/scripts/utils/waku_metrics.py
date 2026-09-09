"""Scrape status-go prometheus counters used by data-usage benchmarks."""

from __future__ import annotations

import logging
import re
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field

LOG = logging.getLogger(__name__)

WAKU_BANDWIDTH_RE = re.compile(
    r'^waku_libp2p_bandwidth_bytes\{dir="(in|out)"\}\s+(\d+(?:\.\d+)?)(?:\s+\d+)?\s*$',
    re.MULTILINE,
)
LABELED_COUNTER_RE = re.compile(
    r'^([a-zA-Z_:][a-zA-Z0-9_:]*)\{([^}]*)\}\s+(\d+(?:\.\d+)?)(?:\s+\d+)?\s*$',
    re.MULTILINE,
)
LABEL_RE = re.compile(r'([a-zA-Z_][a-zA-Z0-9_]*)="((?:\\.|[^"\\])*)"')
STATUS_HTTP_METRIC = 'status_http_bytes'


class WakuMetricsUnavailable(RuntimeError):
    pass


@dataclass(frozen=True)
class DataUsageSnapshot:
    waku_bytes: int
    http_by_host: dict[str, int] = field(default_factory=dict)

    @property
    def http_bytes(self) -> int:
        return sum(self.http_by_host.values())


def _parse_labels(raw: str) -> dict[str, str]:
    return {
        name: value.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
        for name, value in LABEL_RE.findall(raw)
    }


def parse_waku_bandwidth_bytes(text: str, *, required: bool = True) -> int:
    found: dict[str, int] = {}
    for direction, value in WAKU_BANDWIDTH_RE.findall(text):
        found[direction] = int(float(value))
    if 'in' not in found or 'out' not in found:
        if not required:
            return 0
        raise WakuMetricsUnavailable(
            'prometheus scrape is missing waku_libp2p_bandwidth_bytes{dir="in|out"}'
        )
    return found['in'] + found['out']


def parse_status_http_by_host(text: str) -> dict[str, int]:
    totals: dict[str, int] = {}
    for name, labels_raw, value in LABELED_COUNTER_RE.findall(text):
        if name != STATUS_HTTP_METRIC:
            continue
        labels = _parse_labels(labels_raw)
        host = labels.get('host') or 'unknown'
        totals[host] = totals.get(host, 0) + int(float(value))
    return totals


def parse_data_usage_snapshot(text: str, *, require_waku: bool = True) -> DataUsageSnapshot:
    return DataUsageSnapshot(
        waku_bytes=parse_waku_bandwidth_bytes(text, required=require_waku),
        http_by_host=parse_status_http_by_host(text),
    )


def scrape_metrics_text(metrics_url: str, timeout_sec: float = 5.0) -> str:
    request = urllib.request.Request(metrics_url, method='GET')
    with urllib.request.urlopen(request, timeout=timeout_sec) as response:
        return response.read().decode('utf-8', errors='replace')


def scrape_waku_bandwidth_bytes(metrics_url: str, timeout_sec: float = 5.0) -> int:
    return parse_waku_bandwidth_bytes(scrape_metrics_text(metrics_url, timeout_sec=timeout_sec))


def scrape_data_usage_snapshot(metrics_url: str, timeout_sec: float = 5.0) -> DataUsageSnapshot:
    return parse_data_usage_snapshot(scrape_metrics_text(metrics_url, timeout_sec=timeout_sec))


def wait_for_waku_bandwidth_bytes(
    metrics_url: str,
    *,
    timeout_sec: float = 30.0,
    interval_sec: float = 1.0,
) -> int:
    return wait_for_data_usage_snapshot(
        metrics_url, timeout_sec=timeout_sec, interval_sec=interval_sec,
    ).waku_bytes


def wait_for_metrics_text(
    metrics_url: str,
    *,
    timeout_sec: float = 30.0,
    interval_sec: float = 1.0,
) -> str:
    deadline = time.monotonic() + timeout_sec
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            return scrape_metrics_text(metrics_url)
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = error
            LOG.debug('Waiting for metrics at %s: %s', metrics_url, error)
            time.sleep(interval_sec)
    raise WakuMetricsUnavailable(
        f'metrics endpoint unavailable at {metrics_url}: {last_error}'
    )


def wait_for_data_usage_baseline(
    metrics_url: str,
    *,
    timeout_sec: float = 30.0,
    interval_sec: float = 1.0,
) -> DataUsageSnapshot:
    text = wait_for_metrics_text(
        metrics_url, timeout_sec=timeout_sec, interval_sec=interval_sec,
    )
    snapshot = parse_data_usage_snapshot(text, require_waku=False)
    LOG.info(
        'status-go baseline: waku=%s https=%s',
        snapshot.waku_bytes, snapshot.http_bytes,
    )
    return snapshot


def wait_for_data_usage_snapshot(
    metrics_url: str,
    *,
    timeout_sec: float = 30.0,
    interval_sec: float = 1.0,
) -> DataUsageSnapshot:
    deadline = time.monotonic() + timeout_sec
    last_error: Exception | None = None
    last_body = ''
    while time.monotonic() < deadline:
        try:
            last_body = scrape_metrics_text(metrics_url)
            snapshot = parse_data_usage_snapshot(last_body)
            LOG.info(
                'status-go counters ready: waku=%s https=%s',
                snapshot.waku_bytes, snapshot.http_bytes,
            )
            return snapshot
        except (WakuMetricsUnavailable, urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = error
            LOG.debug('Waiting for status-go metrics at %s: %s', metrics_url, error)
            time.sleep(interval_sec)
    snippet = last_body[:500].replace('\n', ' | ') if last_body else '(empty)'
    raise WakuMetricsUnavailable(
        f'Waku bandwidth metrics unavailable at {metrics_url}: {last_error}; body={snippet}'
    )


def delta_by_name(before: dict[str, int], after: dict[str, int]) -> dict[str, int]:
    delta: dict[str, int] = {}
    for name in set(before) | set(after):
        value = max(0, after.get(name, 0) - before.get(name, 0))
        if value:
            delta[name] = value
    return dict(sorted(delta.items(), key=lambda item: (-item[1], item[0])))
