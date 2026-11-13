# Desktop UI tests (e2e)

**Squish 9.3.0**, bundled **Python 3.14**, `pip install -r requirements.txt`.

`SQUISH_DIR` / `PYTHONPATH` / `LD_LIBRARY_PATH`: only in `.venv` activate or PyCharm **pytest run configuration** — not in shell profile or Windows user env.

License: **Qt Account** (`squishconfig --license-qt-account --login`, not FLS `localhost:49345`).

Qt patch must match the AUT (CI is **6.11.0**). macOS: `squishconfig --qt=/path/to/QtCore.framework`. Linux: `UserQtLibDirectory` in `$SQUISH_DIR/etc/squish.ini` (below) — Linux `squishconfig` has no `--qt`. Windows: no `--qt`; the Qt wrapper is bundled (`Qt6Core.dll`).

Set `AUT_PATH` in `configs/_local.py` (copy from `configs/_local.default.py` if missing).

---

## Linux

`SQUISH_DIR` default: `$HOME/Squish_9_3_0`. Install Qt **6.11.0** (same patch as the AUT). `qmake -query QT_INSTALL_LIBS` is the directory that contains `libQt6Core.so.6`.

`startaut` reads `$SQUISH_DIR/etc/squish.ini` and prepends that directory onto the AUT library path. Without it the client dies before the Squish port opens (`libQt6Multimedia.so.6: cannot open shared object file` in `local_run_results/aut.log`):

```ini
[General]
UserQtLibDirectory = "/path/to/Qt/6.11.0/gcc_64/lib"
```

```bash
cd test/e2e
export SQUISH_DIR="${SQUISH_DIR:-$HOME/Squish_9_3_0}"
"$SQUISH_DIR/python/bin/python3.14" -m venv .venv && source .venv/bin/activate
python -m pip install -U pip && python -m pip install -r requirements.txt
```

Append to `.venv/bin/activate`. There is no `$SQUISH_DIR/python3` on Linux 9.3; `libpython3.14` is in `python/lib`.

