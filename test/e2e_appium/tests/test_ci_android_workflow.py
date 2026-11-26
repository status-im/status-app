"""Device-free checks for Android workflow steps."""

import json
import os
import subprocess
from pathlib import Path

import pytest
import yaml

pytestmark = pytest.mark.component

ROOT = Path(__file__).resolve().parents[3]
WORKFLOW = ROOT / ".github" / "workflows" / "e2e-android.yml"
APP_ID = "bs://" + "a" * 40
EVENT_SHA = "b" * 40
PRODUCER_SHA = "c" * 40


@pytest.fixture(scope="module")
def jobs():
    return yaml.safe_load(WORKFLOW.read_text())["jobs"]


def run_step(tmp_path, jobs, job, name, **env):
    script = next(step["run"] for step in jobs[job]["steps"] if step.get("name") == name)
    output = tmp_path / "output"
    output.touch()
    result = subprocess.run(
        ["bash", "--noprofile", "--norc", "-eo", "pipefail", "-c", script],
        cwd=ROOT,
        env={"PATH": os.defpath, "GITHUB_OUTPUT": str(output), **env},
        capture_output=True,
        text=True,
        check=False,
    )
    return result, output.read_text().splitlines()


@pytest.mark.parametrize(
    ("app_id", "artifact", "producer", "ref"),
    [
        (APP_ID, "", "", EVENT_SHA),
        ("", "apk", PRODUCER_SHA, PRODUCER_SHA),
        ("", "apk", "", None),
        ("", "apk", PRODUCER_SHA[:7], None),
        ("", "apk", "refs/pull/123/merge", None),
        (APP_ID, "", PRODUCER_SHA, None),
    ],
)
def test_resolve_checkout_ref(tmp_path, jobs, app_id, artifact, producer, ref):
    result, outputs = run_step(
        tmp_path, jobs, "peer-image", "Check the app inputs",
        APP_ID_INPUT=app_id, APK_ARTIFACT=artifact, APK_PRODUCER_SHA=producer, EVENT_SHA=EVENT_SHA,
    )
    if ref is None:
        assert result.returncode == 1
        assert "apk-producer-sha" in result.stdout
        assert not outputs
    else:
        assert result.returncode == 0
        assert outputs == [f"ref={ref}"]


@pytest.mark.parametrize("job, role", [("peer-image", "peer"), ("e2e", "test")])
@pytest.mark.parametrize("matches", [True, False])
def test_verify_checkout(tmp_path, jobs, job, role, matches):
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    expected = actual if matches else "0" * 40
    result, outputs = run_step(tmp_path, jobs, job, f"Verify the {role} checkout", EXPECTED_REF=expected)
    assert result.returncode == (0 if matches else 1)
    assert outputs == ([f"sha={actual}"] if matches else [])
    if not matches:
        assert f"Checked out {actual}, expected {expected}." in result.stdout


@pytest.fixture
def app_lookup(tmp_path, jobs):
    curl = tmp_path / "curl"
    curl.write_text(
        r"""#!/bin/bash
set -eu
cat >/dev/null
if [[ "${!#}" =~ /recent_group_apps\?limit=100\&offset=([0-9]+)$ ]]; then
    offset="${BASH_REMATCH[1]}"
    echo "$offset" >> "$CALLS"
    if [[ -f "$PAGES/$offset.json" ]]; then
        cat "$PAGES/$offset.json"
        exit 0
    fi
    echo '{"message":"BrowserStack access denied"}'
fi
exit 22
"""
    )
    curl.chmod(0o755)

    def lookup(pages):
        for offset, page in pages.items():
            (tmp_path / f"{offset}.json").write_text(json.dumps(page))
        calls = tmp_path / "calls"
        result, outputs = run_step(
            tmp_path, jobs, "e2e", "Check the app is on the account",
            PATH=f"{tmp_path}:{os.defpath}", PAGES=str(tmp_path), CALLS=str(calls),
            APP_ID=APP_ID, ACCOUNT="1", BS_USER="fake-user", BS_KEY="fake-key",
        )
        return result, outputs, calls.read_text().splitlines()

    return lookup


