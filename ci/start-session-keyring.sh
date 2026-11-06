#!/usr/bin/env bash
set -euo pipefail

: "${1:?usage: $0 <command> [args...]}"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${WORKSPACE_TMP:-/tmp}/runtime}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

exec dbus-run-session -- bash -c '
  set -euo pipefail
  eval "$(printf "ci\n" | gnome-keyring-daemon --daemonize --login --components=secrets)"
  printf "probe\n" | timeout 30 secret-tool store --label=status-e2e service status-e2e account probe
  timeout 30 secret-tool clear service status-e2e account probe
  exec "$@"
' bash "$@"
