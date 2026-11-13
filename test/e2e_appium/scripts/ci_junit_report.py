#!/usr/bin/env python3
"""Turn a run's JUnit file into a job summary and one error annotation per failed test.

The summary and annotations are all a reader without a BrowserStack login can
see, so they name the APK under test and every failure with its message.
"""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

MAX_ANNOTATIONS = 50


@dataclass
class Failure:
    node_id: str
    message: str


@dataclass
class Result:
    total: int = 0
    failed: int = 0
    skipped: int = 0
    failures: list[Failure] = field(default_factory=list)

    @property
    def passed(self) -> int:
        return self.total - self.failed - self.skipped


def node_id(classname: str, name: str) -> str:
    parts = classname.split(".")
    module_end = next((i for i, part in enumerate(parts) if part.startswith("test_")), len(parts) - 1)
    path = "/".join(parts[: module_end + 1]) + ".py"
    return "::".join([path, *parts[module_end + 1 :], name])


def read_junit(path: Path) -> Result:
    root = ET.parse(path).getroot()
    suites = [root] if root.tag == "testsuite" else root.findall("testsuite")
    result = Result()
    for suite in suites:
        for case in suite.iter("testcase"):
            result.total += 1
            bad = case.find("failure")
            if bad is None:
                bad = case.find("error")
            if bad is not None:
                result.failed += 1
                message = (bad.get("message") or bad.text or "").strip().splitlines()
                result.failures.append(Failure(node_id(case.get("classname", ""), case.get("name", "")), message[0] if message else ""))
            elif case.find("skipped") is not None:
                result.skipped += 1
    return result


def _cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")[:300]


def render_summary(result: Result, app: dict, commit: str, app_from_this_commit: bool, account: str, build_url: str) -> str:
    verdict = "passed" if result.failed == 0 else "failed"
    lines = [
        f"## E2E Android {verdict}: {result.passed} passed, {result.failed} failed, {result.skipped} skipped",
        "",
        "| | |",
        "|---|---|",
        f"| APK | `{_cell(app.get('app_name', ''))}` (`{app.get('app_id', '')}`) |",
        f"| Uploaded | {app.get('uploaded_at', '')} |",
        f"| Tests from | `{commit}` |",
        f"| BrowserStack account | {account} |",
    ]
    if build_url:
        lines.append(f"| BrowserStack build | {build_url} |")
    if not app_from_this_commit:
        lines += [
            "",
            f"> The APK was given by app id, so it was not built from this commit (`{commit}`). "
            "A failure can come from a mismatch between the APK and the tests.",
        ]
    if result.failures:
        lines += ["", "### Failed tests", "", "| Test | Message |", "|---|---|"]
        lines += [f"| `{_cell(f.node_id)}` | {_cell(f.message)} |" for f in result.failures]
    return "\n".join(lines) + "\n"


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
    opts = parser.parse_args()

    result = read_junit(opts.junit)
    summary = render_summary(
        result,
        json.loads(opts.app_json or "{}"),
        opts.commit,
        opts.app_from_this_commit == "true",
        opts.account,
        opts.build_url,
    )
    with opts.summary.open("a") as handle:
        handle.write(summary)
    for failure in result.failures[:MAX_ANNOTATIONS]:
        print(annotation(failure.node_id, failure.message))
    return 0


if __name__ == "__main__":
    sys.exit(main())
