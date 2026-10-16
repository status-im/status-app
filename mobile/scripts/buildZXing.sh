#!/usr/bin/env bash
# nim-qrscan's ZXing for the current mobile target; prints the archive path.
# iOS: copied into LIB_DIR, because the Nim client is a static lib and Status.pro
# links -lZXing. Android: the Nim client (.so) links it directly through
# -d:qrscanZxingLib, so it is only built.
set -euo pipefail

STATUS_DESKTOP=${STATUS_DESKTOP:?}
QRSCAN="$STATUS_DESKTOP/vendor/nim-qrscan"

case "${OS:?}" in
  ios)
    if [[ "${SDK:-iphonesimulator}" == "iphoneos" ]]; then
      TARGET=(ios)
    else
      TARGET=(ios-sim "${ARCH:?}")
    fi ;;
  android)
    TARGET=(android "${ANDROID_ABI:?}") ;;
  *)
    echo "buildZXing.sh: unsupported OS: $OS" >&2
    exit 2 ;;
esac

# build-zxing.sh brings its own toolchain settings (iOS sysroot/arch, the NDK
# toolchain file); the mobile build's compiler wrappers must not leak into CMake.
REL=$(env -u CC -u CXX -u CPATH -u SDKROOT bash "$QRSCAN/scripts/build-zxing.sh" "${TARGET[@]}" | tail -1)
SRC="$QRSCAN/$REL"
[[ -f "$SRC" ]] || { echo "buildZXing.sh: no archive at $SRC" >&2; exit 1; }

if [[ "$OS" == "ios" ]]; then
  mkdir -p "${LIB_DIR:?}"
  # Simulator and device builds share LIB_DIR: copy whenever the content
  # differs, never trust modification times.
  cmp -s "$SRC" "$LIB_DIR/libZXing.a" || cp "$SRC" "$LIB_DIR/libZXing.a"
  echo "$LIB_DIR/libZXing.a"
else
  echo "$SRC"
fi
