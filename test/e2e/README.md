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

Details: [Notion — Linux setup](https://www.notion.so/Linux-21f7abd2bb684a0fb10057848760a889).

### One-time setup

```bash
cd test/e2e
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cp configs/_local.default.py configs/_local.py
```

Edit `configs/_local.py` — set `AUT_PATH`:

```python
AUT_PATH = "/path/to/Status.AppImage"
# or local dev build:
# AUT_PATH = "/path/to/status-app/bin/nim_status_client"
```

Set `SQUISH_DIR` (e.g. `/opt/squish-runner-9.2.2-qt-6.11`).

### Run tests

```bash
cd test/e2e
source .venv/bin/activate
pytest -m critical
```

---

## Windows

Details: [Notion — Windows setup](https://www.notion.so/Windows-fbccd2b09b784b32ba4174233d83878d).

### One-time setup

```bash
cd test\e2e
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt

copy configs\_local.default.py configs\_local.py
```

Edit `configs/_local.py` — set `AUT_PATH`:

```python
AUT_PATH = "C:\\Users\\you\\AppData\\Local\\StatusApp\\bin\\Status.exe"
# or local dev build:
# AUT_PATH = "C:\\path\\to\\status-app\\bin\\Status.exe"
```

Set `SQUISH_DIR` (e.g. `C:\squish-runner-9.2.2-qt-6.11`).

### Run tests

```bash
cd test\e2e
.venv\Scripts\activate
pytest -m critical
```

---

## macOS

Mac uses Squish’s own Python — not Homebrew. Run the setup script **once**; it creates `.venv` and configures Squish paths.

### macOS — one-time setup

1. Install **Squish 9.2.2** (`/Applications/Squish_9_2_2`).
2. Get **Status.app** — CI build with Squish entitlements or local dev build (see [Mac CI build](#getting-a-mac-build-from-ci)).
3. In Terminal:

```bash
cd test/e2e
./scripts/setup_mac_squish.sh

cp configs/_local.default.py configs/_local.py
```

4. Edit `configs/_local.py`:

```python
AUT_PATH = "/Users/you/Downloads/Status.app"
# or local dev build:
# AUT_PATH = "/Users/you/status-app/bin/nim_status_client"
```

The setup script fixes Squish library paths, creates `.venv` from Squish’s Python, adds `SQUISH_DIR` / `PYTHONPATH` to `activate`, and installs `requirements.txt`. Override Squish path if needed:

```bash
SQUISH_DIR=/Applications/Squish_9_2_2 ./scripts/setup_mac_squish.sh
```

### Run tests (Terminal)

```bash
cd test/e2e
source .venv/bin/activate
pytest -m critical
```

Do **not** put `SQUISH_DIR` or `PYTHONPATH` in `~/.zshrc` — they are set when you activate `.venv`.

### Run tests (PyCharm)

1. Complete [macOS one-time setup](#macos--one-time-setup) above.
2. **Interpreter**: `test/e2e/.venv/bin/python` — select **existing**, do not create a new venv from Homebrew.
3. **Working directory**: `test/e2e`
4. Copy [`.env.example`](.env.example) → `.env` (or paste those variables into the run config).
5. Set `AUT_PATH` in `configs/_local.py`.
6. Run pytest, e.g. with `-m critical`.

---

## Which app to use

| Source | Linux | Windows | macOS |
|--------|-------|---------|-------|
| **CI nightly** | `.AppImage` from [Jenkins nightly](https://ci.status.im/job/status-desktop/job/nightly/) | `Status.exe` from nightly | DMG with Squish entitlements ([below](#getting-a-mac-build-from-ci)) |
| **Local dev build** | `bin/nim_status_client` or AppImage | `bin\Status.exe` | `Status.app` or `bin/nim_status_client` |

CI builds are usually more stable; local dev builds work on all platforms.

### Getting a Mac build from CI

macOS e2e runs **locally only** (Linux and Windows run in Jenkins). You need a DMG built with Squish entitlements:

1. https://ci.status.im/job/status-desktop/job/systems/job/macos/
2. **Build with Parameters** → pick architecture
3. **Entitlements** → `resources/Entitlements_squish.plist`
4. Download DMG, copy `Status.app` (e.g. `~/Downloads/Status.app`)
5. `AUT_PATH = "/Users/you/Downloads/Status.app"` in `configs/_local.py`

### Keycard e2e (`@pytest.mark.keycard`)

Needs a build with simulated keycard (`USE_SIMULATED_KEYCARD=true`). Set `AUT_PATH` in `configs/_local.py`, then:

```bash
cd test/e2e && source .venv/bin/activate
pytest -m keycard -v
```

**1. Dev build** — from repo root:

```bash
USE_SIMULATED_KEYCARD=true make -j12
```

`AUT_PATH` → `…/status-app/bin/nim_status_client` (or the platform equivalent under `bin/`).

**2. Packaged build** (`Status.app` / AppImage / exe) — CI **Build with Parameters** → enable `USE_SIMULATED_KEYCARD` (on macOS also Squish entitlements as [above](#getting-a-mac-build-from-ci)). `AUT_PATH` → the packaged app.

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

Leave this running. In another terminal, from `test/e2e` with your venv activated:

```bash
export E2E_LOCAL_WAKU_FLEET=1
# export STATUS_FLEET=status-app.test   # optional; must match assets/local-waku-fleets-config.json
pytest -m critical
```

Without `E2E_LOCAL_WAKU_FLEET`, the app uses built-in fleets (e.g. `status.prod`). CI sets this on Linux and Windows in [ci/Jenkinsfile.tests-e2e](../../ci/Jenkinsfile.tests-e2e).

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
| `SQUISH_DIR` error | Mac: `source .venv/bin/activate`. Linux/Windows: `export SQUISH_DIR=...`. PyCharm: use `.env`. |
| Mac: Squish Python not found | `SQUISH_DIR=/Applications/Squish_9_2_2 ./scripts/setup_mac_squish.sh` |
| Mac: `Python.framework` / `squishtest` | Re-run `./scripts/setup_mac_squish.sh` |
| Mac: `EVP_DigestSqueeze` | `pip install -r requirements.txt` in activated `.venv` |
| Mac: PyCharm wrong Python | Use existing `.venv/bin/python`, not Homebrew |
| App won’t attach | Launch app manually first; Mac needs Squish-entitlements build |
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
