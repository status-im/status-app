"""The workflow's first step picks the BrowserStack account; a wrong pick runs on keys the app is not on."""

import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

pytestmark = pytest.mark.component

WORKFLOW = Path(__file__).resolve().parents[3] / ".github" / "workflows" / "e2e-android.yml"


def pick(tmp_path, account, pr="", artifact="", ready_1="true", ready_2="true"):
    script = yaml.safe_load(WORKFLOW.read_text())["jobs"]["credentials"]["steps"][0]["run"]
    output = tmp_path / "output"
    output.touch()
    env = {
        "PATH": "/usr/bin:/bin",
        "ACCOUNT_INPUT": account,
        "PR_NUMBER": pr,
        "APK_ARTIFACT": artifact,
        "READY_1": ready_1,
        "READY_2": ready_2,
        "GITHUB_OUTPUT": str(output),
        "GITHUB_STEP_SUMMARY": str(tmp_path / "summary"),
    }
    done = subprocess.run(
        [shutil.which("bash"), "--noprofile", "--norc", "-eo", "pipefail", "-c", script],
        env=env, capture_output=True, text=True, check=False,
    )
    outputs = dict(line.split("=", 1) for line in output.read_text().split())
    return done.returncode, outputs.get("account"), outputs.get("ready")


@pytest.mark.parametrize(
    "account, pr, artifact, ready_1, ready_2, expected",
    [
        ("1", "", "", "true", "true", ("1", "true")),
        ("2", "", "", "true", "false", ("2", "false")),
        ("auto", "", "", "true", "true", ("1", "true")),
        ("auto", "23159", "apk", "true", "true", ("1", "true")),
        ("auto", "23160", "apk", "true", "true", ("2", "true")),
        ("auto", "08", "apk", "true", "true", ("2", "true")),
        ("auto", "23160", "", "true", "true", ("1", "true")),
        ("auto", "23160", "apk", "true", "false", ("1", "true")),
        ("auto", "23159", "apk", "false", "true", ("2", "true")),
        ("auto", "23159", "apk", "false", "false", ("1", "false")),
    ],
    ids=[
        "account 1 named",
        "account 2 named without secrets is not run",
        "auto without a pull request",
        "auto, odd pull request",
        "auto, even pull request",
        "auto, a leading zero is not octal",
        "auto with an app id stays on account 1",
        "auto, only account 1 has secrets",
        "auto, only account 2 has secrets",
        "auto, no secrets is not run",
    ],
)
def test_account_choice(tmp_path, account, pr, artifact, ready_1, ready_2, expected):
    assert pick(tmp_path, account, pr, artifact, ready_1, ready_2) == (0, *expected)


@pytest.mark.parametrize("account", ["3", "", "auto; echo x", "1 2"])
def test_unknown_account_fails_without_an_output(tmp_path, account):
    assert pick(tmp_path, account) == (1, None, None)


def test_the_e2e_job_queues_on_the_picked_account_without_cancelling():
    concurrency = yaml.safe_load(WORKFLOW.read_text())["jobs"]["e2e"]["concurrency"]
    assert concurrency == {
        "group": "e2e-android-bs-account-${{ needs.credentials.outputs.account }}",
        "cancel-in-progress": False,
        "queue": "max",
    }
