#!/usr/bin/env bash
set -eo pipefail

QT_VERSION="${QT_VERSION:-6.9.2}"

QT_MODULES=qtbase,qtdeclarative,qt5compat,qtmultimedia,qtshadertools,qtimageformats,qtwebview,qtscxml,qtsvg,qtconnectivity,qtwebsockets,qtpositioning,qtlottie,qtwebchannel
(cd "$QT_SRCDIR" && perl init-repository --module-subset="$QT_MODULES")

# Build Qt for host (required as cross-compilation toolchain for Android)
mkdir -p build_qt_host && cd build_qt_host

"$QT_SRCDIR"/configure \
    -prefix "$HOME/qt/$QT_VERSION/gcc_64" \
    -release \
    -opensource \
    -confirm-license \
    -nomake examples \
    -nomake tests \
    -- \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_MESSAGE_LOG_LEVEL=WARNING \
    -Wno-dev

cmake --build . --parallel "$(nproc)"
cmake --install . > /dev/null

cd "$BUILD_DIR"
rm -rf build_qt_host

# Build Qt for Android arm64-v8a
mkdir -p build_qt_android && cd build_qt_android

"$QT_SRCDIR"/configure \
    -prefix "$HOME/qt/$QT_VERSION/android_arm64_v8a" \
    -release \
    -opensource \
    -confirm-license \
    -nomake examples \
    -nomake tests \
    -platform android-clang \
    -android-ndk "$ANDROID_NDK_ROOT" \
    -android-sdk "$ANDROID_SDK_ROOT" \
    -qt-host-path "$HOME/qt/$QT_VERSION/gcc_64" \
    -android-abis arm64-v8a \
    -openssl-linked \
    -- \
    -DOPENSSL_ROOT_DIR="$HOME/openssl" \
    -DCMAKE_MESSAGE_LOG_LEVEL=WARNING \
    -Wno-dev

cmake --build . --parallel "$(nproc)"
cmake --install . > /dev/null

cd "$BUILD_DIR"
rm -rf build_qt_android

find "$QT_SRCDIR" -name "*.o" -delete 2>/dev/null || true
rm -rf "$QT_SRCDIR"/.git "$QT_SRCDIR"/qtwebengine 2>/dev/null || true
