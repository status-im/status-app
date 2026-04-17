# This repository manages UI tests for desktop application

## How to set up your environment

1. **MacOS**: https://www.notion.so/Mac-arch-x64-and-Intel-50ea48dae1d4481b882afdbfad38e95a
2. **Linux**: https://www.notion.so/Linux-21f7abd2bb684a0fb10057848760a889
3. **Windows**: https://www.notion.so/Windows-fbccd2b09b784b32ba4174233d83878d

## Local Waku fleet (Linux)

Use this when you want e2e to run the app against a **local nwaku** stack instead of production `status.prod`.

### Prerequisites

- Docker Engine and Compose v2 (`docker compose`), your user in the `docker` group (or use `sudo` for Docker).
- Tests resolve the fleet config from the **repository root** (`status-app/`), not only from `test/e2e`. Run pytest from `test/e2e` as usual so paths in [driver/aut.py](driver/aut.py) stay correct.

### 1. Start the local fleet

From the **Status app repository root** (parent of `test/`):

```bash
docker compose -f ./docker-compose.waku.yml up --build --remove-orphans
```

Leave this running. The compose file uses host networking on Linux (`network_mode: host`).

### 2. Environment variables for pytest

The AUT is started with local Waku flags only if **`E2E_LOCAL_WAKU_FLEET`** is set to a truthy value (`1`, `true`, or `yes`).

| Variable | Role |
|----------|------|
| `E2E_LOCAL_WAKU_FLEET` | Must be enabled (`1` / `true` / `yes`) to pass `--enable-fleet-selection`, `--waku-fleet`, and `--waku-fleets-config` to the binary. |
| `STATUS_FLEET` | Optional. Defaults to `status-app.test`. **Must match the top-level key** in [assets/local-waku-fleets-config.json](../../assets/local-waku-fleets-config.json). |
| `STATUS_FLEET_CONFIG_FILE` | Set automatically by the test driver to the absolute path of `assets/local-waku-fleets-config.json` when local fleet mode is on (same information as CLI; status-go may use either). |

Example before running tests:

```bash
export E2E_LOCAL_WAKU_FLEET=1
# Optional if you use the default fleet name from the JSON:
# export STATUS_FLEET=status-app.test
```

Without `E2E_LOCAL_WAKU_FLEET`, the app uses the normal built-in fleets (e.g. `status.prod`) and does **not** load `local-waku-fleets-config.json`.

### 3. Logs

With local fleet enabled, pytest logs the full argv via `AUT startaut argv (...)`. Check `aut.log` next to your `AUT_PATH` binary and application logs under the per-run data directory if something fails (e.g. `unknown fleet` means the saved account fleet does not match the keys in the JSON).

### 4. CI

The Linux e2e Jenkins job sets `E2E_LOCAL_WAKU_FLEET`, `STATUS_FLEET`, and `STATUS_FLEET_CONFIG_FILE` in [ci/Jenkinsfile.tests-e2e](../../ci/Jenkinsfile.tests-e2e).

## Which build to use

1. you _can_ use your local dev build but sometimes tests hag there. To use it, just place a path to the executable to AUT_PATH in your _local.py config,
for example `AUT_PATH = "/Users/anastasiya/status-desktop/bin/nim_status_client"`

2. normally, please use CI build. Grab recent one from Jenkins job https://ci.status.im/job/status-desktop/job/nightly/

    **2.1** Linux and Windows could be taken from nightly job
    ![img.png](img.png)

3. **Note:** on windows you have to escape slashes and use the bin from StatusApp folder:
for example `"C:\\Users\\anast\\AppData\\Local\\StatusApp\\bin\\Status.exe"

    **2.2** Mac **requires entitlements**  for Squish which we don't add by default, so please go here https://ci.status.im/job/status-desktop/job/systems/job/macos/
and select architecture you need (arm or intel), click Build with parameters and select Squish entitlements. Select a branch if u like (master is default)
    ![img_1.png](img_1.png)

## Pytest marks used

You can run tests by mark, just use it like this in command line:

```bash
python3 -m pytest -m critical
```

or directly in pycharm terminal:

```bash
pytest -m critical
```

You can obtain the list of all marks we have by running this `pytest --markers`

- `critical`, mark used to select the most important checks we do for PRs in desktop repository 
(the same for our repo PRs)
- `skip`, used to just skip tests for various reasons, normally with a ticket linked
- `timeout(timeout=180, method="thread")`, to catch excessively long test durations like deadlocked or hanging tests.
This is done by `pytest-timeout` plugin