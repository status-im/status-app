#!/usr/bin/env bash
set -euo pipefail

: "${1:?usage: $0 <command> [args...]}"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${WORKSPACE_TMP:-/tmp}/runtime}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# dbus-run-session reaps the app's children and reports each one on stderr.
exec 2> >(grep --line-buffered -v 'dbus-run-session: ignoring unknown child process' >&2)
exec dbus-run-session -- bash -c '
  set -euo pipefail
  eval "$(printf "ci\n" | gnome-keyring-daemon --daemonize --login --components=secrets)"
  printf "probe\n" | timeout 30 secret-tool store --label=status-e2e service status-e2e account probe
  timeout 30 secret-tool clear service status-e2e account probe
  exec "$@"
' bash "$@"
