#!/usr/bin/env bash
# Lifecycle wrapper for the agent QML dev loop (see .claude/skills/qml-storybook-loop).
# Manages a single Storybook instance used as a live harness for QML iteration.
#
# Usage:
#   storybook-agent.sh start [PageName]   # reuse running instance or launch on page
#   storybook-agent.sh status             # print pid or "not running"
#   storybook-agent.sh stop
#
# Prints the Storybook pid on success (start/status) for use with tools/ax.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT_VERSION="$(qmake -query QT_VERSION)"
BINARY="$REPO_ROOT/storybook/build/Qt$QT_VERSION/bin/Storybook.app/Contents/MacOS/Storybook"
LOG_DIR="${TMPDIR:-/tmp}"
LOG_FILE="$LOG_DIR/storybook-agent.log"

AX_CLI="$REPO_ROOT/tools/ax/ax"

running_pid() {
    pgrep -f "$BINARY" | head -1 || true
}

preflight() {
    if [[ ! -x "$AX_CLI" ]]; then
        swiftc -O "$REPO_ROOT/tools/ax/main.swift" -o "$AX_CLI"
    fi
    "$AX_CLI" preflight >&2 || {
        echo "error: missing macOS permissions (see above); aborting" >&2
        exit 1
    }
}

case "${1:-}" in
start)
    PAGE="${2:-}"
    preflight
    PID="$(running_pid)"
    if [[ -n "$PID" ]]; then
        echo "$PID"
        exit 0
    fi
    if [[ ! -x "$BINARY" ]]; then
        echo "error: Storybook binary not found at $BINARY — run 'make storybook-build'" >&2
        exit 1
    fi
    nohup "$BINARY" ${PAGE:+"$PAGE"} >"$LOG_FILE" 2>&1 &
    PID=$!
    # Give the window time to come up so callers can immediately query AX.
    sleep 2
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "error: Storybook exited on startup; log: $LOG_FILE" >&2
        exit 1
    fi
    echo "$PID"
    ;;
status)
    PID="$(running_pid)"
    if [[ -n "$PID" ]]; then echo "$PID"; else echo "not running"; exit 1; fi
    ;;
stop)
    PID="$(running_pid)"
    if [[ -n "$PID" ]]; then kill "$PID"; echo "stopped $PID"; else echo "not running"; fi
    ;;
*)
    echo "usage: $0 start [PageName] | status | stop" >&2
    exit 2
    ;;
esac
