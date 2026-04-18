#!/usr/bin/env bash
#
# Build FFmpeg shared libraries for Android arm64-v8a via ffmpeg-android-maker.
# Required by Qt 6.9 QtMultimedia's FFmpeg backend (the backend that implements
# QCamera on Android). Without it, QtMultimedia falls back to the legacy
# Android backend, which does not configure the camera viewfinder region and
# breaks QR scanning (libgcam spams "Invalid input crop" every frame).
#
set -eo pipefail

: "${FFMPEG_SRCDIR:?FFMPEG_SRCDIR must point to the ffmpeg-android-maker srclib}"
: "${ANDROID_SDK_ROOT:?ANDROID_SDK_ROOT must be set}"
: "${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT must be set}"

ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
ANDROID_API="${ANDROID_API:-28}"

# ffmpeg-android-maker reads ANDROID_{SDK,NDK}_HOME, not _ROOT.
export ANDROID_SDK_HOME="$ANDROID_SDK_ROOT"
export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"

(
  cd "$FFMPEG_SRCDIR"
  ./ffmpeg-android-maker.sh \
    --target-abis="$ANDROID_ABI" \
    --android-api-level="$ANDROID_API"
)

# Qt's FindFFmpeg.cmake expects ${FFMPEG_DIR}/{lib,include} without an ABI
# subdir. ffmpeg-android-maker emits output/{lib,include}/<abi>/..., so stage
# a flat layout for Qt to consume.
STAGE_DIR="$HOME/ffmpeg/$ANDROID_ABI"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/lib" "$STAGE_DIR/include"
cp -a "$FFMPEG_SRCDIR/output/lib/$ANDROID_ABI/." "$STAGE_DIR/lib/"
cp -a "$FFMPEG_SRCDIR/output/include/$ANDROID_ABI/." "$STAGE_DIR/include/"

echo "FFmpeg staged at $STAGE_DIR"
ls -1 "$STAGE_DIR/lib"
