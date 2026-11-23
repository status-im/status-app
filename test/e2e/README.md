# Desktop UI tests (e2e)

The tests drive a built app through a Qt plugin that is loaded into it,
[status-qml-inspector](https://github.com/status-im/status-qml-inspector). The plugin finds QML
objects and gives mouse and key input to Qt where input from the system arrives. The app is used as
it is; it is not rebuilt. The code that talks to the plugin is in `driver/`.

Linux and macOS. Checked so far: the tests in `tests/critical_tests_prs` and `tests/onboarding`.
Keycard tests and tests that open a file dialog have not been run this way yet.

---

## Run in Docker (recommended)

Needs a Linux x86_64 machine with Docker and about 20 GB of disk. Run from the repository root.

1. Build the CI image (`ci/tests.Dockerfile`):

   ```bash
   docker build --build-arg BASE="$(ci/build-image.sh --image desktop)" \
     -t status-e2e-tests -f ci/tests.Dockerfile ci
   ```

2. Build the plugin. The script downloads the plugin's source and Qt 6.11.0, the Qt of the app:

   ```bash
   test/e2e/scripts/inspector/build-plugin.sh /tmp/qmlinspector
   ```

   `PLUGIN_SRC=<path>` builds your own checkout of the plugin instead.

3. Get a Linux build: the `Status-linux-x86_64` artifact of the `CI` workflow, then

   ```bash
   tar -xzf Status.tar.gz && ./Status.AppImage --appimage-extract
   ```

4. Run tests. Arguments go to pytest:

   ```bash
   APP=$PWD/squashfs-root/AppRun PLUGINS=/tmp/qmlinspector/plugins \
     test/e2e/scripts/inspector/run-in-docker.sh tests/critical_tests_prs tests/onboarding
   ```

`run-in-docker.sh` sets up what `ci/Jenkinsfile.tests-e2e` sets up: Xvfb, fluxbox, a session
keyring and the local Waku fleet.

During a run the plugin listens on `127.0.0.1` without a password: any program on the same machine
can run QML code in the app. Run only on a machine where you trust all users.

---

## Run on the host

From `test/e2e`, one setup script installs CPython 3.14 (via `uv` if needed), builds the plugin,
creates `.venv`, installs `requirements.txt`, records `INSPECTOR_PLUGINS`, and ensures `.env` (from
`.env.example`) with `E2E_LOCAL_WAKU_FLEET` and `WALLET_TEST_USER_SEED`. Activate or the venv's
`.pth` files load `.env` into the environment for pytest:

| Platform | Command |
|----------|---------|
| macOS (Apple Silicon) | `./scripts/setup-macos.sh` |
| Linux | `./scripts/setup-linux.sh` |
| Windows | `powershell -File scripts/setup-windows.ps1` |

Optional argument: plugins directory (`generic/`). Defaults to the plugin just built. `QT_PREFIX` and
`PLUGIN_SRC` override Qt and plugin sources. Missing tools: macOS — Xcode CLT and CMake; Linux —
Docker; Windows — VS 2022 (C++), CMake, git.

With Docker running, setup also runs the local Waku fleet (`docker compose -p status-app … up -d` and
`scan_waku_fleet.py`). Set `E2E_SKIP_WAKU_FLEET=1` to skip; `E2E_WAKU_COMPOSE_PROJECT` overrides the
compose project name.

```bash
source .venv/bin/activate
pytest -m critical
```

On Windows the activate command is `.\.venv\Scripts\Activate.ps1`.

Tests with two instances (communities, syncing) need the [local Waku fleet](#local-waku-fleet-optional)
and `E2E_LOCAL_WAKU_FLEET=1`, as in CI.

Set `AUT_PATH` in `configs/_local.py` (copy from `configs/_local.default.py`): an unpacked AppImage's
`AppRun`, or a local `bin/nim_status_client` from `make nim_status_client`.

A local `bin/nim_status_client` does not carry its Qt and Status libraries. Add the directories that
`make run` uses (`$ROOT` is the repo root, `$QT_LIBDIR` is the Qt 6.11.0 `lib` directory):

```bash
export LD_LIBRARY_PATH="$QT_LIBDIR:$ROOT/vendor/status-go/build:$ROOT/vendor/status-go/build/bin:$ROOT/vendor/status-keycard-qt/build/linux:$ROOT/bin/StatusQ:$ROOT/ui/StatusQ/build/Qt6.11.0/lib"
```

For a local macOS app built with `make run`, set `QT_PREFIX` to the Qt that `qmake` reports before
`./scripts/setup-macos.sh`. `AUT_PATH` may be the `.app` bundle. The suite launches
`Contents/MacOS/nim_status_client`.

---

## Driver unit tests

They do not need the app:

```bash
cd test/e2e && pytest driver/tests
```

When a test cannot find an object, set `E2E_LOOKUP_LOG=<file>`: each line shows how many objects were
left after each rule of the locator.

---

## Keycard e2e (`@pytest.mark.keycard`)

Needs a build with `USE_SIMULATED_KEYCARD=true` and a **JRE ≥ 11** on `PATH`.

- Dev build, from the repo root: `USE_SIMULATED_KEYCARD=true make -j12`, then `AUT_PATH` → `…/status-app/bin/StatusDev`.
- Packaged build: CI **Build with Parameters** → enable `USE_SIMULATED_KEYCARD`.

```bash
pytest -m keycard -v
```

A client built with `USE_SIMULATED_KEYCARD=true` loads keycard from
`vendor/status-keycard-qt/build/linux-simulated-keycard` instead of `.../linux`.

---

## WalletConnect tests

`test_wallet_connect_personal_sign.py` and `test_wallet_connect_personal_sign_keycard.py` use a Node.js Sign Client dApp:

```bash
cd test/e2e/scripts/wallet_connect_dapp && npm ci
```

`npm ci` uses `package-lock.json`; `node_modules` is not committed — run `npm ci` again before the next WalletConnect run.

Requires **Node.js 20.19–20.x or 22+** (`NODE_BIN` if not on `PATH`) and network to the WalletConnect relay. `WALLET_CONNECT_PROJECT_ID` in the dApp must match the app’s `STATUS_BUILD_WALLET_CONNECT_PROJECT_ID`.

---

## Logs

`test/e2e/local_run_results/`: `pytest.log`, `aut.log`. Per-run screenshots: `local_run_results/run_<date>/`.

---

## Local Waku fleet (optional)

Local **logos-delivery** instead of `status.prod`. **Docker** must be running (`docker ps`). Setup and
`run-in-docker.sh` start a fleet for you.

From **repo root** (manual):

```bash
docker compose -p status-app -f ./docker-compose.waku.yml up -d --build --remove-orphans
python3 test/e2e/scripts/scan_waku_fleet.py --project status-app
```

That writes `assets/local-waku-fleets-config.json`. Then, from `test/e2e`:

```bash
export E2E_LOCAL_WAKU_FLEET=1
# export STATUS_FLEET=status-app.test   # optional; key in the JSON
pytest -m critical
```

`E2E_LOCAL_WAKU_FLEET` makes the app use that JSON. Without it, the app uses built-in fleets (e.g. `status.prod`).

---

## Pytest marks

```bash
pytest -m critical
pytest --markers
```

- `critical` — PR suite
- `keycard` — simulated keycard
- `skip` — skipped (usually a ticket)
- `timeout(...)` — hang guard
