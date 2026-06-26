import pytest
from allure_commons._allure import step

import configs
from configs import get_platform
import constants
from scripts.utils.benchmark_report import attach_load_time_report, enable_benchmark_mode

ITERATIONS = 5


@pytest.mark.parametrize('user_data, user_account', [
    pytest.param(configs.testpath.TEST_USER_DATA / 'wallet_load', constants.user.wallet_load, id='wallet_load_user'),
    pytest.param(configs.testpath.TEST_USER_DATA / 'wallet_load_alex', constants.user.wallet_load_alex,
                 id='wallet_load_alex_user')
])
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_wallet_loading_time(main_screen, user_data, user_account, tmp_path):
    enable_benchmark_mode()

    with step('Open wallet after login'):
        main_screen.left_panel.open_wallet()

    load_times = []
    for i in range(ITERATIONS):
        with step(f'Iteration {i + 1}: Open Communities portal'):
            main_screen.left_panel.open_communities_portal()

        with step(f'Iteration {i + 1}: Open wallet tab again and record load time'):
            _, load_time = main_screen.left_panel.open_wallet_and_record_load_time()
            load_times.append(load_time)

    attach_load_time_report(
        tmp_path,
        attachment_prefix='Wallet load times',
        line_subject='Wallet load time',
        filename='wallet_load_times.txt',
        load_times=load_times,
    )
