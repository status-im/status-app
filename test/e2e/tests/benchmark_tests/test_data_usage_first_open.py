"""First-open Wallet data usage. Windows only.

Login, open Wallet, then count process-wide Status traffic through a
fixed 5 minute window after Wallet. Split into Waku, HTTPS, and leftover Other.
"""

import os

import pytest
from allure_commons._allure import step

from configs import get_platform
from driver.aut import AUT
from helpers.chat_helper import skip_message_backup_popup_if_visible
from scripts.utils.benchmark_report import (
    BenchmarkMetricReport,
    attach_benchmark_metrics,
    enable_benchmark_mode,
    measured_data_usage_call,
    record_benchmark_hosts,
)
from scripts.utils.waku_metrics import (
    delta_by_name,
    wait_for_data_usage_baseline,
    wait_for_data_usage_snapshot,
)
from tests.benchmark_tests.benchmark_helpers import (
    BENCHMARK_USER_PARAMS,
    DATA_USAGE_PARAMS,
)

os.environ.setdefault('E2E_STATUS_METRICS', '1')

WALLET_WINDOW_SEC = 300.0
_BYTES_PER_MB = 1024 * 1024

DATA_USAGE_USERS = pytest.mark.parametrize(
    'user_data, user_account',
    DATA_USAGE_PARAMS,
    **BENCHMARK_USER_PARAMS,
)


def _login_and_open_wallet(main_window, user_account) -> None:
    main_window.authorize_user(user_account)
    skip_message_backup_popup_if_visible()
    main_window.left_panel.open_wallet()
    skip_message_backup_popup_if_visible()


def _bytes_to_mb(value: float) -> float:
    return value / _BYTES_PER_MB


@DATA_USAGE_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
@pytest.mark.data_usage
@pytest.mark.timeout(900)
def test_data_usage_first_open(
    aut: AUT,
    main_window,
    user_data,
    user_account,
    tmp_path,
):
    enable_benchmark_mode()
    if not aut.metrics_url:
        raise AssertionError(
            'Waku metrics scrape URL is missing; AUT must start with --metrics'
        )

    with step('Login, open Wallet, and measure traffic for 5 minutes'):
        before = wait_for_data_usage_baseline(aut.metrics_url)
        _, settle = measured_data_usage_call(
            aut,
            lambda: _login_and_open_wallet(main_window, user_account),
            min_wait_sec=WALLET_WINDOW_SEC,
            max_wait_sec=WALLET_WINDOW_SEC,
        )
        after = wait_for_data_usage_snapshot(aut.metrics_url)
        skip_message_backup_popup_if_visible()

    https_delta = delta_by_name(before.http_by_host, after.http_by_host)
    waku_mb = _bytes_to_mb(max(0, after.waku_bytes - before.waku_bytes))
    https_mb = _bytes_to_mb(sum(https_delta.values()))
    other_mb = max(0.0, settle.incremental_mb - waku_mb - https_mb)

    record_benchmark_hosts({
        'https': [
            {'host': host, 'mb': _bytes_to_mb(nbytes)}
            for host, nbytes in https_delta.items()
        ],
    })
    attach_benchmark_metrics(tmp_path, [
        BenchmarkMetricReport(
            attachment_prefix='Total data usage',
            filename='total_data_usage.txt',
            line_subject='Total data usage',
            unit='MB',
            values=[settle.incremental_mb],
            durations_sec=[settle.elapsed_sec],
        ),
        BenchmarkMetricReport(
            attachment_prefix='Waku data usage',
            filename='waku_data_usage.txt',
            line_subject='Waku data usage',
            unit='MB',
            values=[waku_mb],
            durations_sec=[settle.elapsed_sec],
        ),
        BenchmarkMetricReport(
            attachment_prefix='HTTPS data usage',
            filename='https_data_usage.txt',
            line_subject='HTTPS data usage',
            unit='MB',
            values=[https_mb],
            durations_sec=[settle.elapsed_sec],
        ),
        BenchmarkMetricReport(
            attachment_prefix='Other data usage',
            filename='other_data_usage.txt',
            line_subject='Other data usage',
            unit='MB',
            values=[other_mb],
            durations_sec=[settle.elapsed_sec],
        ),
    ])
