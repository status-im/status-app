"""The CI argument builder must refuse anything that could reach pytest as an option."""

import subprocess
import sys
from pathlib import Path

import pytest

from scripts.ci_pytest_args import build_args

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "ci_pytest_args.py"
KNOWN = {"pixel_8_android_14", "galaxy_tab_s10p_android_15"}
MARKERS = {"gate", "smoke", "two_phone", "backend_peer", "messaging", "wallet"}
GATE = "(gate and not two_phone) or backend_peer"
TAIL = ["-n", "4", "--env", "browserstack"]

pytestmark = pytest.mark.component


def test_gate_default():
    assert build_args("gate", "4", "", "", KNOWN) == ["-m", GATE, "tests", *TAIL]


def test_smoke():
    assert build_args("smoke", "4", "", "", KNOWN)[:3] == ["-m", "smoke", "tests"]


def test_tests_replace_selection():
    args = build_args("gate", "4", "", "tests/test_a.py::T::test_x tests/b.py", KNOWN)
    assert args == ["tests/test_a.py::T::test_x", "tests/b.py", *TAIL]


def test_parametrised_node_id_allowed():
    args = build_args("gate", "4", "", "tests/test_a.py::test_x[pixel-1]", KNOWN)
    assert args[0] == "tests/test_a.py::test_x[pixel-1]"


@pytest.mark.parametrize("tests", ["-p evil", "--env=x", "tests/a.py --rootdir=/"])
def test_rejects_option_in_tests(tests):
    with pytest.raises(ValueError):
        build_args("gate", "4", "", tests, KNOWN)


@pytest.mark.parametrize("tests", ["tests/a.py;id", "tests/$(id).py", "tests/`id`.py"])
def test_rejects_shell_metachars(tests):
    with pytest.raises(ValueError):
        build_args("gate", "4", "", tests, KNOWN)


@pytest.mark.parametrize("tests", ["../x.py", "/etc/passwd", "tests/../../x"])
def test_rejects_path_outside_tests(tests):
    with pytest.raises(ValueError):
        build_args("gate", "4", "", tests, KNOWN)


@pytest.mark.parametrize("workers", ["0", "6", "x", ""])
def test_workers_out_of_range(workers):
    with pytest.raises(ValueError):
        build_args("gate", workers, "", "", KNOWN)


@pytest.mark.parametrize("workers", ["1", "2", "3", "4", "5"])
def test_workers_in_range(workers):
    assert build_args("gate", workers, "", "", KNOWN)[-3] == workers


def test_unknown_device():
    with pytest.raises(ValueError):
        build_args("gate", "4", "pixel_99", "", KNOWN)


def test_known_device_ok():
    build_args("gate", "4", "pixel_8_android_14", "", KNOWN)


def test_unknown_selection():
    with pytest.raises(ValueError):
        build_args("nightly", "4", "", "", KNOWN)


def test_markers_replace_selection():
    args = build_args("gate", "4", "", "", KNOWN, "two_phone and  messaging", MARKERS)
    assert args == ["-m", "two_phone and messaging", "tests", *TAIL]


def test_markers_with_parentheses_and_not():
    args = build_args("gate", "4", "", "", KNOWN, "(smoke or gate) and not two_phone", MARKERS)
    assert args[:2] == ["-m", "(smoke or gate) and not two_phone"]


def test_tests_and_markers_together_rejected():
    with pytest.raises(ValueError):
        build_args("gate", "4", "", "tests/a.py", KNOWN, "smoke", MARKERS)


@pytest.mark.parametrize(
    "markers",
    ["unknown_marker", "smoke --rootdir=/", "-p evil", "smoke; id", "smoke and $(id)", "smoke`id`", "smoke == 1"],
)
def test_rejects_unknown_marker_tokens(markers):
    with pytest.raises(ValueError):
        build_args("gate", "4", "", "", KNOWN, markers, MARKERS)


