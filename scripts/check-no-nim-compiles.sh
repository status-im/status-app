#!/usr/bin/env bash
#
# The root Makefile never invokes `nim` (issue 0017).
#
# Since issue 0017 every Nim compile belongs to the driver: the client
# (`nim app status.nims`), the Nim test suite (`nim tests status.nims`) and the
# Windows launcher (`nim windowsLauncher status.nims`). The Makefile survives
# for packaging, storybook, the QML/StatusQ checks, the interim mobile legs and
# CI helpers, and it CONSUMES the binary the driver produced.
#
# This asserts the invariant mechanically:
#
#   * no `nim c` / `nim e` — a Nim compile or a nimscript evaluation
#   * no `$(ENV_SCRIPT)`   — nimbus-build-system's compiler-environment wrapper
#   * no `NIM_PARAMS`      — the flag set lives in config.nims, for every platform
#
# A `nim <task> status.nims` dispatch is NOT a compile: it is the supported way
# for a packaging recipe to ask the driver for a binary. It is allowed, and the
# patterns below are written so it stays allowed.
#
# SCOPE: the ROOT Makefile only. `mobile/Makefile` still compiles the client for
# iOS/Android and joins the invariant at the mobile follow-on (PRD:
# 2026-07-09-nimble-owns-nim-compilation-prd.md, "Invariant scope").
#
# Usage:  scripts/check-no-nim-compiles.sh [makefile]
# Exit:   0 = invariant holds, 1 = a forbidden invocation is back.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
makefile="${1:-$repo_root/Makefile}"

if [[ ! -f $makefile ]]; then
  echo "check-no-nim-compiles: no such file: $makefile" >&2
  exit 1
fi

# Comments explain the invariant and must not trip it: drop everything from an
# unescaped '#' to end of line, then drop blank lines.
stripped="$(sed -e 's/[^\\]#.*$//' -e 's/^#.*$//' "$makefile" | grep -v '^[[:space:]]*$')"

fail=0
check() { # <description> <extended regex>
  local what="$1" re="$2" hits
  if hits="$(printf '%s\n' "$stripped" | grep -nE "$re" || true)"; [[ -n $hits ]]; then
    echo "FAIL: $makefile still carries $what:" >&2
    printf '%s\n' "$hits" >&2
    fail=1
  else
    echo "ok: $what — absent"
  fi
}

#           `nim c ...` at a word boundary; a `nim app status.nims` dispatch passes
check "a Nim compile (\`nim c\`)"            '(^|[^[:alnum:]_./-])nim[[:space:]]+c([[:space:]]|$)'
check "a nimscript eval (\`nim e\`)"         '(^|[^[:alnum:]_./-])nim[[:space:]]+e([[:space:]]|$)'
check "the NBS env-script wrapper"           '\$\(ENV_SCRIPT\)|ENV_SCRIPT[[:space:]]*[:?+]?='
check "NIM_PARAMS"                           'NIM_PARAMS'

if (( fail )); then
  echo >&2
  echo "The root Makefile must not compile Nim. Move the compile into a driver" >&2
  echo "task in status.nims and have the recipe call \`nim <task> status.nims\`." >&2
  exit 1
fi

echo "check-no-nim-compiles: $makefile is clean"
