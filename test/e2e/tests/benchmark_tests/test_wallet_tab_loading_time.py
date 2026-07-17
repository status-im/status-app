import pytest
from allure_commons._allure import step

from configs import get_platform
from driver.aut import AUT
from gui.screens.wallet import WalletAccountView
from helpers.wallet_helper import wait_for_account_assets_loaded
from scripts.utils.benchmark_report import (
    BenchmarkScenarioSamples,
    attach_scenario_reports,
    enable_benchmark_mode,
    monitored_timed_call,
)
from tests.benchmark_tests.benchmark_helpers import BENCHMARK_USER_PARAMS, WALLET_BENCHMARK_PARAMS

ITERATIONS = 5
WALLET_BENCHMARK_USERS = pytest.mark.parametrize(
    'user_data, user_account',
    WALLET_BENCHMARK_PARAMS,
    **BENCHMARK_USER_PARAMS,
)


def _wallet_account_view(main_screen) -> WalletAccountView:
    main_screen.left_panel.open_wallet()
    return WalletAccountView().wait_until_appears()


def _open_assets_loaded(wallet_account_view: WalletAccountView) -> WalletAccountView:
    wallet_account_view.open_assets_tab()
    wait_for_account_assets_loaded(wallet_account_view, open_tab=False)
    return wallet_account_view


def _run_tab_benchmark(
    aut: AUT,
    tmp_path,
    *,
    open_tab,
    leave_tab,
    subject: str,
    slug: str,
    record_first_open: bool = False,
) -> None:
    first_open_samples = BenchmarkScenarioSamples()
    repeat_open_samples = BenchmarkScenarioSamples()
    if record_first_open:
        _, load_time, stats = monitored_timed_call(aut, open_tab)
        first_open_samples.record(load_time, stats)
    else:
        open_tab()

    for _ in range(ITERATIONS):
        leave_tab()
        _, load_time, stats = monitored_timed_call(aut, open_tab)
        repeat_open_samples.record(load_time, stats)

    if record_first_open:
        attach_scenario_reports(
            tmp_path,
            subject=f'{subject} first open',
            slug=f'{slug}_first_open',
            samples=first_open_samples,
        )
    attach_scenario_reports(
        tmp_path,
        subject=f'{subject} reopen',
        slug=slug,
        samples=repeat_open_samples,
    )


@WALLET_BENCHMARK_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_wallet_assets_tab_loading_time(
    aut: AUT,
    main_screen,
    user_data,
    user_account,
    tmp_path,
):
    enable_benchmark_mode()
    wallet_account_view = _wallet_account_view(main_screen)
    with step('Measure repeat Assets tab opening'):
        _run_tab_benchmark(
            aut,
            tmp_path,
            open_tab=lambda: _open_assets_loaded(wallet_account_view),
            leave_tab=lambda: wallet_account_view.open_collectibles_tab(
                wait_until_loaded=False
            ),
            subject='Wallet Assets tab',
            slug='wallet_assets_tab',
        )


@WALLET_BENCHMARK_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_wallet_collectibles_tab_loading_time(
    aut: AUT,
    main_screen,
    user_data,
    user_account,
    tmp_path,
):
    enable_benchmark_mode()
    wallet_account_view = _wallet_account_view(main_screen)
    with step('Measure first and repeat Collectibles tab opening'):
        _run_tab_benchmark(
            aut,
            tmp_path,
            open_tab=wallet_account_view.open_collectibles_tab,
            leave_tab=wallet_account_view.open_assets_tab,
            subject='Wallet Collectibles tab',
            slug='wallet_collectibles_tab',
            record_first_open=True,
        )


@WALLET_BENCHMARK_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_wallet_activity_tab_loading_time(
    aut: AUT,
    main_screen,
    user_data,
    user_account,
    tmp_path,
):
    enable_benchmark_mode()
    wallet_account_view = _wallet_account_view(main_screen)
    with step('Measure first and repeat History tab opening'):
        _run_tab_benchmark(
            aut,
            tmp_path,
            open_tab=wallet_account_view.open_activity_tab,
            leave_tab=wallet_account_view.open_assets_tab,
            subject='Wallet History tab',
            slug='wallet_activity_tab',
            record_first_open=True,
        )
