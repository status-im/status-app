#!/usr/bin/env bash
# Platform-switch cleanup for shared vendor artifacts. See docs/adr/0003-platform-sentinel-ownership.md.
set -euo pipefail

# $1 = platform target: darwin-arm64 / ios-arm64 / android-arm64
KEY="${1:-}"
GIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$GIT_ROOT/.platform-target"

[ -n "$KEY" ] || { echo "platform_pre_build_cleanup: empty PLATFORM_TARGET" >&2; exit 1; }

PREV="$(cat "$STATE" 2>/dev/null || echo none)"
[ "$PREV" = "$KEY" ] && exit 0

echo "platform changed ($PREV -> $KEY); cleaning shared artifacts" >&2

# 1) qrcodegen needs no entry: the desktop client {.compile.}s the C source
# into its own nimcache, and the mobile build's buildQRCodeGen.sh `make
# clean`s the shared source tree before every build.
# 2) nim-sds (shared libsds.* + nimcache): outputs land under
# <statusgo build root>/.sds-build, or under vendor/nim-sds/build for a
# develop-linked sds checkout.
rm -rf "$GIT_ROOT/.statusgo-build/.sds-build" 2>/dev/null || true
rm -rf "$GIT_ROOT/vendor/status-go/.sds-build" 2>/dev/null || true
rm -rf "$GIT_ROOT/vendor/nim-sds/build" 2>/dev/null || true
[ -n "${HOME:-}" ] && rm -rf "$HOME"/.cache/nim/libsds_* 2>/dev/null || true
# 3) libstatus.* (shared bin between make run and mobile-run)
rm -f "$GIT_ROOT"/.statusgo-build/build/bin/libstatus.* 2>/dev/null || true
rm -f "$GIT_ROOT"/vendor/status-go/build/bin/libstatus.* 2>/dev/null || true

echo "$KEY" > "$STATE"
