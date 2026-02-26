import logging
import os
import time

import pytest
import allure
from allure_commons.types import AttachmentType
from allure_commons._allure import step

import configs
from configs import get_platform
import constants
from constants.dock_buttons import DockButtons
LOG = logging.getLogger(__name__)


@pytest.mark.parametrize('user_data, user_account', [
    pytest.param(configs.testpath.TEST_USER_DATA / 'wallet_load', constants.user.wallet_load, id='wallet_load_user'),
    pytest.param(configs.testpath.TEST_USER_DATA / 'wallet_load_alex', constants.user.wallet_load_alex,
                 id='wallet_load_alex_user')
])
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_wallet_loading_time(main_screen, user_data, user_account, tmp_path):
    os.environ['STATUS_RUNTIME_TEST_MODE'] = 'True'  # to omit banners

    with step('Open wallet after login'):
        main_screen.left_panel.open_wallet()

    load_times = []
    report_lines = []

    for i in range(5):
        with step(f'Iteration {i + 1}: Open Communities portal'):
            main_screen.left_panel.open_communities_portal()

        with step(f'Iteration {i + 1}: Open wallet tab again and record load time'):
            wallet_screen, load_time = main_screen.left_panel.open_wallet_and_record_load_time()
            load_times.append(load_time)
            line = f"[{i + 1}/5] Wallet load time: {load_time:.3f} seconds"
            report_lines.append(line)
            print(line)
            LOG.info(line)

    average_time = sum(load_times) / len(load_times) if load_times else 0.0
    average_line = f"Average wallet load time over {len(load_times)} runs: {average_time:.3f} seconds"
    print(average_line)
    LOG.info(average_line)

    # Write timings to a text file and attach to Allure
    report_lines.append(average_line)
    report_text = "\n".join(report_lines)
    report_file = tmp_path / "wallet_load_times.txt"
    report_file.write_text(report_text, encoding="utf-8")

    with step('Attach wallet load times to Allure'):
        allure.attach(report_text, name='Wallet load times (text)', attachment_type=AttachmentType.TEXT)
        allure.attach.file(str(report_file), name='Wallet load times (file)', attachment_type=AttachmentType.TEXT)

