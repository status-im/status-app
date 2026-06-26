import pytest
from allure_commons._allure import step

import configs
from configs import get_platform
import constants
from gui.screens.wallet import WalletAccountView
from scripts.utils.benchmark_report import attach_load_time_report, enable_benchmark_mode

ITERATIONS = 5


@pytest.mark.parametrize('user_data, user_account', [
    pytest.param(configs.testpath.TEST_USER_DATA / 'wallet_load', constants.user.wallet_load, id='wallet_load_user'),
    pytest.param(configs.testpath.TEST_USER_DATA / 'wallet_load_alex', constants.user.wallet_load_alex,
                 id='wallet_load_alex_user')
])
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_swap_loading_time(main_screen, user_data, user_account, tmp_path):
    enable_benchmark_mode()

    with step('Open wallet after login'):
        main_screen.left_panel.open_wallet()

    with step('Get wallet account view'):
        wallet_account_view = WalletAccountView().wait_until_appears()

    load_times = []
    for i in range(ITERATIONS):
        with step(f'Iteration {i + 1}: Open Swap modal and record load time'):
            swap_popup, load_time = wallet_account_view.open_swap_popup_and_record_load_time()
            load_times.append(load_time)

        with step(f'Iteration {i + 1}: Close Swap modal'):
            swap_popup.close()

    attach_load_time_report(
        tmp_path,
        attachment_prefix='Swap modal load times',
        line_subject='Swap modal load time',
        filename='swap_load_times.txt',
        load_times=load_times,
    )
