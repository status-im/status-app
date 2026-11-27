#!/usr/bin/env bash
# Writes build-config.json (src/build_config.nim) from the STATUS_BUILD_* environment variables.
set -eo pipefail

[[ $# -ne 1 ]] && { echo 'write-build-config.sh <output_file>' >&2; exit 1; }

OUTPUT="${1}"

jq -n -S 'env | with_entries(
    select((.key | startswith("STATUS_BUILD_")) and .value != "")
    | .key |= ltrimstr("STATUS_BUILD_"))' > "${OUTPUT}"
chmod 644 "${OUTPUT}"
echo "Wrote $(jq length "${OUTPUT}") values to ${OUTPUT}"
