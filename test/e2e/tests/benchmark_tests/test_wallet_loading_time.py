import pytest
from allure_commons._allure import step

from configs import get_platform
from driver.aut import AUT
from scripts.utils.benchmark_report import (
    BenchmarkScenarioSamples,
    attach_scenario_reports,
    enable_benchmark_mode,
    monitored_call,
)
from tests.benchmark_tests.benchmark_helpers import BENCHMARK_USER_PARAMS, WALLET_BENCHMARK_PARAMS

ITERATIONS = 5
WALLET_BENCHMARK_USERS = pytest.mark.parametrize(
    'user_data, user_account',
    WALLET_BENCHMARK_PARAMS,
    **BENCHMARK_USER_PARAMS,
)


def _record_monitored_wallet_open(
    aut: AUT,
    main_screen,
    samples: BenchmarkScenarioSamples,
) -> None:
    (_, load_time), stats = monitored_call(
        aut,
        main_screen.left_panel.open_wallet_and_record_load_time,
    )
    samples.record(load_time, stats)


@WALLET_BENCHMARK_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_wallet_first_open_loading_time(
    aut: AUT,
    main_screen,
    user_data,
    user_account,
    tmp_path,
):
    enable_benchmark_mode()
    samples = BenchmarkScenarioSamples()

    with step('Open Wallet for the first time after login and record metrics'):
        _record_monitored_wallet_open(aut, main_screen, samples)

    attach_scenario_reports(
        tmp_path,
        subject='Wallet first open',
        slug='wallet_first_open',
        samples=samples,
    )


@WALLET_BENCHMARK_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_wallet_repeat_open_loading_time(
    aut: AUT,
    main_screen,
    user_data,
    user_account,
    tmp_path,
):
    enable_benchmark_mode()
    samples = BenchmarkScenarioSamples()

    with step('Open Wallet once without measuring to warm the session'):
        main_screen.left_panel.open_wallet()

    for i in range(ITERATIONS):
        with step(f'Iteration {i + 1}: Open Communities portal'):
            main_screen.left_panel.open_communities_portal()

        with step(f'Iteration {i + 1}: Reopen Wallet and record metrics'):
            _record_monitored_wallet_open(aut, main_screen, samples)

    attach_scenario_reports(
        tmp_path,
        subject='Wallet repeat open',
        slug='wallet_repeat_open',
        samples=samples,
    )
