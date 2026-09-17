#!/bin/sh
# Prints the 40-hex status-go pin from nim_status_client.nimble (or the manifest
# given as $1). Exits 1 when the requires line carries no revision (a file:// flip).
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
manifest=${1:-"$root/nim_status_client.nimble"}
pin=$(sed -n 's|^requires "https://github.com/status-im/status-go\.git#\([0-9a-f]\{40\}\)".*|\1|p' "$manifest" | head -n 1)
if [ -z "$pin" ]; then
  echo "status-go-pin.sh: no status-go revision in $manifest (a file:// flip, or no requires line)" >&2
  exit 1
fi
printf '%s\n' "$pin"