def test_match_on_second_page(app_lookup):
    app = {"app_url": APP_ID, "app_name": "app.apk", "uploaded_at": "2026-11-24"}
    full_page = [{"app_url": f"bs://{i:040x}"} for i in range(100)]
    result, outputs, offsets = app_lookup({0: full_page, 100: [{"app_url": APP_ID + "0"}, app]})
    assert result.returncode == 0
    assert offsets == ["0", "100"]
    assert outputs[0] == f"app-id={APP_ID}"
    assert json.loads(outputs[1].removeprefix("app-json=")) == {
        "app_id": APP_ID, "app_name": "app.apk", "uploaded_at": "2026-11-24",
    }


@pytest.mark.parametrize("last_page", [[], [{"app_url": APP_ID + "0"}], {"message": "No results found"}])
def test_exhausted_pages(app_lookup, last_page):
    full_page = [{"app_url": f"bs://{i:040x}"} for i in range(100)]
    result, outputs, offsets = app_lookup({0: full_page, 100: last_page})
    assert (result.returncode, outputs, offsets) == (1, [], ["0", "100"])
    assert "is not among recent uploads" in result.stdout


@pytest.mark.parametrize(
    ("pages", "error"),
    [
        ({}, "BrowserStack could not list apps"),
        ({0: {"message": "unexpected"}}, "Unexpected answer from BrowserStack"),
    ],
)
def test_lookup_errors_are_not_reported_as_missing_apps(app_lookup, pages, error):
    result, outputs, offsets = app_lookup(pages)
    assert (result.returncode, outputs, offsets) == (1, [], ["0"])
    assert error in result.stdout
    if not pages:
        assert "BrowserStack access denied" in result.stdout


@pytest.fixture
def session_cleanup(tmp_path, jobs):
    curl = tmp_path / "curl"
    curl.write_text(
        """#!/bin/bash
set -eu
cat >/dev/null
case "${!#}" in
    */builds.json*)
        echo '[{"automation_build":{"name":"e2e-run-identifier","hashed_id":"build"}}]'
        ;;
    */builds/build/sessions.json*)
        echo list >> "$CALLS"
        attempt=$(grep -c '^list$' "$CALLS")
        cat "$PAGES/$attempt.json" 2>/dev/null || exit 22
        ;;
    */wd/hub/session/session-1)
        [[ " $* " == *" --request DELETE "* ]]
        echo stop >> "$CALLS"
        ;;
    *) exit 22 ;;
esac
"""
    )
    curl.chmod(0o755)
    sleep = tmp_path / "sleep"
    sleep.write_text("#!/bin/bash\nexit 0\n")
    sleep.chmod(0o755)

    def cleanup(*pages):
        for attempt, page in enumerate(pages, start=1):
            if page is not None:
                (tmp_path / f"{attempt}.json").write_text(json.dumps(page))
        calls = tmp_path / "calls"
        result, _ = run_step(
            tmp_path, jobs, "e2e", "Find the BrowserStack build and stop its leftover sessions",
            PATH=f"{tmp_path}:{os.defpath}", PAGES=str(tmp_path), CALLS=str(calls),
            BROWSERSTACK_BUILD_IDENTIFIER="identifier", BS_USER="fake-user", BS_KEY="fake-key",
        )
        return result, calls.read_text().splitlines()

    return cleanup


RUNNING = [{"automation_session": {"status": "running", "hashed_id": "session-1"}}]


def test_cleanup_retries_before_stopping_leftover_sessions(session_cleanup):
    result, calls = session_cleanup(None, {}, RUNNING, [])
    assert result.returncode == 0
    assert calls == ["list", "list", "list", "stop", "list"]
    assert "Sessions still running after the stop: 0" in result.stdout


@pytest.mark.parametrize("after_stop", [False, True])
def test_cleanup_warns_when_the_remaining_sessions_are_unknown(session_cleanup, after_stop):
    result, calls = session_cleanup(*([RUNNING] if after_stop else []))
    assert result.returncode == 0
    assert calls == (["list", "stop"] if after_stop else []) + ["list"] * 3
    assert "::warning::" in result.stdout
    assert "remaining sessions are unknown" in result.stdout
    assert "Sessions still running after the stop: 0" not in result.stdout
