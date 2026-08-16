#!/usr/bin/env bash
# Used via `go build -toolexec`. cgo bakes sha256(importPath)[:6] into every
# generated symbol, so derive that path from source instead of the $WORK dir.

set -euo pipefail

TOOL="$1"
shift

TOOL_NAME="$(basename "$TOOL")"

# status-go sets its own -ldflags, so inject -s -w -buildid= here instead.
# cmd/link is last-wins on repeated flags, so drop existing values first.
if [[ "$TOOL_NAME" == "link" ]]; then
  new_args=()
  skip_next=false
  injected_buildid=false
  for arg in "$@"; do
    if $skip_next; then skip_next=false; continue; fi
    if [[ "$arg" == "-buildid" ]]; then
      skip_next=true
      continue
    elif [[ "$arg" == -buildid=* || "$arg" == "-s" || "$arg" == "-w" ]]; then
      continue
    fi
    new_args+=("$arg")
  done
  exec "$TOOL" -s -w -buildid= "${new_args[@]}"
fi

if [[ "$TOOL_NAME" != "cgo" ]]; then
  exec "$TOOL" "$@"
fi

# Collect user-supplied .go inputs; Go's own _cgo_*.go live in $WORK and vary.
inputs=()
for arg in "$@"; do
  if [[ "$arg" == *.go && -f "$arg" ]]; then
    base=$(basename "$arg")
    if [[ "$base" != _cgo_* ]]; then
      inputs+=("$arg")
    fi
  fi
done

# Nothing to derive from, pass through.
if (( ${#inputs[@]} == 0 )); then
  exec "$TOOL" "$@"
fi

if command -v sha256sum >/dev/null 2>&1; then
  SHA256="sha256sum"
else
  SHA256="shasum -a 256"
fi

# Order-independent file-set hash: hash each file, sort, hash again. Go passes
# these files in a different order per build for some packages.
det=$(
  for f in "${inputs[@]}"; do
    $SHA256 < "$f"
  done | sort | $SHA256 | awk '{print $1}' | cut -c1-16
)
new_importpath="reprodpkg-${det}"

# Rebuild args, replacing the -importpath value in either accepted form.
new_args=()
take_next=false
for arg in "$@"; do
  if $take_next; then
    new_args+=("$new_importpath")
    take_next=false
  elif [[ "$arg" == "-importpath" ]]; then
    new_args+=("$arg")
    take_next=true
  elif [[ "$arg" == -importpath=* ]]; then
    new_args+=("-importpath=${new_importpath}")
  else
    new_args+=("$arg")
  fi
done

exec "$TOOL" "${new_args[@]}"
