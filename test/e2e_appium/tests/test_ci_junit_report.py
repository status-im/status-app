"""The CI report is all a triager without a BrowserStack login gets to see."""

import pytest

from scripts.ci_junit_report import annotation, node_id, read_junit, read_reruns, render_summary

pytestmark = pytest.mark.component

JUNIT = """<?xml version="1.0" encoding="utf-8"?>
<testsuites><testsuite name="pytest" tests="4" failures="1" errors="1" skipped="1" time="12.5">
<testcase classname="tests.messaging.test_a.TestA" name="test_ok" time="1"/>
<testcase classname="tests.messaging.test_a.TestA" name="test_bad[device_0]" time="2">
  <failure message="AssertionError: Message not visible after sending: x_1&#10;second line">trace</failure>
</testcase>
<testcase classname="tests.test_b" name="test_err" time="3"><error message="TimeoutError: no session">trace</error></testcase>
<testcase classname="tests.test_b" name="test_skip" time="0"><skipped message="needs peer"/></testcase>
</testsuite></testsuites>"""

APP = {
    "app_id": "bs://abc",
    "app_name": "StatusIm-Desktop-261110-033800-f4a17a-arm64.apk",
    "uploaded_at": "2026-11-10 15:56:55 UTC",
}


@pytest.fixture
def junit(tmp_path):
    path = tmp_path / "results.xml"
    path.write_text(JUNIT)
    return path


def test_counts(junit):
    result = read_junit(junit)
    assert (result.total, result.passed, result.failed, result.skipped) == (4, 1, 2, 1)


def test_failures_carry_node_id_and_first_message_line(junit):
    failures = read_junit(junit).failures
    assert [f.node_id for f in failures] == [
        "tests/messaging/test_a.py::TestA::test_bad[device_0]",
        "tests/test_b.py::test_err",
    ]
    assert failures[0].message == "AssertionError: Message not visible after sending: x_1"


def test_summary_names_the_apk_and_warns_its_commit_is_unverified(junit):
    text = render_summary(read_junit(junit), APP, commit="0c1b85ece52", app_from_this_commit=False, account="1", build_url="")
    assert APP["app_name"] in text
    assert "2026-11-10 15:56:55 UTC" in text
    assert "could not be verified" in text
    assert "`0c1b85ece52`" in text


def test_summary_omits_the_warning_for_an_apk_built_in_this_run(junit):
    text = render_summary(read_junit(junit), APP, commit="abc", app_from_this_commit=True, account="1", build_url="")
    assert "could not be verified" not in text


def test_summary_lists_every_failure(junit):
    text = render_summary(read_junit(junit), APP, commit="abc", app_from_this_commit=True, account="1", build_url="")
    assert "tests/messaging/test_a.py::TestA::test_bad[device_0]" in text
    assert "TimeoutError: no session" in text
    assert text.splitlines()[0].startswith("## ")
    assert "2 failed" in text.splitlines()[0]


def test_summary_lists_every_skip_with_its_reason(junit):
    text = render_summary(read_junit(junit), APP, commit="abc", app_from_this_commit=True, account="1", build_url="")
    assert "### Skipped tests" in text
    assert "| `tests/test_b.py::test_skip` | needs peer |" in text


def test_summary_has_no_skipped_section_without_skips(tmp_path):
    path = tmp_path / "r.xml"
    path.write_text(PASSING)
    text = render_summary(read_junit(path), APP, commit="abc", app_from_this_commit=True, account="1", build_url="")
    assert "Skipped tests" not in text


@pytest.mark.parametrize(
    "classname, expected",
    [
        ("tests.test_suites.test_a.TestA", "tests/test_suites/test_a.py::TestA::test_x"),
        ("tests.b.TestB", "tests/b.py::TestB::test_x"),
        ("tests.test_a.TestA.TestInner", "tests/test_a.py::TestA::TestInner::test_x"),
        ("tests.messaging.test_a", "tests/messaging/test_a.py::test_x"),
    ],
)
def test_node_id_splits_the_module_from_the_first_class(classname, expected):
    assert node_id(classname, "test_x") == expected


def test_summary_links_the_browserstack_build(junit):
    url = "https://app-automate.browserstack.com/dashboard/v2/builds/c92a"
    text = render_summary(read_junit(junit), APP, commit="abc", app_from_this_commit=True, account="1", build_url=url)
    assert url in text


def test_summary_escapes_table_breaking_characters(tmp_path):
    path = tmp_path / "r.xml"
    path.write_text(JUNIT.replace("Message not visible", "a | b"))
    text = render_summary(read_junit(path), APP, commit="abc", app_from_this_commit=True, account="1", build_url="")
    assert "a \\| b" in text


def test_annotation_escapes_workflow_command_characters():
    line = annotation("tests/a.py::test_x[a,b:c]", "50% done\nnext")
    assert line == "::error title=tests/a.py%3A%3Atest_x[a%2Cb%3Ac]::50%25 done%0Anext"


def test_testsuite_root_without_testsuites(tmp_path):
    path = tmp_path / "r.xml"
    path.write_text('<testsuite tests="1" failures="0" errors="0" skipped="0"><testcase classname="tests.test_c" name="t"/></testsuite>')
    assert read_junit(path).passed == 1


def test_zero_tests_is_not_run_not_passed(tmp_path):
    path = tmp_path / "r.xml"
    path.write_text('<testsuites><testsuite tests="0" failures="0" errors="0" skipped="0"/></testsuites>')
    text = render_summary(read_junit(path), APP, commit="abc", app_from_this_commit=True, account="1", build_url="")
    assert text.splitlines()[0] == "## E2E Android NOT RUN: no tests were selected"
    assert "passed" not in text.splitlines()[0]


