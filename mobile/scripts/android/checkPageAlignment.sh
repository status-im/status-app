#!/usr/bin/env bash
# Fails if any .so in the given directory has a LOAD segment aligned below 16 KB.
# Google Play rejects apps targeting Android 15+ that ship such libraries.
set -eo pipefail

LIBS_DIR=${1:?usage: $0 <libs-dir>}
MIN_ALIGN=$((0x4000))

READELF=$(find "${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT is not set}/toolchains/llvm/prebuilt" -name llvm-readelf -path '*/bin/*' | head -n 1)
[[ -x "$READELF" ]] || { echo "llvm-readelf not found in ANDROID_NDK_ROOT"; exit 1; }

FAILED=0
while IFS= read -r -d '' lib; do
  for align in $("$READELF" -lW "$lib" | awk '$1 == "LOAD" { print $NF }'); do
    if (( align < MIN_ALIGN )); then
      echo "Error: $(basename "$lib") has LOAD alignment $align (< 16 KB)"
      FAILED=1
      break
    fi
  done
done < <(find "$LIBS_DIR" -name '*.so' -print0)

(( FAILED == 0 )) || exit 1
echo "All libraries in $LIBS_DIR are 16 KB page aligned"
