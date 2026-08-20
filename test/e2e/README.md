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
# AUT_PATH = "/Users/you/status-app/bin/nim_status_client"
```

### Run tests (Terminal)

```bash
cd test/e2e
source .venv/bin/activate
pytest tests/onboarding/test_language_selector_and_password_strength.py -v --maxfail=1
# or the PR suite:
# pytest -m critical
```

### Run tests (PyCharm)

1. Complete [macOS one-time setup](#macos--one-time-setup) above.
2. **Interpreter**: `test/e2e/.venv/bin/python` — select **existing**, do not create a new venv from Homebrew or python.org.
3. **Working directory**: `test/e2e`
4. Use [`.env`](.env.example) (`SQUISH_DIR` / `PYTHONPATH`) — the setup script copies `.env.example` → `.env` if needed.
5. Set `AUT_PATH` in `configs/_local.py`.
6. Run pytest, e.g. the onboarding file above or `-m critical`.

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

That writes `assets/local-waku-fleets-config.json`.

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