PASSING = '<testsuite tests="2" failures="0" errors="0" skipped="0"><testcase classname="tests.test_c" name="a"/><testcase classname="tests.test_c" name="b"/></testsuite>'


def test_passes_from_a_cancelled_test_step_are_incomplete(tmp_path):
    path = tmp_path / "r.xml"
    path.write_text(PASSING)
    text = render_summary(read_junit(path), APP, "abc", True, "1", "", tests_outcome="cancelled")
    assert text.splitlines()[0] == "## E2E Android incomplete: 2 passed before the test step was cancelled"


def test_passes_from_a_failed_test_step_are_an_error_not_incomplete(tmp_path):
    path = tmp_path / "r.xml"
    path.write_text(PASSING)
    heading = render_summary(read_junit(path), APP, "abc", True, "1", "", tests_outcome="failure").splitlines()[0]
    assert heading == (
        "## E2E Android error: 2 passed and none failed, but the test step ended as failure "
        "(a timeout, or an error outside the tests)"
    )
    assert "incomplete" not in heading


def test_passes_from_a_successful_test_step_are_passed(tmp_path):
    path = tmp_path / "r.xml"
    path.write_text(PASSING)
    text = render_summary(read_junit(path), APP, "abc", True, "1", "", tests_outcome="success")
    assert text.splitlines()[0].startswith("## E2E Android passed: 2 passed")


def test_failures_stay_failed_whatever_the_outcome(junit):
    text = render_summary(read_junit(junit), APP, "abc", True, "1", "", tests_outcome="cancelled")
    assert text.splitlines()[0].startswith("## E2E Android failed:")


def test_all_skipped_is_not_run(tmp_path):
    path = tmp_path / "r.xml"
    path.write_text('<testsuite tests="1" failures="0" errors="0" skipped="1"><testcase classname="tests.test_c" name="a"><skipped/></testcase></testsuite>')
    text = render_summary(read_junit(path), APP, "abc", True, "1", "")
    assert text.splitlines()[0] == "## E2E Android NOT RUN: all 1 selected tests were skipped"


PYTEST_LOG = """\
[gw1] [ 53%] RERUN tests/test_onboarding_import_seed.py::TestOnboardingImportSeed::test_import_seed_phrase
[gw1] [ 55%] PASSED tests/test_onboarding_import_seed.py::TestOnboardingImportSeed::test_import_seed_phrase
[gw0] [ 60%] RERUN tests/messaging/test_a.py::TestA::test_bad[device_0]
[gw0] [ 61%] RERUN tests/messaging/test_a.py::TestA::test_bad[device_0]
[gw0] [ 62%] FAILED tests/messaging/test_a.py::TestA::test_bad[device_0]
=================== 59 passed, 1 failed, 3 rerun in 1102.37s ===================
"""


def test_reruns_are_read_once_each_from_the_pytest_log(tmp_path):
    log = tmp_path / "pytest.log"
    log.write_text(PYTEST_LOG)
    assert read_reruns(log) == [
        "tests/test_onboarding_import_seed.py::TestOnboardingImportSeed::test_import_seed_phrase",
        "tests/messaging/test_a.py::TestA::test_bad[device_0]",
    ]


def test_a_missing_pytest_log_gives_no_reruns(tmp_path):
    assert read_reruns(None) == []
    assert read_reruns(tmp_path / "absent.log") == []


def test_summary_lists_only_the_reruns_that_passed(junit, tmp_path):
    junit.write_text(
        JUNIT.replace(
            'tests="4"',
            'tests="5"',
        ).replace(
            "</testsuite>",
            '<testcase classname="tests.test_onboarding_import_seed.TestOnboardingImportSeed" '
            'name="test_import_seed_phrase"/></testsuite>',
        )
    )
    log = tmp_path / "pytest.log"
    log.write_text(
        PYTEST_LOG
        + "[gw0] [ 62%] RERUN tests/test_b.py::test_skip\n"
        + "[gw1] [ 62%] RERUN tests/test_b.py::test_err\n"
        + "[gw1] [ 62%] RERUN tests/test_b.py::test_unfinished\n"
    )
    text = render_summary(read_junit(junit), APP, "abc", True, "1", "", reruns=read_reruns(log))
    section = text.split("### Passed on a rerun")[1].split("###")[0]
    assert "test_import_seed_phrase" in section
    assert "test_bad" not in section
    assert "test_skip" not in section
    assert "test_err" not in section
    assert "test_unfinished" not in section


def test_summary_has_no_rerun_section_without_reruns(junit):
    assert "Passed on a rerun" not in render_summary(read_junit(junit), APP, "abc", True, "1", "")


@pytest.mark.parametrize(
    "behind_base, expected",
    [
        ("0 master", "| Tests from | `abc`, up to date with `master` |"),
        ("1 master", "| Tests from | `abc`, 1 commit behind `master` |"),
        ("12 release/2.39", "| Tests from | `abc`, 12 commits behind `release/2.39` |"),
        ("", "| Tests from | `abc` |"),
        ("unknown master", "| Tests from | `abc` |"),
        ("3", "| Tests from | `abc` |"),
    ],
)
def test_summary_says_how_far_the_tested_commit_is_behind_its_base(junit, behind_base, expected):
    text = render_summary(read_junit(junit), APP, "abc", True, "1", "", behind_base=behind_base)
    assert expected in text
