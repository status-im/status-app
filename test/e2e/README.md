# Desktop UI tests (e2e)

Run automated UI tests for Status desktop on **Linux**, **Windows**, or **macOS**.

Pick your platform below and follow the steps in order.

---

## Before you begin

1. **Clone the repo** and open a terminal in `test/e2e`.
2. **Get a Status app** — CI build or local dev build (see [Which app to use](#which-app-to-use)).
3. **Install Squish** — required on all platforms ([Qt Squish](https://www.qt.io/squish)).

---

## Linux

Squish env lives in `.venv/bin/activate` (terminal) and `.env` (PyCharm). Do **not** put `SQUISH_DIR`, `PYTHONPATH`, or `LD_LIBRARY_PATH` in `/etc/profile` or `~/.bashrc` — that hangs desktop apps that scan the Python SDK (including PyCharm).

### Linux — one-time setup

1. Install **Squish 9.2.2** (default lookup: `$HOME/Squish_9_2_2` or `/opt/squish-runner-9.2.2-qt-6.11`) and activate the license ([Qt Squish](https://www.qt.io/squish)).
2. Get a **Status AppImage** or local `bin/nim_status_client` (see [Which app to use](#which-app-to-use)).
3. On Debian/Ubuntu, if `python3 -m venv` fails: `sudo apt install python3-venv`.
4. From `test/e2e`:

```bash
cd test/e2e
./scripts/setup_linux_squish.sh
```

The script creates `.venv`, installs `requirements.txt`, writes Squish into `activate` / `.env`, and copies `configs/_local.py` if it is missing. Override Squish path with `SQUISH_DIR=...` if needed.

On Ubuntu 24.04+ system `python3` is **3.12**, and `numpy~=1.25` has no wheel (`Cannot import 'setuptools.build_meta'`). `python3.10` is usually not on `PATH` — use Squish’s bundled interpreter (unset `PYTHONPATH` first; recreate `.venv` if the first run already used 3.12):

```bash
unset SQUISH_DIR PYTHONPATH LD_LIBRARY_PATH
rm -rf .venv
PYTHON=$HOME/Squish_9_2_2/python/bin/python3.10 ./scripts/setup_linux_squish.sh
# if Squish is under /opt:
# PYTHON=/opt/squish-runner-9.2.2-qt-6.11/python/bin/python3.10 ./scripts/setup_linux_squish.sh
```

5. Edit `configs/_local.py`:

```python
AUT_PATH = "/path/to/Status.AppImage"
# or local dev build:
# AUT_PATH = "/path/to/status-app/bin/nim_status_client"
```

### Run tests (Terminal)

```bash
cd test/e2e
source .venv/bin/activate
pytest tests/onboarding/test_language_selector_and_password_strength.py -v --maxfail=1
# or the PR suite:
# pytest -m critical
```

PyCharm: [Run tests (PyCharm)](#run-tests-pycharm).

---

## Windows

Squish env lives in `.venv\Scripts\Activate.ps1` / `activate.bat` (terminal) and `.env` (PyCharm). Do **not** set `SQUISH_DIR` or `PYTHONPATH` as permanent user or system environment variables.

### Windows — one-time setup

1. Install **Python 3.10+** and **Squish 9.2.2** (default lookup: `C:\squish-runner-9.2.2-qt-6.11`) and activate the license ([Qt Squish](https://www.qt.io/squish)).
2. Get **Status.exe** (see [Which app to use](#which-app-to-use)).
3. From `test/e2e` in PowerShell:

```powershell
cd test\e2e
powershell -ExecutionPolicy Bypass -File .\scripts\setup_windows_squish.ps1
```

The script creates `.venv`, installs `requirements.txt`, writes Squish into the activate scripts / `.env`, and copies `configs/_local.py` if it is missing. Override Squish path with `$env:SQUISH_DIR = 'D:\Squish'` before running.

4. Edit `configs/_local.py`:

```python
AUT_PATH = "C:\\Users\\you\\AppData\\Local\\StatusApp\\bin\\Status.exe"
# or local dev build:
# AUT_PATH = "C:\\path\\to\\status-app\\bin\\StatusDev.exe"
```

### Run tests (Terminal)

```powershell
cd test\e2e
.\.venv\Scripts\Activate.ps1
pytest tests/onboarding/test_language_selector_and_password_strength.py -v --maxfail=1
# or the PR suite:
# pytest -m critical
```

PyCharm: [Run tests (PyCharm)](#run-tests-pycharm).

---

## macOS

Apple Silicon (M-series) needs a few extra pieces beyond Linux/Windows. Squish 9.2.2’s Python and `squishserver` are **x86_64** (Rosetta). A clean Mac has **no** Intel / python.org Python at `/Library/Frameworks/Python.framework` — do **not** install one. The setup script uses Squish’s bundled Python (`python3.10` with `@loader_path`). Do **not** create the venv from Homebrew, python.org, or Squish’s `python3.10-intel64` (that stub looks for the missing system framework and crashes).

### macOS — one-time setup

Do these in order on a clean Mac.

1. **Rosetta 2** (required):

```bash
softwareupdate --install-rosetta --agree-to-license
```

2. **Xcode.app** from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835) (not only Command Line Tools). Squish IDE / Inspector fail with “Xcode installation was not found” without it. Open Xcode once, then:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

3. Install **Squish 9.2.2** into `/Applications/Squish_9_2_2` and activate the license ([Qt Squish](https://www.qt.io/squish)).

4. Install **the same Qt patch** Status and Squish were built with (a mismatch shows `StatusDialog unavailable` / `QtPrivate_6_11_0` in the AUT log). Point Squish at that kit’s `QtCore.framework` (path depends on how you installed Qt):

```bash
/Applications/Squish_9_2_2/bin/squishconfig --qt=/path/to/QtCore.framework
```

5. Get **Status.app** — CI DMG with Squish entitlements (see [Mac CI build](#getting-a-mac-build-from-ci)).

6. **x86_64 OpenSSL** (Intel Homebrew — not `/opt/homebrew`). Needed to compile `scrypt`:

```bash
# Intel Homebrew once, if /usr/local/bin/brew is missing:
#   arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
arch -x86_64 /usr/local/bin/brew install openssl@3
```

Always call Intel brew as `arch -x86_64 /usr/local/bin/brew`.

7. From `test/e2e`:

```bash
cd test/e2e
./scripts/setup_mac_squish.sh
```

The script creates `.venv` from Squish’s bundled Python (no system Intel Python needed), installs `requirements.txt`, and copies `configs/_local.py` / `.env` if they are missing. Override Squish path with `SQUISH_DIR=...` if needed. Do **not** put `SQUISH_DIR` or `PYTHONPATH` in `~/.zshrc`.

8. Edit `configs/_local.py`:

```python
AUT_PATH = "/Users/you/Downloads/Status.app"
# or local dev build:
# AUT_PATH = "/Users/you/status-app/bin/StatusDev.app"
```

### Run tests (Terminal)

```bash
cd test/e2e
source .venv/bin/activate
pytest tests/onboarding/test_language_selector_and_password_strength.py -v --maxfail=1
# or the PR suite:
# pytest -m critical
```

PyCharm: [Run tests (PyCharm)](#run-tests-pycharm).

---

## Run tests (PyCharm)

Same on Linux, Windows, and macOS. Finish the one-time setup for your OS first.

1. **Interpreter**: existing `.venv` — `test/e2e/.venv/bin/python` (Linux / macOS) or `test\e2e\.venv\Scripts\python.exe` (Windows). Do not create a new venv (on Mac: not from Homebrew or python.org).
2. **Working directory**: `test/e2e`
3. Set `AUT_PATH` in `configs/_local.py`.
4. **`SQUISH_DIR` alone is not enough** — Python finds `squishtest` via `PYTHONPATH`. Put the variables on the **pytest run configuration** (Run → Edit Configurations → Environment variables), not on the project interpreter, and not in `/etc/profile`, `~/.zshrc`, or Windows user/system environment.
5. If putting `PYTHONPATH` in `.env` makes PyCharm hang on “Updating Python interpreter”, omit it from `.env` and set it only on that run configuration.
6. Run pytest, e.g. `tests/onboarding/test_language_selector_and_password_strength.py` or `-m critical`.

Use your real Squish path.

**Linux** (also `LD_LIBRARY_PATH`, or `squishtest`’s `.so` will not load):

```
SQUISH_DIR=/home/you/Squish_9_2_2
PYTHONPATH=/home/you/Squish_9_2_2/lib:/home/you/Squish_9_2_2/lib/python
LD_LIBRARY_PATH=/home/you/Squish_9_2_2/lib:/home/you/Squish_9_2_2/python3/lib
```

**Windows** (`PYTHONPATH` uses `;`). Prepend Squish `lib` and `python3\lib` to `PATH` in the same run configuration — do not replace the whole `PATH`:

```
SQUISH_DIR=C:\squish-runner-9.2.2-qt-6.11
PYTHONPATH=C:\squish-runner-9.2.2-qt-6.11\lib;C:\squish-runner-9.2.2-qt-6.11\lib\python
```

**macOS:**

```
SQUISH_DIR=/Applications/Squish_9_2_2
PYTHONPATH=/Applications/Squish_9_2_2/lib:/Applications/Squish_9_2_2/lib/python
```

---

## Which app to use

| Source | Linux | Windows | macOS |
|--------|-------|---------|-------|
| **CI nightly** | `.AppImage` from [Jenkins nightly](https://ci.status.im/job/status-desktop/job/nightly/) | `StatusApp\bin\Status.exe` from the nightly package | DMG with Squish entitlements → `Status.app` ([below](#getting-a-mac-build-from-ci)) |
| **Local dev build** | `bin/nim_status_client` | `bin\StatusDev.exe` | `bin/StatusDev.app` |

On Windows use the packaged launcher **`StatusApp\bin\Status.exe`** (e2e requires `Status` in `AUT_PATH`). A local `make` build is **`StatusDev.exe`**. On macOS, CI is **`Status.app`**; `make run` produces **`bin/StatusDev.app`**. Set `AUT_PATH` to the `.app` bundle.

CI packaged builds are usually more stable; local dev builds work on all platforms.

### Getting a Mac build from CI

macOS e2e runs **locally only** (Linux and Windows run in Jenkins). You need a DMG built with Squish entitlements:

1. https://ci.status.im/job/status-desktop/job/systems/job/macos/
2. **Entitlements** → `resources/Entitlements_squish.plist`
3. Download DMG, copy `Status.app` (e.g. `~/Downloads/Status.app`)
4. `AUT_PATH = "/Users/you/Downloads/Status.app"` in `configs/_local.py`

### Keycard e2e (`@pytest.mark.keycard`)

Needs a build with simulated keycard (`USE_SIMULATED_KEYCARD=true`). Set `AUT_PATH` in `configs/_local.py`, then:

```bash
cd test/e2e && source .venv/bin/activate
pytest -m keycard -v
```

Requires a **JRE ≥ 11** on `PATH` (packaged builds ship the simulator, but still start it with the host JVM).

**1. Dev build** — from repo root:

```bash
USE_SIMULATED_KEYCARD=true make -j12
```

`AUT_PATH` → `…/status-app/bin/StatusDev` (or the platform equivalent under `bin/`).

**2. Packaged build** (`Status.app` / AppImage / .exe) — CI **Build with Parameters** → enable `USE_SIMULATED_KEYCARD` (on macOS also Squish entitlements as [above](#getting-a-mac-build-from-ci)). `AUT_PATH` → the packaged app.

**CI (nightly):** the nightly job builds a separate Linux and Windows package with `USE_SIMULATED_KEYCARD=true` (not published as the nightly artifacts) and runs `tests-e2e` with `KEYCARD_TESTS=true` (`pytest -m keycard`). Manual run: same two parameters — package with `USE_SIMULATED_KEYCARD`, then e2e with `KEYCARD_TESTS` and `BUILD_SOURCE` pointing at that package. Windows e2e agents need a **JRE ≥ 11** on `PATH`.

---

## Logs

All platforms write to `test/e2e/local_run_results/`:

- `pytest.log` — test runner
- `aut.log` — app launch (`startaut`)
- `squish.log` — Squish server

Per-run screenshots and data: `local_run_results/run_<date>/`.

---

## Local Waku fleet (optional)

Run against a local **nwaku** stack instead of `status.prod`. Works on **Linux, Windows, and macOS** — same env vars and compose file everywhere.

**Prerequisites:** Docker installed and running (`docker ps` must work). On Mac/Windows use [Docker Desktop](https://www.docker.com/products/docker-desktop/) and wait until it is fully started before running compose.

From the **repo root** (`status-app/`):

```bash
docker compose -f ./docker-compose.waku.yml up --build --remove-orphans
```

Compose does not write the fleets JSON. Generate it from the repo root (`--project` must match compose; default is `e2e-fleet` if you passed `-p e2e-fleet`, otherwise usually `status-app`):

```bash
python3 test/e2e/scripts/scan_waku_fleet.py --project <compose-project>
```

That writes `assets/local-waku-fleets-config.json` (override with `--output`; `--fleet-name` must match the fleet you will run, default `status-app.test`).

Leave this running. In another terminal, from `test/e2e` with your venv activated:

```bash
export E2E_LOCAL_WAKU_FLEET=1
# export STATUS_FLEET=status-app.test   # optional; must be a key in the JSON
pytest -m critical
```

`E2E_LOCAL_WAKU_FLEET` makes the runner point the app at that JSON: CLI `--waku-fleets-config` and env **`STATUS_FLEET_CONFIG_FILE`** (what status-go reads). Locally you do not need to export `STATUS_FLEET_CONFIG_FILE` — startaut sets it to `<repo>/assets/local-waku-fleets-config.json`. CI sets the same variable on the agent (`ci/Jenkinsfile.tests-e2e`). If you generate the file elsewhere, copy or write it to that path (the runner does not read a custom `STATUS_FLEET_CONFIG_FILE` from your shell).

Without `E2E_LOCAL_WAKU_FLEET`, the app uses built-in fleets (e.g. `status.prod`).

---

## Pytest marks

```bash
pytest -m critical      # main PR checks
pytest --markers        # list all marks
```

- `critical` — important desktop PR checks
- `keycard` — simulated keycard tests (`USE_SIMULATED_KEYCARD=true` build)
- `skip` — skipped tests (usually with a ticket)
- `timeout(...)` — hanging-test guard (`pytest-timeout`)

---

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| `SQUISH_DIR` error | Activate `.venv` (terminal) or set env on the [PyCharm](#run-tests-pycharm) run configuration. Do **not** put Squish in `/etc/profile`. |
| Linux: `python3 -m venv` / ensurepip | `sudo apt install python3-venv`, then `./scripts/setup_linux_squish.sh` |
| Linux: `Cannot import 'setuptools.build_meta'` / numpy on 3.12 | Unset `PYTHONPATH`, `rm -rf .venv`, then `PYTHON=$HOME/Squish_9_2_2/python/bin/python3.10 ./scripts/setup_linux_squish.sh` (or `$SQUISH_DIR/python/bin/python3.10` if Squish is under `/opt`) |
| Linux: `import squishtest` / `.so` | Re-run `./scripts/setup_linux_squish.sh` so `LD_LIBRARY_PATH` is in `activate` |
| PyCharm: `No module named 'squishtest'` | `SQUISH_DIR` is not enough. Set `PYTHONPATH` (and Linux `LD_LIBRARY_PATH` / Windows `PATH`) on the [pytest run configuration](#run-tests-pycharm), not the interpreter. |
| PyCharm hangs on “Updating Python interpreter” | Do not put `PYTHONPATH` on the interpreter, in `/etc/profile`, or in `.env` if the IDE loads it for the SDK. Set it only on the run configuration. |
| Windows: Squish not found | `$env:SQUISH_DIR = 'C:\squish-runner-9.2.2-qt-6.11'; .\scripts\setup_windows_squish.ps1` |
| Mac: Squish Python not found | `SQUISH_DIR=/Applications/Squish_9_2_2 ./scripts/setup_mac_squish.sh` |
| Mac: `Library not loaded: .../Python.framework/Versions/3.10` / `Abort trap: 6` | Clean Mac has no python.org Intel Python — that is expected. Do not install it and do not use `python3.10-intel64` as the venv base. Re-run `./scripts/setup_mac_squish.sh`. |
| Mac: `Failed building wheel for scrypt` | Install x86_64 OpenSSL: `arch -x86_64 /usr/local/bin/brew install openssl@3`, then re-run setup. ARM Homebrew (`/opt/homebrew`) will not work. |
| Mac: `Segmentation fault` on `import squishtest` | Venv was using python.org’s framework. Re-run `./scripts/setup_mac_squish.sh`. |
| Mac: `Python.framework` / `squishtest` | Re-run `./scripts/setup_mac_squish.sh` |
| Mac: `EVP_DigestSqueeze` | `pip install -r requirements.txt` in activated `.venv` |
| Mac: PyCharm wrong Python | Use existing `.venv/bin/python`, not Homebrew |
| Mac: PyCharm still shows a deleted `.venv` | Settings → Python Interpreter → Show All → remove the old interpreter, then add the new `.venv/bin/python` |
| Mac: Squish IDE “Xcode installation was not found” | Install **Xcode.app**, then `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` |
| Mac: `StatusDialog unavailable` / `QtPrivate_6_11_*` in `aut.log` | Squish Qt patch ≠ Status.app Qt. Point Squish at the matching kit: `squishconfig --qt=/path/to/QtCore.framework`. |
| App won’t attach / segfault in `get_context` / `attachToApplication` | Use a Status.app built with Squish entitlements. Launch the app once from Finder if Gatekeeper blocks it. |
| Mac: Python quit during test | Retry; check `local_run_results/aut.log` |
| Test hangs | Try a CI build instead of local dev |
| Docker: `docker.sock` not found | Start Docker Desktop (Mac/Windows) or the Docker daemon (Linux); verify with `docker ps` |
| `unknown fleet` with local Waku | Fleet in saved data must match `local-waku-fleets-config.json` |
| Windows path errors | Double backslashes in `AUT_PATH`; use `Status.exe` in StatusApp folder |

---

## CI overview

| Platform | E2e in Jenkins? | Where to get the app |
|----------|-----------------|----------------------|
| Linux | Yes | [Nightly](https://ci.status.im/job/status-desktop/job/nightly/) + [tests-e2e](https://ci.status.im/job/status-desktop/job/systems/job/linux/) |
| Windows | Yes | Nightly + Windows tests-e2e |
| macOS | No (local only) | [macOS systems job](https://ci.status.im/job/status-desktop/job/systems/job/macos/) |

Jenkins agents set `SQUISH_DIR` and `PYTHONPATH` automatically on Linux/Windows.
