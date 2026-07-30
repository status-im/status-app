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
from tests.benchmark_tests.benchmark_helpers import (
    BENCHMARK_USER_PARAMS,
    COMMUNITY_MEMBER_BENCHMARK_PARAMS as _COMMUNITY_MEMBER_PARAM_VALUES,
)

COMMUNITY_NAME = 'Status'
SECOND_OPEN_ITERATIONS = 5

COMMUNITY_MEMBER_BENCHMARK_PARAMS = pytest.mark.parametrize(
    'user_data, user_account',
    _COMMUNITY_MEMBER_PARAM_VALUES,
    **BENCHMARK_USER_PARAMS,
)


def _record_monitored_community_open(aut: AUT, main_screen, samples: BenchmarkScenarioSamples) -> None:
    """Shared by first-open and second-open community benchmark tests (load, CPU, RAM)."""
    (_, load_time), stats = monitored_call(
        aut,
        lambda: main_screen.left_panel.open_community_and_record_load_time(COMMUNITY_NAME),
    )
    samples.record(load_time, stats)


@COMMUNITY_MEMBER_BENCHMARK_PARAMS
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_status_community_first_open_loading_time(
    aut: AUT, main_screen, user_data, user_account, tmp_path,
):
    enable_benchmark_mode()
    samples = BenchmarkScenarioSamples()

    with step('Open Status community after login and record first open load time'):
        _record_monitored_community_open(aut, main_screen, samples)

    attach_scenario_reports(
        tmp_path,
        subject='Status community first open',
        slug='status_community_first_open',
        samples=samples,
    )


@COMMUNITY_MEMBER_BENCHMARK_PARAMS
@pytest.mark.skipif(get_platform() != 'Windows', reason="Windows only test")
@pytest.mark.benchmark
def test_status_community_second_open_loading_time(
    aut: AUT, main_screen, user_data, user_account, tmp_path,
):
    enable_benchmark_mode()
    samples = BenchmarkScenarioSamples()

    with step('Open Status community after login'):
        main_screen.left_panel.open_community(COMMUNITY_NAME)

    for iteration in range(1, SECOND_OPEN_ITERATIONS + 1):
        with step(f'Iteration {iteration}: Open Communities portal'):
            main_screen.left_panel.open_communities_portal()

        with step(f'Iteration {iteration}: Open Status community again and record load time'):
            _record_monitored_community_open(aut, main_screen, samples)

    attach_scenario_reports(
        tmp_path,
        subject='Status community second open',
        slug='status_community_second_open',
        samples=samples,
    )
