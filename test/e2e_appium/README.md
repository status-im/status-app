# E2E Testing Framework

Automated end-to-end testing for the Status mobile app using Appium, on BrowserStack or a local device.

## Quick Start

### 1. Setup
```bash
cd test/e2e_appium
pip install -r requirements.txt
```

### 2. Run on BrowserStack from GitHub Actions
See [GitHub Actions](#github-actions) below.

## A headless status-backend as a chat participant

`core/backend_peer.py` drives a headless `status-backend` through status-go's own
test client, as a chat participant that is not a phone. It runs as a container
the client starts and stops, from an image named after the status-go commit this
checkout vendors; `core/peer_containers.py` refuses an image built from any other
commit. The tests marked `backend_peer` need only Docker: two peers exchange a
message on the real fleet, and five peers run side by side.

```bash
# from the repo root, with docker running
export STATUS_BACKEND_DOCKER_PROJECT=peer-local
IMAGE=$(test/e2e_appium/scripts/peer_image.sh "$STATUS_BACKEND_DOCKER_PROJECT")

cd test/e2e_appium
pip install -r requirements.txt -r requirements-backend-peer.txt
STATUS_BACKEND_IMAGE="$IMAGE" pytest -m backend_peer tests
```

The first build takes several minutes; after that the image is already on the
host and the script only looks it up. Without `STATUS_BACKEND_IMAGE` the tests
are skipped. On Docker Desktop the script finds the daemon through the docker
context but the test client reads only `DOCKER_HOST`, so set it first:

```bash
export DOCKER_HOST=$(docker context inspect -f '{{.Endpoints.docker.Host}}')
```

Peer container logs are written to `logs/backend_peer/` for CI artifact
collection. All peers created in one pytest process must use the same fleet
because the status-go client's `Config` is process-global.

## Test Selection

**By markers:**
```bash
pytest -m smoke          # Core functionality
pytest -m onboarding     # User registration flow
pytest -m critical       # Essential features
pytest -m performance    # Performance validation tests
```

**Specific tests:**
```bash
# Run onboarding tests with fixture
pytest tests/test_onboarding_flow.py::TestOnboardingFlow::test_complete_onboarding_flow_with_fixture

# (Legacy examples removed for v1)

# Run tests that depend on onboarding
pytest tests/test_onboarding_dependent_features.py
```

## Local Testing

```bash
# Setup local environment
python scripts/local_setup.py

# Run tests with local APK
export LOCAL_APP_PATH="/path/to/Status.apk"
pytest -m onboarding --env=local -v
```

## GitHub Actions

`.github/workflows/e2e-android.yml` runs the lane on BrowserStack with a
status-backend peer. It is advisory and QA-owned: do not make its check
required, because a run in a repository without BrowserStack secrets ends as
skipped (its summary says NOT RUN).

**By hand:** Actions > E2E Android > Run workflow, with a `bs://` app id that a
user in the account's BrowserStack group uploaded. Pick a branch whose
`test/e2e_appium` matches the APK: an app id can be up to 30 days older or
newer than the branch, and the summary warns when the APK was not built from
the tested commit.

**From a workflow that built an APK:**

```yaml
e2e:
  needs: apk
  uses: ./.github/workflows/e2e-android.yml
  with: { apk-artifact: <artifact with one APK>, account: '1' }
  secrets: inherit
```

The APK must be built with `STATUSQ_TESTMODE=true`, or the e2e hooks are
compiled out. Release APKs cannot run the suite.

**On pull requests, opt in with a label.** The PR workflow that builds the APK
runs this one only when the PR has the `e2e-android` label:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, labeled]

concurrency:
  # A run for any other label gets a group of its own, so it cancels nothing.
  group: ${{ github.event.action == 'labeled' && github.event.label.name != 'e2e-android' && github.run_id || format('android-{0}', github.ref) }}
  cancel-in-progress: true

jobs:
  apk:
    # Any label sends a labeled event. Only this one needs a new build.
    if: github.event.action != 'labeled' || github.event.label.name == 'e2e-android'
    # builds the APK and uploads it as the artifact "apk"
  e2e:
    needs: apk
    if: contains(github.event.pull_request.labels.*.name, 'e2e-android')
    uses: ./.github/workflows/e2e-android.yml
    with: { apk-artifact: apk, account: '1' }
    secrets: inherit
