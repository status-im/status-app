#!/usr/bin/env bash

SDK=${SDK:-"iphonesimulator"}
XCODE_SDK_PATH=$(xcrun --sdk "$SDK" --show-sdk-path)
CLANG=$(xcrun --sdk "$SDK" --find clang)
IOS_TARGET=${IOS_TARGET:-26}
ARCH=${ARCH:-"amd64"}

EXTRA_ARGS=()

if [[ "$ARCH" == "amd64" ]]; then
    CARCH="x86_64"
elif [[ "$ARCH" == "arm64" ]]; then
    CARCH="arm64"
elif [[ "$ARCH" == "arm" ]]; then
    CARCH="armv7"
elif [[ "$ARCH" == "386" ]]; then
    CARCH="i386"
else
    CARCH="$ARCH"
fi

if [[ "$SDK" == "iphoneos" ]]; then
    EXTRA_ARGS=(-fembed-bitcode -miphoneos-version-min="$IOS_TARGET")
    TARGET="$CARCH-apple-ios$IOS_TARGET"
elif [[ "$SDK" == "iphonesimulator" ]]; then
    EXTRA_ARGS=(-fembed-bitcode -mios-simulator-version-min="$IOS_TARGET")
    TARGET="$CARCH-apple-ios$IOS_TARGET-simulator"
elif [[ "$SDK" == "macosx" ]]; then
    IOS_TARGET=14
    TARGET="$CARCH-apple-ios$IOS_TARGET-macabi"
    if [[ "$ARCH" == "arm64" ]]; then
        EXTRA_ARGS=(-fembed-bitcode)
    fi
fi

exec "$CLANG" -target "$TARGET" "${EXTRA_ARGS[@]}" -isysroot "$XCODE_SDK_PATH" "$@"