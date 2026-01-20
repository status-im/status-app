#!/usr/bin/env bash
set -eou pipefail

QT_VERSION="${QT_VERSION:-6.9.2}"
QT_BASE="$HOME/qt/$QT_VERSION"
ANDROID_ABI="arm64-v8a"
ANDROID_API="${ANDROID_API:-28}"

if [[ -z "${ANDROID_NDK_ROOT:-}" ]]; then
    echo "Error: ANDROID_NDK_ROOT is not set" >&2
    exit 1
fi

if [[ -z "${JAVA_HOME:-}" ]]; then
    JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which javac)")")")"
    export JAVA_HOME
fi

NDK_TOOLCHAIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64"

export QT_HOST_PATH="$QT_BASE/gcc_64"
export QTDIR="$QT_BASE/android_arm64_v8a"
export CMAKE_PREFIX_PATH="$QT_BASE/android_arm64_v8a"
export QMAKE="$QT_BASE/android_arm64_v8a/bin/qmake"
export QT_ANDROID_DIR="$QT_BASE/android_arm64_v8a/src/android/java"
export ANDROID_ABI ANDROID_API
export PATH="$QT_BASE/gcc_64/bin:$QT_BASE/android_arm64_v8a/bin:$NDK_TOOLCHAIN/bin:$HOME/go/bin:$PATH"

cd "$BUILD_DIR"

go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.1

ulimit -n 65536 || true
export USE_SYSTEM_NIM=1
export NIM_SDS_SOURCE_DIR="$BUILD_DIR/vendor/nim-sds"

make deps

make -C mobile apk-fdroid BUILD_VARIANT=release ARCH=arm64 V=3