```

- Without the label, the e2e job is skipped and nothing reaches BrowserStack.
- Other labels skip every job and do not cancel a build in progress.
- Adding the label reruns the PR workflow, so the tests run against an APK
  built from that PR. Every later push runs them again until the label is
  removed.
- PRs from forks get no secrets, so their run ends as NOT RUN.
- Runs on the same account queue one at a time.
- If the PR workflow sets `cancel-in-progress: true`, a push cancels the e2e
  run in progress along with the rest of that workflow. Its leftover
  BrowserStack sessions are still stopped.

**Inputs:** `selection` (`gate` or `smoke`), or `tests` (node ids under
`tests/`), or `markers` (an expression of marker names from `pytest.ini`);
`device` (Android ids from `config/environments/browserstack.yaml`); `workers`
(`auto` is 4 for the gate, which leaves one of the account's 5 sessions spare,
and 2 when multi-phone tests can be selected); `account` (`1` or `2`).

**Queueing:** one run per BrowserStack account per repository at a time. The
queue never cancels a run in progress, though a calling workflow's own
`cancel-in-progress` can; GitHub keeps one waiting run per account, so a
newer waiting run replaces an older one. Queues are per repository, and a
BrowserStack group's 5 sessions are shared by every user in it, so runs from
two repositories on the same group do not see each other. The harness's
capacity check is then the only guard. Apps are visible only inside the group
that uploaded them.

**Secrets:** `BROWSERSTACK_USERNAME` and `BROWSERSTACK_ACCESS_KEY` for account
1, and the same names with `_2` for account 2.

**Peer image:** `.github/workflows/e2e-peer-image.yml` publishes
`ghcr.io/<owner>/status-app-e2e-peer:<status-go commit>` from the default
branch. An e2e run pulls it, or builds it (about 7 to 10 minutes) when the
vendored status-go has no published image yet or GHCR cannot be reached. A
built image is handed to the e2e job as an artifact kept for 4 days.

**Results:** the job summary names the APK, its upload date, the tested
commit and every failed test with its message, and each failure is an error
annotation. Reports, logs and screenshots are in the `e2e-android-reports-*`
artifact for 14 days.

## Onboarding Fixture

The framework includes a reusable onboarding fixture that eliminates code duplication:

```python
# Simple usage - fixture handles complete onboarding
def test_my_feature(self, onboarded_user):
    user_data = onboarded_user['user_data']
    assert onboarded_user['success']
    # Test your feature here

# Advanced usage with custom configuration  
@pytest.mark.onboarding_config(custom_display_name="MyUser")
def test_with_custom_onboarding(self, onboarded_user):
    assert onboarded_user['user_data']['display_name'] == "MyUser"
```

📖 **[Quick Guide: Using Onboarding Fixtures](docs/USING_ONBOARDING_FIXTURES.md)**  
📖 **[Complete Onboarding Fixture Documentation](docs/ONBOARDING_FIXTURE.md)**

## Environment Configuration

### For BrowserStack
```bash
export BROWSERSTACK_USERNAME=...
export BROWSERSTACK_ACCESS_KEY=...
export BROWSERSTACK_APP_ID=bs://...
pytest -m gate --env=browserstack
```

### For Local Testing
```bash
export LOCAL_APP_PATH="/path/to/Status.apk"
export CURRENT_TEST_ENVIRONMENT="local"
```

## Troubleshooting

**BrowserStack runs:**
- "not in BrowserStack account N's group": the app was deleted after 30 days or uploaded to another group. Upload it again.
- Many "message not visible" or login failures at once: check the summary's APK warning; the tests probably do not match the APK.
- "Re-run failed jobs" fails to download the peer image: the artifact expired after 4 days. Re-run all jobs.
- "incomplete" in the summary heading: the test step was cancelled. "error" with no failed tests: the step timed out, or pytest exited with an error outside the tests.

**Local Testing Issues:**
- Ensure Appium server running: `appium`
- Verify Android emulator running with correct device name
- Check LOCAL_APP_PATH points to valid APK file

## Framework Structure

```
test/e2e_appium/
├── tests/              # Test files
├── pages/              # Page object models
├── config/             # Configuration files
├── scripts/            # Automation and setup scripts
├── docs/               # Documentation
└── .github/actions/    # Reusable workflow actions
```

## Contributing

- **[Contributing Guide](CONTRIBUTING.md)** - Complete guide for new contributors
- **[Framework Architecture](docs/FRAMEWORK_ARCHITECTURE.md)** - Technical design and patterns
- **[Code Guidelines](docs/CODE_GUIDELINES.md)** - Coding standards and best practices

## Documentation

### Getting Started
- **[Quick Start Guide](docs/QUICK_START.md)** - 5-minute setup
- **[Local Setup Guide](docs/LOCAL_SETUP.md)** - Detailed development setup
- **[Environment Management](docs/ENVIRONMENT_MANAGEMENT.md)** - Configuration system

### Workflow & CI/CD
- **[Workflow Quick Reference](docs/WORKFLOW_QUICKREF.md)** - GitHub Actions reference
- **[GitHub Actions Guide](docs/github-actions.md)** - CI/CD workflows
- **[Test Reporting](docs/REPORTING_RESULTS.md)** - Understanding results

### Framework Usage
- **[Using Onboarding Fixtures](docs/USING_ONBOARDING_FIXTURES.md)** - Fixture patterns
- **[Onboarding Fixture Documentation](docs/ONBOARDING_FIXTURE.md)** - Detailed fixture guide
- **[Logging Guide](docs/LOGGING.md)** - Logging system

### Reference
- **[Framework Architecture](docs/FRAMEWORK_ARCHITECTURE.md)** - Technical architecture
- **[Code Guidelines](docs/CODE_GUIDELINES.md)** - Development standards 