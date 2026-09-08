#!/usr/bin/env bash
# Zero-input desktop repro runner for the in-app AutoReproDriver
# (ui/app/mainui/AutoReproDriver.qml). Launches the dev app with the scenario,
# watches the driver heartbeat and reports crash / freeze / clean run.
# macOS and Windows (Git Bash); Linux untested.
#
#   PASSWORD=... scripts/auto-repro.sh [scenario] [-- extra app ARGS]
#
#   scenario   default "wallet-settings:at=immediate,loops=30"
#   PASSWORD   dev profile password; logs into the last-used profile, or creates
#              one when DATA_DIR has none (required for zero-input runs)
#   RESTARTS=N one driver loop per process, N cold app starts (the driver parks
#              the wallet as active section so every start is "login -> wallet
#              incubating -> settings"); overrides loops=1 in the scenario
#   DATA_DIR   app data dir (default ./Status-autorepro, isolated from ./Status)
#   HB_GAP     seconds without heartbeat that count as a freeze (default 15)
#   TIMEOUT    per-process cap in seconds (default 900)
#   NO_BUILD=1 skip `make nim_status_client`; `make run` still refreshes resources.rcc
#
# Exit codes: 0 clean, 2 crash, 3 freeze (macOS: a `sample` dump is written), 4 timeout.
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1 ;; *) WIN=0 ;; esac
# the app parses --dataDir itself, so give it a native path on Windows
native_path() { if [ "$WIN" = 1 ]; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

SCENARIO=${1:-"wallet-settings:at=immediate,loops=30"}
[ "${1:-}" = "--" ] && SCENARIO="wallet-settings:at=immediate,loops=30"
shift || true
[ "${1:-}" = "--" ] && shift
DATA_DIR=${DATA_DIR:-"$REPO_ROOT/Status-autorepro"}
HB_GAP=${HB_GAP:-15}
TIMEOUT=${TIMEOUT:-900}
RESTARTS=${RESTARTS:-1}
OUT_DIR=${OUT_DIR:-"$REPO_ROOT/Status-autorepro/repro-runs"}
mkdir -p "$OUT_DIR" "$DATA_DIR"

if [ -n "${PASSWORD:-}" ]; then
  case "$SCENARIO" in *:*) SCENARIO="$SCENARIO,password=$PASSWORD" ;; *) SCENARIO="$SCENARIO:password=$PASSWORD" ;; esac
fi
if [ "$RESTARTS" -gt 1 ]; then
  SCENARIO=$(sed -E 's/,?loops=[0-9]+//' <<<"$SCENARIO")
  case "$SCENARIO" in *:*) SCENARIO="$SCENARIO,loops=1" ;; *) SCENARIO="$SCENARIO:loops=1" ;; esac
fi

