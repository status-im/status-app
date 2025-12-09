#!/usr/bin/env bash
set -ef pipefail

ARCH=${ARCH:-"x86_64"}
# Use $QMAKE if set, otherwise fall back to system qmake
QMAKE_BIN=${QMAKE:-qmake}
QTDIR=${QTDIR:-$($QMAKE_BIN -query QT_INSTALL_PREFIX)}
OS=${OS:-ios}
ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT:-""}

STATIC_LIB=ON
CMAKE_TOOLCHAIN_FILE=""
COMMON_CMAKE_CONFIG=()

if [[ "$OS" == "ios" ]]; then
    if [[ "$ARCH" == "x86_64" ]]; then
        SDK="iphonesimulator"
    else
        SDK="iphoneos"
    fi
    SYSTEM_NAME="iOS"
    COMMON_CMAKE_CONFIG+=(
        -DCMAKE_OSX_ARCHITECTURES:STRING="$ARCH"
        -DCMAKE_OSX_SYSROOT="$SDK"
        -DCMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET=12.0
    )
elif [[ "$OS" == "android" ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
        ANDROID_ABI="arm64-v8a"
    elif [[ "$ARCH" == "arm" ]]; then
        ANDROID_ABI="armeabi-v7a"
    fi
    SYSTEM_NAME="Android"
    STATIC_LIB=OFF
    CMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake"
    COMMON_CMAKE_CONFIG+=(
        -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE"
        -DANDROID_ABI:STRING="$ANDROID_ABI"
    )
else
    echo "Unknown OS: $OS"
    exit 1
fi

COMMON_CMAKE_CONFIG+=(
    -DCMAKE_SYSTEM_NAME:STRING="$SYSTEM_NAME"
    -DCMAKE_FIND_ROOT_PATH:STRING="$QTDIR"
    -DCMAKE_BUILD_TYPE=Release
)

# Add Android-specific flags only for Android
if [[ "$OS" == "android" ]]; then
    COMMON_CMAKE_CONFIG+=(-DANDROID_PLATFORM=android-35)
fi

printf 'COMMON_CMAKE_CONFIG: %s\n' "${COMMON_CMAKE_CONFIG[@]}"
