#!/usr/bin/env bash
set -e

# Library and plugin paths
export LD_LIBRARY_PATH="/app/lib:/app/lib64:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="/app/lib/qt6/plugins:/app/lib/plugins:${QT_PLUGIN_PATH:-}"
export QML2_IMPORT_PATH="/app/lib/qt6/qml:/app/lib/qml:${QML2_IMPORT_PATH:-}"
export QML_IMPORT_PATH="/app/lib/qt6/qml:/app/lib/qml:${QML_IMPORT_PATH:-}"

if [[ -x /app/libexec/QtWebEngineProcess ]]; then
  export QTWEBENGINEPROCESS_PATH="/app/libexec/QtWebEngineProcess"
  export QTWEBENGINE_RESOURCES_PATH="/app/resources"
  export QTWEBENGINE_LOCALES_PATH="/app/translations/qtwebengine_locales"
elif [[ -x /app/bin/QtWebEngineProcess ]]; then
  export QTWEBENGINEPROCESS_PATH="/app/bin/QtWebEngineProcess"
fi

export GST_PLUGIN_PATH="/app/lib/gstreamer-1.0:${GST_PLUGIN_PATH:-}"

# GTK modules for sound (libcanberra). 
export GTK_PATH="/app/lib/gtk-3.0:${GTK_PATH:-}"
export GTK_MODULES="canberra-gtk-module:${GTK_MODULES:-}"
export GTK3_MODULES="canberra-gtk-module:${GTK3_MODULES:-}"

# PC/SC smartcard environment
export PCSC_DRIVERS_DIR="/app/lib/pcsc/drivers"
export PCSCLITE_CONFIG_DIR="/tmp/pcscd/etc"

# Force XCB on X11 sessions
[[ -z "${WAYLAND_DISPLAY:-}" ]] && export QT_QPA_PLATFORM="xcb"

PCSCD_PID=""
PCSCD_PIDFILE="/tmp/pcscd/pcscd.pid"
PCSCD_RUN_DIR="/tmp/pcscd/run"
PCSCD_SOCKET="${PCSCD_RUN_DIR}/pcscd.comm"

cleanup() {
  if [[ -n "$PCSCD_PID" ]] && kill -0 "$PCSCD_PID" 2>/dev/null; then
    kill "$PCSCD_PID" 2>/dev/null || true
  fi
  rm -f "$PCSCD_PIDFILE"
}
trap cleanup EXIT TERM INT

wait_for() {
  local desc="$1" timeout="$2"; shift 2
  local deadline=$(( SECONDS + timeout ))
  local ms=$(( timeout * 1000 / 20 )) interval
  printf -v interval '%d.%03d' $(( ms / 1000 )) $(( ms % 1000 ))
  while ! "$@"; do
    if (( SECONDS >= deadline )); then
      echo "WARN: timed out after ${timeout}s waiting for ${desc}" >&2
      return 1
    fi
    sleep "$interval"
  done
}

# pcscd runs with --auto-exit and dies with
# the sandbox, so no prior process survives. Clear it; don't signal the old PID.
rm -f "$PCSCD_PIDFILE"

rm -rf "$PCSCD_RUN_DIR"
mkdir -p "$PCSCD_RUN_DIR" "$(dirname "$PCSCD_PIDFILE")" "$PCSCLITE_CONFIG_DIR"

# pcsc-lite's meson build installs the daemon to sbindir, i.e. /app/sbin/pcscd.
PCSCD_BIN="/app/sbin/pcscd"
if [[ -x "$PCSCD_BIN" ]]; then
  "$PCSCD_BIN" --foreground --auto-exit &
  PCSCD_PID=$!
  echo "$PCSCD_PID" > "$PCSCD_PIDFILE"
  # Wait for the IPC socket pcscd creates rather than a fixed delay,
  # so the app never connects before pcscd is listening.
  wait_for "pcscd socket ${PCSCD_SOCKET}" 5 \
    bash -c "[[ -S '${PCSCD_SOCKET}' ]]" || true
fi

exec /app/bin/nim_status_client "$@"