export STATUS_AUTO_REPRO="$SCENARIO"
MAKE_FLAGS=()
if [ "$(uname -s)" = "Darwin" ]; then
  export PATH="$REPO_ROOT/vendor/nimbus-build-system/vendor/Nim/bin:$PATH"
  MAKE_FLAGS+=(USE_SYSTEM_NIM=1)
  # A mobile kit left in QMAKE (android/ios) would rebuild every dependency for
  # the wrong target; desktop runs always take the newest macOS kit unless told otherwise.
  case "${QMAKE:-}" in */macos/bin/qmake) ;; *) QMAKE=${DESKTOP_QMAKE:-$(ls -d "$HOME"/Qt/*/macos/bin/qmake | sort -V | tail -1)} ;; esac
  export QMAKE
fi

echo "scenario : ${SCENARIO/password=*/password=***}"
echo "data dir : $DATA_DIR"
echo "restarts : $RESTARTS"

if [ "${NO_BUILD:-0}" != "1" ]; then
  STAMP=$(date +%Y%m%d_%H%M%S)
  make nim_status_client ${MAKE_FLAGS[@]+"${MAKE_FLAGS[@]}"} > "$OUT_DIR/build_$STAMP.log" 2>&1 || {
    echo "build failed, see $OUT_DIR/build_$STAMP.log"; exit 1; }
fi

if [ "$WIN" = 1 ]; then
  app_pid() { tasklist //FI "IMAGENAME eq nim_status_client.exe" //FO CSV //NH 2>/dev/null | grep -o '"[0-9]*"' | head -1 | tr -d '"' || true; }
  app_alive() { [ -n "$(app_pid)" ]; }
  # WM_CLOSE first so QSettings (saved active section) and the DB flush; forced kill as fallback
  stop_app() {
    local pid; pid=$(app_pid); [ -z "$pid" ] && return 0
    taskkill //PID "$pid" > /dev/null 2>&1 || true
    for _ in $(seq 1 20); do app_alive || return 0; sleep 0.5; done
    taskkill //F //PID "$pid" > /dev/null 2>&1 || true
  }
  kill_app() { taskkill //F //PID "$1" > /dev/null 2>&1 || true; }
  sample_app() { echo "  (no stack sampling on Windows; attach a debugger to pid $1 before it is killed if needed)"; }
  crash_reports() { :; }
else
  APP_PATTERN="StatusDev.app/Contents/MacOS/nim_status_client"
  app_pid() { pgrep -n -f "$APP_PATTERN" || true; }
  # SIGTERM first so QSettings (saved active section) and the DB flush; SIGKILL as fallback
  stop_app() {
    local pid; pid=$(app_pid); [ -z "$pid" ] && return 0
    kill -TERM "$pid" 2>/dev/null || true
    for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || return 0; sleep 0.5; done
    kill -9 "$pid" 2>/dev/null || true
  }
  kill_app() { kill -9 "$1" 2>/dev/null || true; }
  sample_app() {
    sample "$1" 5 -file "$2" > /dev/null 2>&1 || true
    echo "  stack sample: $2"
  }
  crash_reports() {
    ls -t ~/Library/Logs/DiagnosticReports 2>/dev/null | grep -i "nim_status_client\|StatusDev" | head -2 | sed 's|^|  crash report: ~/Library/Logs/DiagnosticReports/|'
  }
fi

# One app process: launch, follow driver lines, classify. Echoes RESULT, returns exit code.
run_once() {
  local n=$1; shift
  local stamp log make_pid start now last_hb last_line line pid code
  stamp=$(date +%Y%m%d_%H%M%S)
  log="$OUT_DIR/run_${stamp}_$n.log"
  echo "--- start $n/$RESTARTS  log: $log"
  # `make run` refreshes resources.rcc when QML changed, then launches the app in the foreground
  make run ${MAKE_FLAGS[@]+"${MAKE_FLAGS[@]}"} ARGS="--dataDir=$(native_path "$DATA_DIR") $*" > "$log" 2>&1 &
  make_pid=$!
  start=$(date +%s); last_hb=$start; last_line=""
  while true; do
    sleep 1
    now=$(date +%s)
    line=$(grep -a "\[autoRepro\]" "$log" | tail -n 1 || true)
    if [ "$line" != "$last_line" ]; then
      last_line=$line; last_hb=$now
      case "$line" in *" :: hb"*) ;; *) echo "  ${line#*text=}" ;; esac
    fi
    if grep -aq "phase=done" "$log"; then
      echo "RESULT $n: clean"; stop_app; wait "$make_pid" 2>/dev/null || true; return 0
    fi
    if ! kill -0 "$make_pid" 2>/dev/null; then
      wait "$make_pid" && code=0 || code=$?
      echo "RESULT $n: app exited (make exit $code) before the scenario finished -> CRASH"
      echo "  last driver line: ${last_line#*text=}"
      crash_reports
      return 2
    fi
    pid=$(app_pid)
    if grep -aq "\[autoRepro\] loop=" "$log" && [ $((now - last_hb)) -ge "$HB_GAP" ] && [ -n "$pid" ]; then
      echo "RESULT $n: no heartbeat for ${HB_GAP}s -> FREEZE (pid $pid), sampling..."
      echo "  last driver line: ${last_line#*text=}"
      sample_app "$pid" "$OUT_DIR/freeze_${stamp}_$n.sample"
      kill_app "$pid"; wait "$make_pid" 2>/dev/null || true
      return 3
    fi
    if [ $((now - start)) -ge "$TIMEOUT" ]; then
      echo "RESULT $n: timeout after ${TIMEOUT}s"; stop_app; wait "$make_pid" 2>/dev/null || true; return 4
    fi
  done
}

stop_app
for n in $(seq 1 "$RESTARTS"); do
  run_once "$n" "$@" && continue
  exit $?
done
echo "RESULT: $RESTARTS clean start(s), nothing reproduced"
exit 0
