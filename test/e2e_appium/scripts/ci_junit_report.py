#!/usr/bin/env python3
"""Turn a run's JUnit file into a job summary and one error annotation per failed test.

The summary and annotations are all a reader without a BrowserStack login can
see, so they name the APK under test and every failure with its message.
"""

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

MAX_ANNOTATIONS = 50
RERUN_LINE = re.compile(r"\bRERUN (tests/\S+)")


@dataclass
class Failure:
    node_id: str
    message: str


@dataclass
class Skip:
    node_id: str
    reason: str


@dataclass
class Result:
    total: int = 0
    failed: int = 0
    skipped: int = 0
    failures: list[Failure] = field(default_factory=list)
    skips: list[Skip] = field(default_factory=list)
    passed_ids: set[str] = field(default_factory=set)

    @property
    def passed(self) -> int:
        return self.total - self.failed - self.skipped


def node_id(classname: str, name: str) -> str:
    parts = classname.split(".")
    # Classes are CamelCase and modules are not: the module is the part before the first class.
    module_end = max(next((i for i, part in enumerate(parts) if part[:1].isupper()), len(parts)) - 1, 0)
    path = "/".join(parts[: module_end + 1]) + ".py"
    return "::".join([path, *parts[module_end + 1 :], name])


def read_junit(path: Path) -> Result:
    root = ET.parse(path).getroot()
    suites = [root] if root.tag == "testsuite" else root.findall("testsuite")
    result = Result()
    for suite in suites:
        for case in suite.iter("testcase"):
            result.total += 1
            case_id = node_id(case.get("classname", ""), case.get("name", ""))
            bad = case.find("failure")
            if bad is None:
                bad = case.find("error")
            if bad is not None:
                result.failed += 1
                message = (bad.get("message") or bad.text or "").strip().splitlines()
                result.failures.append(Failure(case_id, message[0] if message else ""))
                continue
            skipped = case.find("skipped")
            if skipped is not None:
                result.skipped += 1
                reason = (skipped.get("message") or skipped.text or "").strip().splitlines()
                result.skips.append(Skip(case_id, reason[0] if reason else ""))
            else:
                result.passed_ids.add(case_id)
    return result


def read_reruns(log: Path | None) -> list[str]:
    """Node ids pytest reran, in first-seen order. The JUnit file keeps only the
    last try of a test, so reruns can only be read from pytest's own output."""
    if log is None or not log.is_file():
        return []
    seen: dict[str, None] = {}
    for line in log.read_text(errors="replace").splitlines():
        match = RERUN_LINE.search(line)
        if match:
            seen.setdefault(match.group(1))
    return list(seen)


def _cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")[:300]


def render_summary(
    result: Result,
    app: dict,
    commit: str,
    app_from_this_commit: bool,
    account: str,
    build_url: str,
    tests_outcome: str = "success",
    reruns: tuple[str, ...] | list[str] = (),
    behind_base: str = "",
) -> str:
    if result.total == 0:
        heading = "## E2E Android NOT RUN: no tests were selected"
    elif result.skipped == result.total:
        heading = f"## E2E Android NOT RUN: all {result.total} selected tests were skipped"
    elif result.failed == 0 and tests_outcome == "cancelled":
        # A cancelled step still writes results for the tests that finished.
        heading = f"## E2E Android incomplete: {result.passed} passed before the test step was cancelled"
    elif result.failed == 0 and tests_outcome != "success":
        # A step timeout and an error outside the tests both end as failure.
        heading = (
            f"## E2E Android error: {result.passed} passed and none failed, but the test step ended as "
            f"{tests_outcome} (a timeout, or an error outside the tests)"
        )
    else:
        verdict = "passed" if result.failed == 0 else "failed"
        heading = f"## E2E Android {verdict}: {result.passed} passed, {result.failed} failed, {result.skipped} skipped"
    lines = [
        heading,
        "",
        "| | |",
        "|---|---|",
        f"| APK | `{_cell(app.get('app_name', ''))}` (`{app.get('app_id', '')}`) |",
        f"| Uploaded | {app.get('uploaded_at', '')} |",
        f"| Tests from | `{commit}`{_behind(behind_base)} |",
        f"| BrowserStack account | {account} |",
    ]
    if build_url:
        lines.append(f"| BrowserStack build | {build_url} |")
    if not app_from_this_commit:
        lines += [
            "",
            f"> The APK was given by app id, so its commit could not be verified against this one (`{commit}`). "
            "A mismatch between the APK and the tests can cause failures.",
        ]
    if result.failures:
        lines += ["", "### Failed tests", "", "| Test | Message |", "|---|---|"]
        lines += [f"| `{_cell(f.node_id)}` | {_cell(f.message)} |" for f in result.failures]
    nonpassing_ids = {f.node_id for f in result.failures} | {s.node_id for s in result.skips}
    final_passes = result.passed_ids - nonpassing_ids
    passed_on_rerun = [node for node in reruns if node in final_passes]
    if passed_on_rerun:
        # A pass on the second try is still a pass, so it shows nowhere else.
        lines += ["", "### Passed on a rerun", ""]
        lines += [f"- `{_cell(node)}`" for node in passed_on_rerun]
    if result.skips:
        # A skip is silent in the verdict, so a reader must see what did not run and why.
        lines += ["", "### Skipped tests", "", "| Test | Reason |", "|---|---|"]
        lines += [f"| `{_cell(s.node_id)}` | {_cell(s.reason)} |" for s in result.skips]
    return "\n".join(lines) + "\n"


def _behind(behind_base: str) -> str:
    """`behind_base` is "<count> <branch>", or empty when it is not known."""
    count, _, branch = behind_base.partition(" ")
    if not count.isdigit() or not branch:
        return ""
    if count == "0":
        return f", up to date with `{_cell(branch)}`"
    return f", {count} commit{'' if count == '1' else 's'} behind `{_cell(branch)}`"


def _escape_data(text: str) -> str:
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def annotation(title: str, message: str) -> str:
    escaped_title = _escape_data(title).replace(":", "%3A").replace(",", "%2C")
    return f"::error title={escaped_title}::{_escape_data(message)}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--junit", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--app-json", default="{}")
    parser.add_argument("--commit", default="")
    parser.add_argument("--app-from-this-commit", default="false")
    parser.add_argument("--account", default="")
    parser.add_argument("--build-url", default="")
    parser.add_argument("--tests-outcome", default="success")
    parser.add_argument("--pytest-log", type=Path)
    parser.add_argument("--behind-base", default="")
    opts = parser.parse_args()

    result = read_junit(opts.junit)
    summary = render_summary(
        result,
        json.loads(opts.app_json or "{}"),
        opts.commit,
        opts.app_from_this_commit == "true",
        opts.account,
        opts.build_url,
        opts.tests_outcome,
        read_reruns(opts.pytest_log),
        opts.behind_base,
    )
    with opts.summary.open("a") as handle:
        handle.write(summary)
    for failure in result.failures[:MAX_ANNOTATIONS]:
        print(annotation(failure.node_id, failure.message))
    return 0


if __name__ == "__main__":
    sys.exit(main())
