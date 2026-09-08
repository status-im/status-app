# E2E Testing Framework

Automated end-to-end testing for Status Desktop using Appium and LambdaTest.

## Quick Start

### 1. Setup
```bash
cd test/e2e_appium
pip install -r requirements.txt
```

### 2. Configure LambdaTest (GitHub Secrets)
Repository administrators need to set:
- `LT_USERNAME` - Your LambdaTest username
- `LT_ACCESS_KEY` - Your LambdaTest access key

### 3. Run Tests via GitHub Actions
1. Build APK using `android-build.yml` workflow (architecture: `x86_64`)
2. Run tests using `e2e-appium-android.yml` workflow
3. Use artifact name: `Status-x86_64`

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

## GitHub Actions Workflows

### Build APK Workflow
- **File**: `android-build.yml`
- **Architecture**: `x86_64` (required for LambdaTest)
- **Output**: `Status-x86_64` artifact

### E2E Testing Workflow
- **File**: `e2e-appium-android.yml`
- **APK source**: GitHub artifact (default)
- **Test target**: `onboarding` (default)
- **Device**: Galaxy Tab S8 (default)

## Workflow Input Options

### APK Sources
- **GitHub artifacts**: `Status-x86_64` (recommended)
- **Direct URLs**: `https://example.com/app.apk`
- **LambdaTest IDs**: `lt://APP123456789`

### Device Options
- **default**: Galaxy Tab S8 (Android 14)
- **pixel_tablet**: Google Pixel Tablet
- **galaxy_tab_a**: Samsung Galaxy Tab A

### Test Targets
- **onboarding**: Complete user onboarding flow
- **smoke**: Quick critical functionality tests
- **critical**: Essential features that must pass

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

### For LambdaTest (Cloud)
```bash
# Set in GitHub repository secrets
LT_USERNAME=your_username
LT_ACCESS_KEY=your_access_key
```

### For Local Testing
```bash
export LOCAL_APP_PATH="/path/to/Status.apk"
export CURRENT_TEST_ENVIRONMENT="local"
```

## Troubleshooting

**APK Build Issues:**
- Verify x86_64 architecture selected in android-build.yml
- Check build workflow completed successfully

**Test Execution Issues:**
- Verify LambdaTest credentials in repository secrets
- Check APK artifact name matches exactly: `Status-x86_64`
- Review workflow logs for detailed error messages

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