#!/usr/bin/env bash
# Read Go build metadata; hidden libtkl symbols are not a public capability API.
set -euo pipefail
library="${1:?Supply the status-go library}"
metadata="$(go version -m "$library")"
printf '%s\n' "$metadata" | awk '
  $1 == "build" && $2 ~ /^-tags=/ {
    sub(/^.*-tags=/, "")
    gsub(/"/, "")
    n = split($0, tags, /[,[:space:]]+/)
    for (i = 1; i <= n; i++) if (tags[i] == "tkl") found = 1
  }
  END { exit !found }
'
