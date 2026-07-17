import pytest
from allure_commons._allure import step

from configs import get_platform
from driver.aut import AUT
from gui.screens.wallet import WalletAccountView
from scripts.utils.benchmark_report import (
    BenchmarkScenarioSamples,
    attach_scenario_reports,
    enable_benchmark_mode,
    monitored_call,
)
from tests.benchmark_tests.benchmark_helpers import BENCHMARK_USER_PARAMS, WALLET_BENCHMARK_PARAMS

ITERATIONS = 5


@pytest.mark.parametrize('user_data, user_account', WALLET_BENCHMARK_PARAMS, **BENCHMARK_USER_PARAMS)
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_swap_loading_time(aut: AUT, main_screen, user_data, user_account, tmp_path):
    enable_benchmark_mode()
    samples = BenchmarkScenarioSamples()

    with step('Open wallet after login'):
        main_screen.left_panel.open_wallet()

    with step('Get wallet account view'):
        wallet_account_view = WalletAccountView().wait_until_appears()

    for i in range(ITERATIONS):
        with step(f'Iteration {i + 1}: Open Swap modal and record load time'):
            (swap_popup, load_time), stats = monitored_call(
                aut,
                wallet_account_view.open_swap_popup_and_record_load_time,
            )
            samples.record(load_time, stats)

        with step(f'Iteration {i + 1}: Close Swap modal'):
            swap_popup.close()

    attach_scenario_reports(
        tmp_path,
        subject='Swap modal',
        slug='swap',
        samples=samples,
    )
