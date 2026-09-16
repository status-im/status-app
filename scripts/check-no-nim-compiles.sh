#!/usr/bin/env bash
#
# The Makefiles never invoke a Nim compile.
#
# Every Nim compile belongs to the driver: the client (`./status app`), the
# Nim test suite (`./status tests`) and the Windows launcher
# (`./status windowsLauncher`). The Makefiles survive for packaging,
# storybook, the QML/StatusQ checks, the mobile legs and CI helpers, and they
# CONSUME the binary the driver produced.
#
# This asserts the invariant mechanically:
#
#   * no `nim c` / `nim compile` / `nim e` — a Nim compile or a nimscript eval
#   * no `$(ENV_SCRIPT)`   — nimbus-build-system's compiler-environment wrapper
#   * no `NIM_PARAMS`      — the flag set lives in config.nims, for every platform
#
# A driver dispatch (`./status <task>`, or `nim <task> <file>.nims`) is NOT a
# compile: it is the supported way for a packaging recipe to ask the driver for
# a binary. It is allowed, and the patterns below are written so it stays
# allowed.
#
# SCOPE: the Makefiles. The mobile client compile itself lives in
# mobile/scripts/buildNimStatusClient.sh, which is not checked here.
#
# Usage:  scripts/check-no-nim-compiles.sh [makefile...]
#         (default: Makefile and mobile/Makefile)
# Exit:   0 = invariant holds, 1 = a forbidden invocation is back.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
makefiles=("$@")
if (( ${#makefiles[@]} == 0 )); then
  makefiles=("$repo_root/Makefile" "$repo_root/mobile/Makefile")
fi

fail=0

check_makefile() { # <makefile>
  local makefile="$1"

  if [[ ! -f $makefile ]]; then
    echo "check-no-nim-compiles: no such file: $makefile" >&2
    exit 1
  fi

# Comments explain the invariant and must not trip it: blank out everything from
# an unescaped '#' to end of line. The capture group PRESERVES the character
# before the '#' (the old `[^\\]#` ate it), and blank lines are kept rather than
# filtered, so `grep -n` below reports the line numbers of the FILE — the numbers
# a reader is about to open an editor at.
  local stripped
  stripped="$(sed -e 's/\([^\\]\)#.*$/\1/' -e 's/^#.*$//' "$makefile")"

  check() { # <description> <extended regex>
    local what="$1" re="$2" hits
    if hits="$(printf '%s\n' "$stripped" | grep -nE "$re" || true)"; [[ -n $hits ]]; then
      echo "FAIL: $makefile still carries $what:" >&2
      printf '%s\n' "$hits" >&2
      fail=1
    else
      echo "ok: ${makefile#"$repo_root"/}: $what — absent"
    fi
  }

#           `nim c ...` / `nim compile ...` at a word boundary. A driver dispatch
#           (`./status app`, `nim libsdsAndroid …/statusgo.nims`) passes: the
#           trailing anchor demands the WHOLE word be the compile command.
  check "a Nim compile (\`nim c\`/\`nim compile\`)" \
                                              '(^|[^[:alnum:]_./-])nim[[:space:]]+(c|compile)([[:space:]]|$)'
  check "a nimscript eval (\`nim e\`)"         '(^|[^[:alnum:]_./-])nim[[:space:]]+e([[:space:]]|$)'
  check "the NBS env-script wrapper"           '\$\(ENV_SCRIPT\)|ENV_SCRIPT[[:space:]]*[:?+]?='
  check "NIM_PARAMS"                           'NIM_PARAMS'
}

for makefile in "${makefiles[@]}"; do
  check_makefile "$makefile"
done

if (( fail )); then
  echo >&2
  echo "A Makefile must not compile Nim. Move the compile into a driver task in" >&2
  echo "status.nims and have the recipe call \`./status <task>\`." >&2
  exit 1
fi

echo "check-no-nim-compiles: clean"
