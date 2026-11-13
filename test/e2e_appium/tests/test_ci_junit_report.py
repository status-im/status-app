"""The CI report is all a triager without a BrowserStack login gets to see."""

import pytest

from scripts.ci_junit_report import annotation, read_junit, render_summary

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


def test_summary_names_the_apk_and_warns_it_is_not_this_commit(junit):
    text = render_summary(read_junit(junit), APP, commit="0c1b85ece52", app_from_this_commit=False, account="1", build_url="")
    assert APP["app_name"] in text
    assert "2026-11-10 15:56:55 UTC" in text
    assert "not built from this commit" in text
    assert "`0c1b85ece52`" in text


def test_summary_omits_the_warning_for_an_apk_built_in_this_run(junit):
    text = render_summary(read_junit(junit), APP, commit="abc", app_from_this_commit=True, account="1", build_url="")
    assert "not built from this commit" not in text


def test_summary_lists_every_failure(junit):
    text = render_summary(read_junit(junit), APP, commit="abc", app_from_this_commit=True, account="1", build_url="")
    assert "tests/messaging/test_a.py::TestA::test_bad[device_0]" in text
    assert "TimeoutError: no session" in text
    assert text.splitlines()[0].startswith("## ")
    assert "2 failed" in text.splitlines()[0]


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
