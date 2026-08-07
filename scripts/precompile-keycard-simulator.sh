#!/usr/bin/env bash
# Precompile keycard-simulator: nix JDK off-Windows; on Windows host javac (scoop).
set -euo pipefail

SRC_DIR="${1:?usage: $0 <keycard-simulator-dir>}"
SRC_DIR="$(cd "$SRC_DIR" && pwd)"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

is_windows() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

run_build() {
  # Host JDK may be 17; --release 11 keeps bytecode runnable on any JRE >= 11 (same as build.sh).
  local release="${JAVAC_RELEASE:-11}"
  (
    cd "$SRC_DIR"
    mkdir -p out/core
    echo "Compiling core (--release $release) ..."
    "$JAVAC_BIN" --release "$release" -cp "libs/common/*" -d out/core \
      src/im/status/keycardqt/sim/*.java
    local vdir v out
    local -a sources
    for vdir in versions/*/; do
      v="$(basename "$vdir")"
      [[ -d "${vdir}src" && -d "${vdir}libs" ]] || continue
      out="${vdir}out"
      mkdir -p "$out"
      echo "Compiling version $v (--release $release) ..."
      mapfile -d '' sources < <(find "${vdir}src" -name '*.java' -print0)
      "$JAVAC_BIN" --release "$release" \
        -cp "out/core;libs/common/*;${vdir}libs/*" -d "$out" \
        "${sources[@]}"
    done
  )
}

cd "$ROOT_DIR"

if is_windows; then
  if ! command -v javac >/dev/null 2>&1; then
    echo "ERROR: javac not found; run scripts/windows_build_setup.ps1" >&2
    exit 1
  fi
  JAVAC_BIN="$(command -v javac)"
  run_build
else
  export PATH="/nix/var/nix/profiles/default/bin:${HOME:-}/.nix-profile/bin:${PATH:-}"
  nix --extra-experimental-features 'nix-command flakes' shell .#jdk -c \
    bash -c "cd '$SRC_DIR' && ./build.sh"
fi

test -d "$SRC_DIR/out"
