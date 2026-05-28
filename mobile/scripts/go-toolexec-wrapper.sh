#!/usr/bin/env bash
# go-toolexec-wrapper.sh
#
# Wraps invocations of Go toolchain binaries (cgo, compile, link, asm, ...)
# triggered by `go build -toolexec=THIS_SCRIPT`. For everything except cgo it
# is a pure pass-through. For cgo it rewrites the -importpath argument so the
# value is derived from the SHA-256 of the sorted input .go file contents,
# making it deterministic across builds.
#
# WHY: cgo bakes a per-package hash prefix into every generated symbol
# (_cgo_<hash>_Cfunc_X, _cgoexp_<hash>_X). That hash is sha256(importPath)[:6]
# (cmd/cgo/main.go). Go's build system constructs -importpath from values that
# can include $WORK temp-dir paths, so the hash changes per invocation, which
# cascades into different .text addresses, different .data.rel.ro pclntab
# layout, and a ~32-byte oscillation in libstatus.so size that no amount of
# -trimpath / -buildvcs=false / -ldflags fixes.
#
# By replacing -importpath with reprodpkg-<sha16-of-source-contents>, the
# input to cgo's hash is purely a function of source code → reproducible.

set -euo pipefail

TOOL="$1"
shift

if [[ "$(basename "$TOOL")" != "cgo" ]]; then
  exec "$TOOL" "$@"
fi

# Collect the user-supplied .go input files. Exclude Go's own auto-generated
# _cgo_*.go files (those live in $WORK and have volatile content).
inputs=()
for arg in "$@"; do
  if [[ "$arg" == *.go && -f "$arg" ]]; then
    base=$(basename "$arg")
    if [[ "$base" != _cgo_* ]]; then
      inputs+=("$arg")
    fi
  fi
done

# No inputs to derive from → fall back to pass-through.
if (( ${#inputs[@]} == 0 )); then
  exec "$TOOL" "$@"
fi

if command -v sha256sum >/dev/null 2>&1; then
  SHA256="sha256sum"
else
  SHA256="shasum -a 256"
fi

# Sort by basename for stable concatenation order, then hash file contents.
det=$(printf '%s\n' "${inputs[@]}" | sort -t/ -k99,99 | xargs cat | $SHA256 | awk '{print $1}' | cut -c1-16)
new_importpath="reprodpkg-${det}"

# Rebuild args, replacing -importpath value. Support both `-importpath X` and
# `-importpath=X` forms.
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
