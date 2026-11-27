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

1. Get the CI image (`ci/tests.Dockerfile`), pulled when it is published and built otherwise:

   ```bash
   ci/build-image.sh --pull tests
   docker tag "$(ci/build-image.sh --image tests)" status-e2e-tests
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

## Run on your machine

From `test/e2e`.

1. Set up Python, the plugin and `.venv`. This also starts the local Waku fleet (communities and sync
   need it). `E2E_SKIP_WAKU_FLEET=1` skips the fleet.

   | Platform | Command |
   |----------|---------|
   | macOS (Apple Silicon) | `./scripts/setup-macos.sh` |
   | Linux | `./scripts/setup-linux.sh` |
   | Windows | `powershell -File scripts/setup-windows.ps1` |

   Needs: macOS — Xcode Command Line Tools, CMake and Homebrew `libpq`; Linux — Docker (running), git and
   `libpq5`; Windows — Visual Studio 2022 (C++), CMake, git and WSL 1 for the fleet (the script installs
   `libpq` inside WSL).

2. Point the tests at the app. Copy `configs/_local.default.py` to `configs/_local.py` and set
   `AUT_PATH`:

   - macOS: the `.app` bundle, for example `bin/StatusDev.app` or a nightly `.app`. The suite starts
     `Contents/MacOS/nim_status_client`. `AUT_PATH` may also be that binary itself.
   - Linux: an unpacked AppImage's `AppRun`, or `bin/nim_status_client`.
   - Windows: `Status\bin\Status.exe`.

   A local `bin/nim_status_client` on Linux does not carry its libraries. Before pytest (`$ROOT` is the
   repo root, `$QT_LIBDIR` is the Qt 6.11.0 `lib` directory):

   ```bash
   export LD_LIBRARY_PATH="$QT_LIBDIR:$ROOT/vendor/status-go/build:$ROOT/vendor/status-go/build/bin:$ROOT/vendor/status-keycard-qt/build/linux:$ROOT/bin/StatusQ:$ROOT/ui/StatusQ/build/Qt6.11.0/lib"
   ```

   For a local Linux binary built with `USE_SIMULATED_KEYCARD=true`, use
   `…/vendor/status-keycard-qt/build/linux-simulated-keycard` instead of `…/build/linux` in
   `LD_LIBRARY_PATH` (see [Keycard e2e](#keycard-e2e-pytestmarkkeycard)).

   For a macOS app built with `make run`, set `QT_PREFIX` to the Qt that `qmake` reports and run step 1
   again, so the plugin is built against that Qt.

3. Open `.env` and set `WALLET_TEST_USER_SEED` (wallet tests). Setup creates `.env` from
   `.env.example` on first run and appends missing keys (`E2E_LOCAL_WAKU_FLEET=1`, and so on) to an
   existing file. Activating `.venv` loads `.env`.

4. Run:

   ```bash
   source .venv/bin/activate
   pytest -m critical
   ```

   Windows: `.\.venv\Scripts\Activate.ps1`, then `pytest -m critical`.

The fleet keeps running after setup. Start it again from the repo root with
`test/e2e/scripts/start-waku-fleet.sh` (`--stop` stops it). On Windows:
`powershell -File test\e2e\scripts\start-waku-fleet-windows.ps1`.

---

## Inspect the screen

The inspector is not a separate window. It is loaded into the app and answers on a local port.

1. Take the `plugins` directory from setup (it contains `generic/`). The setup script prints
   its path as `INSPECTOR_PLUGINS`; it is injected into `.venv` activation rather than written
   to `.env`.

2. Start the app with the plugin. Pick a free port.

   macOS or Linux:

   ```bash
   export QT_PLUGIN_PATH="/path/to/plugins"
   export QT_QPA_GENERIC_PLUGINS="qmlinspector:3768"
   export STATUS_RUNTIME_TEST_MODE=1
   ```

   Windows (PowerShell):

   ```powershell
   $env:QT_PLUGIN_PATH = "C:\path\to\plugins"
   $env:QT_QPA_GENERIC_PLUGINS = "qmlinspector:3768"
   $env:STATUS_RUNTIME_TEST_MODE = "1"
   ```

   Then start the app as usual.

3. The app log must contain `Inspector server listening on port 3768`. Without
   `STATUS_RUNTIME_TEST_MODE=1` the plugin does nothing.

4. Ask for the element tree. One command, one reply:

   ```bash
   printf '%s\n' '{"id":1,"command":"getTree","params":{}}' | nc 127.0.0.1 3768
   ```

   The reply is the QML tree: type, id, text, visibility and position.

   For a short list of what is on screen, run the MCP server from
   [status-qml-inspector](https://github.com/status-im/status-qml-inspector) and call `qml_snapshot`.
   Set `QML_INSPECTOR_HOST=127.0.0.1` and `QML_INSPECTOR_PORT=3768`.

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

Keycard tests drive the in-app **Keycard Simulator Controller**, which talks to the
[jcardsim-backed simulator](../../vendor/status-keycard-qt/test/keycard-simulator/README.md)
bundled with simulated-keycard builds.

### Build with simulated keycard

From the **repository root**, pass `USE_SIMULATED_KEYCARD=true` to `make` (same targets as a normal
dev build). Example:

```bash
USE_SIMULATED_KEYCARD=true make -j12          # Linux
USE_SIMULATED_KEYCARD=true make run         # macOS → bin/StatusDev.app
USE_SIMULATED_KEYCARD=true make nim_status_client   # or full package target on Windows
```

That flag:

- builds `status-keycard-qt` into `vendor/status-keycard-qt/build/<platform>-simulated-keycard`
  (on Linux, `…/linux-simulated-keycard` instead of `…/linux`);
- precompiles `vendor/status-keycard-qt/test/keycard-simulator` (build host needs **JDK with `javac` ≥ 11**);
- links the client with `-d:useSimulatedKeycard` (separate Nim cache — toggling the flag forces a client
  rebuild; do not mix a normal client with a simulated `status-keycard-qt` library).

Packaged builds: Jenkins **Build with Parameters** → `USE_SIMULATED_KEYCARD=true` (Linux / Windows /
macOS). The simulator tree is copied next to the app (`share/keycard-simulator` on Linux, and so on).
GitHub **e2e nightly** builds separate Linux packages with the same flag for the `keycard` pytest mark.

### Run keycard tests

Set `AUT_PATH` in `configs/_local.py` ([Run on your machine](#run-on-your-machine)):

| Platform | Typical `AUT_PATH` after a simulated dev build |
|----------|------------------------------------------------|
| Linux | `…/status-app/bin/nim_status_client` |
| macOS | `…/status-app/bin/StatusDev.app` |
| Windows | `…/status-app/bin/Status.exe` |

Or point at a CI package built with `USE_SIMULATED_KEYCARD=true`.

**JRE ≥ 11** on `PATH` when running tests (the app starts the simulator with the host JVM; packaged
builds ship the simulator files but not a JVM).

For a local binary under `bin/`, the test runner sets `STATUS_KEYCARD_SIM_DIR` to
`vendor/status-keycard-qt/test/keycard-simulator` when that directory exists. Override with
`STATUS_KEYCARD_SIM_DIR` if needed.

On Linux, if you export `LD_LIBRARY_PATH` for `bin/nim_status_client`, include
`vendor/status-keycard-qt/build/linux-simulated-keycard` (not `…/build/linux`).

```bash
cd test/e2e && source .venv/bin/activate
pytest -m keycard -v
```

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

## Local Waku fleet

Setup starts it. To start it again, use the commands in [Run on your machine](#run-on-your-machine).
That writes `assets/local-waku-fleets-config.json`. With `E2E_LOCAL_WAKU_FLEET=1` the app uses that
file. Without it, the app uses the built-in fleets (for example `status.prod`). `run-in-docker.sh`
starts its own fleet.

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
