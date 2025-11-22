#!/usr/bin/env bash
# Flatpak wrapper script for Status Desktop
set -e

# Library and plugin paths
export LD_LIBRARY_PATH="/app/lib:/app/lib64:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="/app/lib/qt6/plugins:${QT_PLUGIN_PATH:-}"
export QML2_IMPORT_PATH="/app/lib/qt6/qml:${QML2_IMPORT_PATH:-}"
export QML_IMPORT_PATH="/app/lib/qt6/qml:${QML_IMPORT_PATH:-}"

# Qt WebEngine paths
export QTWEBENGINEPROCESS_PATH="/app/libexec/QtWebEngineProcess"
export QTWEBENGINE_RESOURCES_PATH="/app/resources"
export QTWEBENGINE_LOCALES_PATH="/app/translations/qtwebengine_locales"

# GStreamer paths
export GST_PLUGIN_PATH="/app/lib/gstreamer-1.0:${GST_PLUGIN_PATH:-}"
export GST_PLUGIN_SYSTEM_PATH="/app/lib/gstreamer-1.0"

# GTK modules for sound (libcanberra)
export GTK_MODULES="canberra-gtk-module:${GTK_MODULES:-}"
export GTK3_MODULES="canberra-gtk-module:${GTK3_MODULES:-}"

# PC/SC smartcard environment
export PCSC_DRIVERS_DIR="/app/lib/pcsc/drivers"
export PCSCLITE_CONFIG_DIR="/tmp/pcscd/etc"

# Force XCB on X11 sessions
[[ -z "$WAYLAND_DISPLAY" ]] && export QT_QPA_PLATFORM="xcb"

# Start pcscd for smartcard support (if available)
PCSCD_PID=""
PCSCD_PIDFILE="/tmp/pcscd/pcscd.pid"
PCSCD_RUN_DIR="/tmp/pcscd/run"

cleanup() {
  if [[ -n "$PCSCD_PID" ]] && kill -0 "$PCSCD_PID" 2>/dev/null; then
    kill "$PCSCD_PID" 2>/dev/null || true
  fi
  rm -f "$PCSCD_PIDFILE"
}
trap cleanup EXIT TERM INT

# Kill any orphan pcscd from previous runs
if [[ -f "$PCSCD_PIDFILE" ]]; then
  OLD_PID=$(cat "$PCSCD_PIDFILE" 2>/dev/null)
  if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
    kill -9 "$OLD_PID" 2>/dev/null || true
    sleep 0.2
  fi
  rm -f "$PCSCD_PIDFILE"
fi

rm -rf "$PCSCD_RUN_DIR"
mkdir -p "$PCSCD_RUN_DIR" "$(dirname "$PCSCD_PIDFILE")" "$PCSCLITE_CONFIG_DIR"

for pcscd in /app/sbin/pcscd /app/bin/pcscd; do
  if [[ -x "$pcscd" ]]; then
    "$pcscd" --foreground --auto-exit &
    PCSCD_PID=$!
    echo "$PCSCD_PID" > "$PCSCD_PIDFILE"
    # Brief delay to let pcscd initialize its IPC socket before the app connects
    sleep 0.3
    break
  fi
done

# Launch application
# needs dataDir otherwise default lands in sandbox which is inaccessible in flatpak builds  
exec /app/bin/nim_status_client --dataDir="${HOME}/.status-im" "$@"