@pytest.mark.parametrize("markers", ["(smoke", "smoke)", ")smoke("])
def test_rejects_unbalanced_parentheses(markers):
    with pytest.raises(ValueError):
        build_args("gate", "4", "", "", KNOWN, markers, MARKERS)


def test_blank_markers_keep_selection():
    assert build_args("smoke", "4", "", "", KNOWN, "   ", MARKERS)[:3] == ["-m", "smoke", "tests"]


def _cli(*extra):
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--selection", "gate", "--workers", "4", *extra],
        capture_output=True,
        text=True,
    )


def test_cli_nul_output():
    out = _cli("--device", "", "--tests", "")
    assert out.returncode == 0, out.stderr
    assert out.stdout.split("\0")[:-1] == ["-m", GATE, "tests", *TAIL]


def test_cli_reads_devices_from_browserstack_config():
    assert _cli("--device", "pixel_8_android_14", "--tests", "").returncode == 0


def test_cli_exit_2_on_bad_input():
    out = _cli("--device", "", "--tests", "-p evil")
    assert out.returncode == 2
    assert out.stdout == ""
    assert out.stderr.strip()


def test_cli_reads_markers_from_pytest_ini():
    out = _cli("--markers", "two_phone and messaging")
    assert out.returncode == 0, out.stderr
    assert out.stdout.split("\0")[:3] == ["-m", "two_phone and messaging", "tests"]


def test_cli_exit_2_on_unknown_marker():
    assert _cli("--markers", "not_a_marker").returncode == 2


@pytest.mark.parametrize(
    "selection, tests, markers, expected",
    [
        ("gate", "", "", "4"),
        ("smoke", "", "", "2"),
        ("gate", "tests/test_a.py", "", "2"),
        ("gate", "", "two_phone and messaging", "2"),
    ],
)
def test_auto_workers_leave_a_spare_session(selection, tests, markers, expected):
    args = build_args(selection, "auto", "", tests, KNOWN, markers, MARKERS)
    assert args[args.index("-n") + 1] == expected


def test_only_android_devices_are_offered():
    from scripts.ci_pytest_args import android_devices

    devices = android_devices()
    assert "pixel_8_android_14" in devices
    assert not [d for d in devices if "ios" in d or d.startswith("dynamic_")]


def _dispatch_inputs():
    import yaml

    workflow = Path(__file__).resolve().parents[3] / ".github" / "workflows" / "e2e-android.yml"
    loaded = yaml.safe_load(workflow.read_text())
    triggers = loaded.get("on", loaded.get(True))
    return triggers["workflow_dispatch"]["inputs"]


def test_workflow_device_menu_matches_the_config():
    from scripts.ci_pytest_args import android_devices

    assert _dispatch_inputs()["device"]["options"] == ["default", *android_devices()]


def test_workflow_workers_default_to_auto():
    workers = _dispatch_inputs()["workers"]
    assert workers["default"] == "auto"
    assert workers["options"] == ["auto", "1", "2", "3", "4", "5"]


@pytest.mark.parametrize(
    "markers",
    ["smoke and", "smoke smoke", "()", "and smoke", "smoke not wallet", "not", "(smoke) (wallet)", "smoke or ()"],
)
def test_rejects_malformed_marker_expressions(markers):
    with pytest.raises(ValueError):
        build_args("gate", "4", "", "", KNOWN, markers, MARKERS)


@pytest.mark.parametrize(
    "markers",
    ["smoke", "not smoke", "smoke and not wallet", "(smoke or wallet) and not two_phone", "not (smoke and wallet)"],
)
def test_accepts_well_formed_marker_expressions(markers):
    assert build_args("gate", "4", "", "", KNOWN, markers, MARKERS)[:2] == ["-m", markers]


def test_node_id_with_an_image_digest_is_allowed():
    node_id = "tests/test_backend_peer_core.py::test_every_reference_form_of_the_built_image_is_accepted[statusgo-peer-27bca1fc5ce8@sha256:aaaa]"
    assert build_args("gate", "4", "", node_id, KNOWN)[0] == node_id
