#!/usr/bin/env bash

ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-""}
ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT:-""}
ANDROID_API=${ANDROID_API:-28}
ARCH=${ARCH:-"arm64"}

HOST_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
CLANG="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_OS}-x86_64/bin/clang"
SYSROOT="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_OS}-x86_64/sysroot"

TARGET_SUFFIX=""

if [[ "$ARCH" == "amd64" ]]; then
    CARCH="x86_64"
elif [[ "$ARCH" == "arm64" ]]; then
    CARCH="aarch64"
elif [[ "$ARCH" == "arm" ]]; then
    CARCH="armv7a"
    TARGET_SUFFIX="eabi"
elif [[ "$ARCH" == "386" ]]; then
    CARCH="i686"
else
    CARCH="$ARCH"
fi

TARGET="$CARCH-linux-android${TARGET_SUFFIX}${ANDROID_API}"
EXTRA_ARGS="-fembed-bitcode"

LINK_PAGE_SIZE_ARGS="-Wl,-z,max-page-size=16384"

exec "$CLANG" --target="$TARGET" "$EXTRA_ARGS" --sysroot="$SYSROOT" "${LINK_PAGE_SIZE_ARGS}" -v "$@"