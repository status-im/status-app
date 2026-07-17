import pytest
from allure_commons._allure import step

from configs import get_platform
from driver.aut import AUT
from gui.screens.wallet import WalletAccountView
from scripts.utils.benchmark_report import (
    BenchmarkScenarioSamples,
    attach_scenario_reports,
    enable_benchmark_mode,
    monitored_timed_call,
)
from tests.benchmark_tests.benchmark_helpers import (
    BENCHMARK_USER_PARAMS,
    WALLET_ACCOUNT_BENCHMARK_PARAMS,
    WALLET_BENCHMARK_PARAMS,
)

ITERATIONS = 5
WALLET_BENCHMARK_USERS = pytest.mark.parametrize(
    'user_data, user_account',
    WALLET_BENCHMARK_PARAMS,
    **BENCHMARK_USER_PARAMS,
)
WALLET_ACCOUNT_BENCHMARK_USERS = pytest.mark.parametrize(
    'user_data, user_account, account_name',
    WALLET_ACCOUNT_BENCHMARK_PARAMS,
    **BENCHMARK_USER_PARAMS,
)


def _record_modal_open_samples(
    aut: AUT,
    action,
    first_open_samples: BenchmarkScenarioSamples,
    repeat_open_samples: BenchmarkScenarioSamples,
) -> None:
    first_popup, load_time, stats = monitored_timed_call(aut, action)
    first_open_samples.record(load_time, stats)
    first_popup.close()

    for _ in range(ITERATIONS):
        popup, load_time, stats = monitored_timed_call(aut, action)
        repeat_open_samples.record(load_time, stats)
        popup.close()


def _run_modal_benchmark(
    aut: AUT,
    tmp_path,
    action,
    *,
    subject: str,
    slug: str,
) -> None:
    first_open_samples = BenchmarkScenarioSamples()
    repeat_open_samples = BenchmarkScenarioSamples()
    _record_modal_open_samples(
        aut,
        action,
        first_open_samples,
        repeat_open_samples,
    )
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


def _wallet_account_view(main_screen) -> WalletAccountView:
    main_screen.left_panel.open_wallet()
    return WalletAccountView().wait_until_appears()


def _select_wallet_account(main_screen, account_name: str) -> WalletAccountView:
    wallet = main_screen.left_panel.open_wallet()
    wallet.left_panel.open_all_accounts(account_name)
    return wallet.left_panel.select_account(account_name)


def _open_send_ready(wallet_account_view: WalletAccountView):
    popup = wallet_account_view.open_send_popup()
    popup.send_modal_title.wait_until_appears()
    assert popup.send_modal_title.text == 'Send'
    return popup


def _open_receive_ready(wallet_account_view: WalletAccountView):
    popup = wallet_account_view.open_receive_popup()
    popup.qr_code.wait_until_appears()
    return popup


def _open_add_account_ready(wallet_left_panel):
    popup = wallet_left_panel.open_add_account_popup()
    return popup.verify_add_account_popup_present()


@WALLET_BENCHMARK_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_wallet_send_loading_time(aut: AUT, main_screen, user_data, user_account, tmp_path):
    enable_benchmark_mode()
    wallet_account_view = _wallet_account_view(main_screen)
    with step('Measure first and repeat Send modal opening'):
        _run_modal_benchmark(
            aut,
            tmp_path,
            lambda: _open_send_ready(wallet_account_view),
            subject='Wallet Send modal',
            slug='wallet_send',
        )


@WALLET_ACCOUNT_BENCHMARK_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_wallet_receive_loading_time(
    aut: AUT,
    main_screen,
    user_data,
    user_account,
    account_name,
    tmp_path,
):
    enable_benchmark_mode()
    with step(f'Select {account_name} before opening Receive'):
        wallet_account_view = _select_wallet_account(main_screen, account_name)
    with step('Measure first and repeat Receive modal opening'):
        _run_modal_benchmark(
            aut,
            tmp_path,
            lambda: _open_receive_ready(wallet_account_view),
            subject='Wallet Receive modal',
            slug='wallet_receive',
        )


@WALLET_BENCHMARK_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_wallet_swap_loading_time(aut: AUT, main_screen, user_data, user_account, tmp_path):
    enable_benchmark_mode()
    wallet_account_view = _wallet_account_view(main_screen)
    with step('Measure first and repeat Swap modal opening'):
        _run_modal_benchmark(
            aut,
            tmp_path,
            wallet_account_view.open_swap_popup,
            subject='Wallet Swap modal',
            slug='wallet_swap',
        )


@WALLET_BENCHMARK_USERS
@pytest.mark.skipif(get_platform() != 'Windows', reason='Windows only test')
@pytest.mark.benchmark
def test_wallet_add_account_loading_time(
    aut: AUT,
    main_screen,
    user_data,
    user_account,
    tmp_path,
):
    enable_benchmark_mode()
    wallet_left_panel = main_screen.left_panel.open_wallet().left_panel
    with step('Measure first and repeat Add account modal opening'):
        _run_modal_benchmark(
            aut,
            tmp_path,
            lambda: _open_add_account_ready(wallet_left_panel),
            subject='Wallet Add account modal',
            slug='wallet_add_account',
        )
