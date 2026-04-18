#!/usr/bin/env bash
# Build FFmpeg for Android arm64-v8a. Required by Qt 6.9 QtMultimedia's
# FFmpeg backend, which implements QCamera on Android (QR scanning).
set -eo pipefail

: "${FFMPEG_SRCDIR:?FFMPEG_SRCDIR must point to the ffmpeg-android-maker srclib}"
: "${ANDROID_SDK_ROOT:?ANDROID_SDK_ROOT must be set}"
: "${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT must be set}"

: "${ANDROID_API:?ANDROID_API must be set (exported by F-Droid metadata)}"

ANDROID_ABI=arm64-v8a

# Qt 6.9.2 references FF_PROFILE_* macros which only exist in FFMPEG 7.1.1
# TODO: we might have to upgrade ffmpeg when we bump QT version
FFMPEG_VERSION=7.1.1

# ffmpeg-android-maker reads _HOME, not _ROOT.
export ANDROID_SDK_HOME="$ANDROID_SDK_ROOT"
export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"

FAM_BUILD_SH="$FFMPEG_SRCDIR/scripts/ffmpeg/build.sh"
# Qt's plugin calls av_jni_set_java_vm in JNI_OnLoad and needs additional flags
# These flags match what we get out of the box from aqtinstall 
FAM_EXTRA_FLAGS="--enable-jni --enable-mediacodec --disable-indev=android_camera"
if ! grep -qF "$FAM_EXTRA_FLAGS" "$FAM_BUILD_SH"; then
  # This patching is necessary because these vars get reset for each ABI
  sed -i "s|\${EXTRA_BUILD_CONFIGURATION_FLAGS}|\${EXTRA_BUILD_CONFIGURATION_FLAGS} $FAM_EXTRA_FLAGS|" "$FAM_BUILD_SH"
fi

"$FFMPEG_SRCDIR/ffmpeg-android-maker.sh" --target-abis="$ANDROID_ABI" --android-api-level="$ANDROID_API" --source-tar="$FFMPEG_VERSION"

# Qt's FindFFmpeg.cmake expects ({lib,include} under FFMPEG_DIR).
STAGE_DIR="$HOME/ffmpeg/$ANDROID_ABI"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/lib" "$STAGE_DIR/include"
cp -a "$FFMPEG_SRCDIR/output/lib/$ANDROID_ABI/." "$STAGE_DIR/lib/"
cp -a "$FFMPEG_SRCDIR/output/include/$ANDROID_ABI/." "$STAGE_DIR/include/"
