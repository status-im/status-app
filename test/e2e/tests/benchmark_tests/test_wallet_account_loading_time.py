import pytest
from allure_commons._allure import step

from configs import get_platform
from driver.aut import AUT
from scripts.utils.benchmark_report import (
    BenchmarkScenarioSamples,
    attach_scenario_reports,
    enable_benchmark_mode,
    monitored_timed_call,
)
from tests.benchmark_tests.benchmark_helpers import (
    BENCHMARK_USER_PARAMS,
    WALLET_ACCOUNT_BENCHMARK_PARAMS,
)


@pytest.mark.parametrize(
    'user_data, user_account, account_name',
    WALLET_ACCOUNT_BENCHMARK_PARAMS,
    **BENCHMARK_USER_PARAMS,
)
@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_wallet_account_open_loading_time(
    aut: AUT,
    main_screen,
    user_data,
    user_account,
    account_name,
    tmp_path,
):
    enable_benchmark_mode()
    samples = BenchmarkScenarioSamples()
    wallet_left_panel = main_screen.left_panel.open_wallet().left_panel

    with step(f'Open {account_name} for the first time and record metrics'):
        wallet_left_panel.open_all_accounts(account_name)
        _, load_time, stats = monitored_timed_call(
            aut,
            lambda: wallet_left_panel.select_account(account_name),
        )
        samples.record(load_time, stats)

    attach_scenario_reports(
        tmp_path,
        subject='Wallet account first open',
        slug='wallet_account_first_open',
        samples=samples,
    )