```bash
export SQUISH_DIR="${SQUISH_DIR:-$HOME/Squish_9_3_0}"
export PYTHONPATH="$SQUISH_DIR/lib:$SQUISH_DIR/lib/python"
export LD_LIBRARY_PATH="$SQUISH_DIR/lib:$SQUISH_DIR/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

`AUT_PATH` in `configs/_local.py` (copy from `configs/_local.default.py` if missing): nightly `.AppImage`, or a local `bin/nim_status_client` from `make nim_status_client`.

An AppImage carries its own Qt and Status libraries. A local `bin/nim_status_client` does not — add the same directories `make run` uses, **before** the Squish paths (`$ROOT` is the repo root, `$QT_LIBDIR` is `UserQtLibDirectory`):

```bash
export LD_LIBRARY_PATH="$QT_LIBDIR:$ROOT/vendor/status-go/build:$ROOT/vendor/status-go/build/bin:$ROOT/vendor/status-keycard-qt/build/linux:$ROOT/bin/StatusQ:$ROOT/ui/StatusQ/build/Qt6.11.0/lib:$SQUISH_DIR/lib:$SQUISH_DIR/python/lib"
```

A client built with `USE_SIMULATED_KEYCARD=true` loads keycard from `vendor/status-keycard-qt/build/linux-simulated-keycard` instead of `.../linux`.

---

## Windows

`SQUISH_DIR` default: `C:\Squish_9_3_0` (use `python3.14.exe` if `python.exe` is missing)

```powershell
cd test\e2e
$env:SQUISH_DIR = 'C:\Squish_9_3_0'
& "$env:SQUISH_DIR\python\python.exe" -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -U pip; python -m pip install -r requirements.txt
```

Append to `.venv\Scripts\Activate.ps1`:

```powershell
$env:SQUISH_DIR = 'C:\Squish_9_3_0'
$env:PYTHONPATH = "$env:SQUISH_DIR\bin;$env:SQUISH_DIR\lib;$env:SQUISH_DIR\lib\python"
$env:PATH = "$env:SQUISH_DIR\lib;$env:SQUISH_DIR\bin;$env:PATH"
```

`AUT_PATH`: `StatusApp\bin\Status.exe` (packaged) or `StatusDev.exe` (local). Use `\\` in paths.

---

## macOS

Rosetta required. Run `./scripts/setup_mac_squish.sh` (x86_64 venv from `python3.14-intel64` — not Homebrew).

Prereqs: **Xcode.app** (`xcode-select --switch /Applications/Xcode.app/.../Developer`), Squish in `/Applications/Squish_9_3_0`, Status.app with Squish entitlements ([macOS CI job](https://ci.status.im/job/status-desktop/job/systems/job/macos/) + `Entitlements_squish.plist`).

```bash
softwareupdate --install-rosetta --agree-to-license
cd test/e2e && ./scripts/setup_mac_squish.sh
source .venv/bin/activate
```

---

## Run tests

```bash
cd test/e2e
source .venv/bin/activate          # Windows: .\.venv\Scripts\Activate.ps1
pytest -m critical
# pytest tests/onboarding/test_language_selector_and_password_strength.py -v --maxfail=1
```

---

## PyCharm

Interpreter: existing `test/e2e/.venv/bin/python` (not a new venv). Working dir: `test/e2e`. Env on **run configuration** only:

| OS | Variables |
|----|-----------|
| Linux | `SQUISH_DIR`, `PYTHONPATH`, `LD_LIBRARY_PATH` (paths as in activate above, including Qt and Status libs for a local `nim_status_client`) |
| Windows | `SQUISH_DIR`, `PYTHONPATH` (`bin;lib;lib\python`); prepend Squish `lib` and `bin` to `PATH` |
| macOS | `SQUISH_DIR=/Applications/Squish_9_3_0`, `PYTHONPATH=.../lib:.../lib/python` |

macOS interpreter must be **3.14 x86_64** (run log must not show Homebrew `python3.10`). If the IDE hangs, omit `PYTHONPATH` from `.env`.

---

## Squish IDE

Open `test/e2e/suite_status` in Squish IDE, set the AUT ([Which app to use](#which-app-to-use)), **Launch AUT**, **Pick** → `gui/objects_map/`. Do not commit local `suite.conf` / `envvars`.

---

## Which app to use

| Source | Linux | Windows | macOS |
|--------|-------|---------|-------|
| **CI nightly** | `.AppImage` from [Jenkins nightly](https://ci.status.im/job/status-desktop/job/nightly/) | `StatusApp\bin\Status.exe` from the nightly package | DMG with Squish entitlements → `Status.app` ([below](#getting-a-mac-build-from-ci)) |
| **Local dev build** | `bin/nim_status_client` | `bin\StatusDev.exe` | `bin/StatusDev.app` |

On Windows use **`StatusApp\bin\Status.exe`** in `AUT_PATH` (the name must contain `Status`). Local `make` → **`StatusDev.exe`**. On macOS, CI → **`Status.app`**; `make run` → **`bin/StatusDev.app`**. Set `AUT_PATH` to the `.app` bundle on Mac.

CI packaged builds are usually more stable; local dev builds work on all platforms.

### Getting a Mac build from CI

macOS e2e runs **locally only**. You need a DMG built with Squish entitlements:

1. https://ci.status.im/job/status-desktop/job/systems/job/macos/
2. **Entitlements** → `resources/Entitlements_squish.plist`
3. Download DMG, copy `Status.app` (e.g. `~/Downloads/Status.app`)
4. `AUT_PATH = "/Users/you/Downloads/Status.app"` in `configs/_local.py`

### Keycard e2e (`@pytest.mark.keycard`)

Needs `USE_SIMULATED_KEYCARD=true`. Set `AUT_PATH` in `configs/_local.py`, then:

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

**2. Packaged build** (`Status.app` / AppImage / .exe) — CI **Build with Parameters** → enable `USE_SIMULATED_KEYCARD` (on macOS also Squish entitlements as [above](#getting-a-mac-build-from-ci)).

**CI (nightly):** Linux and Windows can build with `USE_SIMULATED_KEYCARD=true` and run e2e with `KEYCARD_TESTS=true` (`pytest -m keycard`). Same parameters for a manual run. Windows agents need **JRE ≥ 11** on `PATH`.

### WalletConnect tests

`test_wallet_connect_personal_sign.py` and `test_wallet_connect_personal_sign_keycard.py` use a Node.js Sign Client dApp:

```bash
cd test/e2e/scripts/wallet_connect_dapp && npm ci
```

`npm ci` uses `package-lock.json`; `node_modules` is not committed — run `npm ci` again before the next WalletConnect run.

Requires **Node.js 20.19–20.x or 22+** (`NODE_BIN` if not on `PATH`) and network to the WalletConnect relay. `WALLET_CONNECT_PROJECT_ID` in the dApp must match the app’s `STATUS_BUILD_WALLET_CONNECT_PROJECT_ID`.

---

## Logs

`test/e2e/local_run_results/`: `pytest.log`, `aut.log` (`startaut`), `squish.log`. Per-run screenshots: `local_run_results/run_<date>/`.

---

## Local Waku fleet (optional)

Local **logos-delivery** instead of `status.prod` (Linux, Windows, macOS). **Docker** must be running (`docker ps`).

From **repo root**:

```bash
docker compose -f ./docker-compose.waku.yml up --build --remove-orphans
```

Generate fleets JSON (`--project` must match compose; default project name is often `status-app` or the `-p` name you used):

```bash
python3 test/e2e/scripts/scan_waku_fleet.py --project <compose-project>
```

Writes `assets/local-waku-fleets-config.json`. From `test/e2e` with venv activated:

```bash
export E2E_LOCAL_WAKU_FLEET=1
# export STATUS_FLEET=status-app.test   # optional; key in the JSON
pytest -m critical
```

`E2E_LOCAL_WAKU_FLEET` makes `startaut` set `STATUS_FLEET_CONFIG_FILE` to that JSON. Without it, the app uses built-in fleets (e.g. `status.prod`).

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

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `No module named 'squishtest'` | `SQUISH_DIR` + `PYTHONPATH` on the run config or activate. Windows `PYTHONPATH` must include `bin`. Also Linux `LD_LIBRARY_PATH`, Windows Squish `lib` and `bin` on `PATH` |
| PyCharm wrong Python | Remove old interpreter; use `.venv/bin/python` |
| Mac `need arm64` / wrong arch | Re-run `setup_mac_squish.sh` |
| Mac `QtPrivate_6_11_*` | `squishconfig --qt=` matches AUT |
| Linux `.so` load / AUT port never opens | Venv must be Squish `python3.14`. `LD_LIBRARY_PATH` needs `$SQUISH_DIR/lib` and `$SQUISH_DIR/python/lib`. `Could not read UserQtLibDirectory` or `libQt6Multimedia.so.6`: write `$SQUISH_DIR/etc/squish.ini`. Local `nim_status_client`: also the `make run` library directories. Details are in `local_run_results/aut.log` |
