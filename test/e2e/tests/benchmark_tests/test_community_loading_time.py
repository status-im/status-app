import pytest
from allure_commons._allure import step

import configs
from configs import get_platform
import constants
from driver.aut import AUT
from scripts.utils.benchmark_report import (
    CommunityOpenSamples,
    attach_community_scenario_reports,
    enable_benchmark_mode,
    monitored_call,
)

COMMUNITY_NAME = 'Status'
SECOND_OPEN_ITERATIONS = 5

COMMUNITY_BENCHMARK_PARAMS = pytest.mark.parametrize(
    'user_data, user_account',
    [pytest.param(
        configs.testpath.TEST_USER_DATA / 'status_community_member',
        constants.user.status_community_member,
    )],
)


def _record_monitored_community_open(aut: AUT, main_screen, samples: CommunityOpenSamples) -> None:
    load_time, stats = monitored_call(
        aut.pid,
        lambda: main_screen.left_panel.open_community_and_record_load_time(COMMUNITY_NAME),
    )
    samples.record(load_time, stats)


@COMMUNITY_BENCHMARK_PARAMS
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_status_community_first_open_loading_time(
    aut: AUT, main_screen, user_data, user_account, tmp_path,
):
    enable_benchmark_mode()
    samples = CommunityOpenSamples()

    with step('Open Status community after login and record first open load time'):
        _record_monitored_community_open(aut, main_screen, samples)

    attach_community_scenario_reports(tmp_path, 'first open', samples)


@COMMUNITY_BENCHMARK_PARAMS
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_status_community_second_open_loading_time(
    aut: AUT, main_screen, user_data, user_account, tmp_path,
):
    enable_benchmark_mode()
    samples = CommunityOpenSamples()

    with step('Open Status community after login'):
        main_screen.left_panel.open_community(COMMUNITY_NAME)

    for iteration in range(1, SECOND_OPEN_ITERATIONS + 1):
        with step(f'Iteration {iteration}: Open Communities portal'):
            main_screen.left_panel.open_communities_portal()

        with step(f'Iteration {iteration}: Open Status community again and record load time'):
            _record_monitored_community_open(aut, main_screen, samples)

    attach_community_scenario_reports(tmp_path, 'second open', samples)
