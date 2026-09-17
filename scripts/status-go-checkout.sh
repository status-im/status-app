#!/bin/sh
# Materialises the pinned status-go revision as a git checkout in <dir>
# (default: .statusgo-src at the repo root) and prints the directory.
# The upstream URL is hardcoded: nothing here fetches from a PR-supplied remote.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
dir=${1:-"$root/.statusgo-src"}
upstream=https://github.com/status-im/status-go.git

pin=$("$root/scripts/status-go-pin.sh")

if [ -d "$dir/.git" ] && [ "$(git -C "$dir" rev-parse --verify --quiet HEAD 2>/dev/null || true)" = "$pin" ]; then
  printf '%s\n' "$dir"
  exit 0
fi

mkdir -p "$dir"
[ -d "$dir/.git" ] || git init -q "$dir"
echo "status-go-checkout.sh: fetching status-go $pin into $dir" >&2
git -C "$dir" fetch -q --depth 1 "$upstream" "$pin"
git -C "$dir" checkout -q FETCH_HEAD
printf '%s\n' "$dir"
