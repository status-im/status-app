#!/usr/bin/env python3
"""Build the pytest arguments for a CI run from workflow inputs.

Workflow inputs are untrusted text. Checking them here, and handing the result
to the shell NUL-separated, means no input is ever parsed as shell or reaches
pytest as an option.
"""

import argparse
import configparser
import re
import sys
from pathlib import Path

import yaml

SELECTIONS = {
    "gate": ["-m", "(gate and not two_phone) or backend_peer", "tests"],
    "smoke": ["-m", "smoke", "tests"],
}
WORKERS = {"1", "2", "3", "4", "5"}
# The gate has only one-phone tests, so 4 workers leave one session spare.
# Other selections can hold two- and three-phone tests: 2 workers fit 5 sessions.
AUTO_WORKERS_GATE = "4"
AUTO_WORKERS_OTHER = "2"
NODE_ID = re.compile(r"^tests/[A-Za-z0-9_./\[\]:-]+$")
MARKER_TOKEN = re.compile(r"[()]|[^\s()]+")
MARKER_OPERATORS = {"and", "or", "not", "(", ")"}
BROWSERSTACK_CONFIG = Path(__file__).resolve().parents[1] / "config" / "environments" / "browserstack.yaml"
PYTEST_INI = Path(__file__).resolve().parents[1] / "pytest.ini"


def marker_args(markers: str, known_markers: set[str]) -> list[str]:
    tokens = MARKER_TOKEN.findall(markers)
    if not tokens:
        raise ValueError("markers is empty")
    depth = 0
    for token in tokens:
        if token not in MARKER_OPERATORS and token not in known_markers:
            raise ValueError(f"not a marker or and/or/not: {token!r}; markers are {sorted(known_markers)}")
        depth += {"(": 1, ")": -1}.get(token, 0)
        if depth < 0:
            raise ValueError(f"unbalanced parentheses in {markers!r}")
    if depth:
        raise ValueError(f"unbalanced parentheses in {markers!r}")
    return ["-m", " ".join(markers.split()), "tests"]


def build_args(
    selection: str,
    workers: str,
    device: str,
    tests: str,
    known_devices: set[str],
    markers: str = "",
    known_markers: set[str] = frozenset(),
) -> list[str]:
    if selection not in SELECTIONS:
        raise ValueError(f"unknown selection {selection!r}; expected one of {sorted(SELECTIONS)}")
    if workers not in WORKERS | {"auto"}:
        raise ValueError(f"workers must be auto or 1 to 5, got {workers!r}")
    if device and device not in known_devices:
        raise ValueError(f"unknown device {device!r}; expected one of {sorted(known_devices)}")

    node_ids = tests.split()
    for node_id in node_ids:
        if not NODE_ID.match(node_id) or ".." in node_id.split("::")[0].split("/"):
            raise ValueError(f"not a test node id under tests/: {node_id!r}")

    if node_ids and markers.strip():
        raise ValueError("give tests or markers, not both")

    if node_ids:
        selected = node_ids
    elif markers.strip():
        selected = marker_args(markers, known_markers)
    else:
        selected = SELECTIONS[selection]
    if workers == "auto":
        only_gate = selection == "gate" and not node_ids and not markers.strip()
        workers = AUTO_WORKERS_GATE if only_gate else AUTO_WORKERS_OTHER
    return [*selected, "-n", workers, "--env", "browserstack"]


def android_devices(path: Path = BROWSERSTACK_CONFIG) -> list[str]:
    """Android devices in config order. Entries without the android tag, such as
    the iOS devices and the regex-matched dynamic tablet, are not offered."""
    config = yaml.safe_load(path.read_text())
    return [entry["id"] for entry in config["devices"]["matrix"] if "android" in entry.get("tags", [])]


def known_devices(path: Path = BROWSERSTACK_CONFIG) -> set[str]:
    return set(android_devices(path))


def known_markers(path: Path = PYTEST_INI) -> set[str]:
    config = configparser.ConfigParser(interpolation=None)
    config.read(path)
    lines = config["pytest"]["markers"].strip().splitlines()
    return {re.split(r"[:(]", line, maxsplit=1)[0].strip() for line in lines if line.strip()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--selection", required=True)
    parser.add_argument("--workers", required=True)
    parser.add_argument("--device", default="")
    parser.add_argument("--tests", default="")
    parser.add_argument("--markers", default="")
    opts = parser.parse_args()
    try:
        args = build_args(
            opts.selection, opts.workers, opts.device, opts.tests, known_devices(), opts.markers, known_markers()
        )
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 2
    sys.stdout.write("".join(f"{arg}\0" for arg in args))
    return 0


if __name__ == "__main__":
    sys.exit(main())
