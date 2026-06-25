import logging
import os

import pytest
import allure
from allure_commons.types import AttachmentType
from allure_commons._allure import step

import configs
from configs import get_platform
import constants

LOG = logging.getLogger(__name__)


@pytest.mark.parametrize('user_data, user_account', [
    pytest.param(configs.testpath.TEST_USER_DATA / 'status_community_member', constants.user.status_community_member),
])
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_status_community_first_open_loading_time(main_screen, user_data, user_account, tmp_path):
    os.environ['STATUS_RUNTIME_TEST_MODE'] = 'True'  # to omit banners

    with step('Open Status community after login and record first open load time'):
        _, load_time = main_screen.left_panel.open_community_and_record_load_time('Status')

    report_lines = []
    line = f"[1/1] Status community first open load time: {load_time:.3f} seconds"
    report_lines.append(line)
    LOG.info(line)

    average_line = f"Average Status community first open load time over 1 runs: {load_time:.3f} seconds"
    LOG.info(average_line)

    report_lines.append(average_line)
    report_text = "\n".join(report_lines)
    report_file = tmp_path / "status_community_first_open_load_times.txt"
    report_file.write_text(report_text, encoding="utf-8")

    with step('Attach Status community first open load times to Allure'):
        allure.attach(report_text, name='Status community first open load times (text)', attachment_type=AttachmentType.TEXT)
        allure.attach.file(str(report_file), name='Status community first open load times (file)', attachment_type=AttachmentType.TEXT)


@pytest.mark.parametrize('user_data, user_account', [
    pytest.param(configs.testpath.TEST_USER_DATA / 'status_community_member', constants.user.status_community_member),
])
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_status_community_second_open_loading_time(main_screen, user_data, user_account, tmp_path):
    os.environ['STATUS_RUNTIME_TEST_MODE'] = 'True'  # to omit banners

    with step('Open Status community after login'):
        main_screen.left_panel.open_community('Status')

    load_times = []
    report_lines = []

    for i in range(5):
        with step(f'Iteration {i + 1}: Open Communities portal'):
            main_screen.left_panel.open_communities_portal()

        with step(f'Iteration {i + 1}: Open Status community again and record load time'):
            _, load_time = main_screen.left_panel.open_community_and_record_load_time('Status')
            load_times.append(load_time)
            line = f"[{i + 1}/5] Status community second open load time: {load_time:.3f} seconds"
            report_lines.append(line)
            LOG.info(line)

    average_time = sum(load_times) / len(load_times) if load_times else 0.0
    average_line = f"Average Status community second open load time over {len(load_times)} runs: {average_time:.3f} seconds"
    LOG.info(average_line)

    report_lines.append(average_line)
    report_text = "\n".join(report_lines)
    report_file = tmp_path / "status_community_second_open_load_times.txt"
    report_file.write_text(report_text, encoding="utf-8")

    with step('Attach Status community second open load times to Allure'):
        allure.attach(report_text, name='Status community second open load times (text)', attachment_type=AttachmentType.TEXT)
        allure.attach.file(str(report_file), name='Status community second open load times (file)', attachment_type=AttachmentType.TEXT)
