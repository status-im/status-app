#!/usr/bin/env bash
set -eo pipefail

# Stable locale and timestamp for every cmake/ninja/moc/rcc run below.
export LC_ALL=C
export LANG=C
export SOURCE_DATE_EPOCH="$(git -C "$BUILD_DIR" log -1 --pretty=%ct 2>/dev/null || echo 0)"

QT_VERSION="${QT_VERSION:-6.9.2}"

QT_MODULES=qtbase,qtdeclarative,qt5compat,qtmultimedia,qtshadertools,qtimageformats,qtwebview,qtscxml,qtsvg,qtconnectivity,qtwebsockets,qtpositioning,qtlottie,qtwebchannel
(cd "$QT_SRCDIR" && perl init-repository --module-subset="$QT_MODULES")

# Remove de-registered and leftover submodules.
git -C "$QT_SRCDIR" submodule status | grep '^-' | while read -r _ path _; do
  rm -rf "${QT_SRCDIR:?}/$path"
done

# Strip .note.gnu.build-id from every .so and keep absolute paths out of them.
QT5_CMAKELISTS="$QT_SRCDIR/CMakeLists.txt"
if ! grep -q 'build-id=none' "$QT5_CMAKELISTS"; then
    sed -i '/^project(Qt$/,/^)$/{/^)$/a\
add_link_options("LINKER:--build-id=none")\
add_compile_options("-ffile-prefix-map=${CMAKE_SOURCE_DIR}=.")\
add_compile_options("-ffile-prefix-map=${CMAKE_BINARY_DIR}=.")\
add_compile_options("-ffile-prefix-map=$ENV{HOME}=.")
}' "$QT5_CMAKELISTS"
fi

# qmlcachegen's AOT codegen walks QHash containers and emits a different
# amount of code per run, so pin every Qt-internal QML module to bytecode only.
QT_QML_MACROS="$QT_SRCDIR/qtdeclarative/src/qml/Qt6QmlMacros.cmake"
if [ -f "$QT_QML_MACROS" ] && ! grep -q 'REPRODUCIBILITY_ONLY_BYTECODE' "$QT_QML_MACROS"; then
    sed -i '/MATCHES "-NOTFOUND\$"/,/endforeach()/{
/endforeach()/a\
    # REPRODUCIBILITY_ONLY_BYTECODE: skip AOT codegen, it is not deterministic.\
    get_target_property(_qmlcg_args ${target} QT_QMLCACHEGEN_ARGUMENTS)\
    if(NOT "--only-bytecode" IN_LIST _qmlcg_args)\
        list(APPEND _qmlcg_args "--only-bytecode")\
        set_target_properties(${target} PROPERTIES QT_QMLCACHEGEN_ARGUMENTS "${_qmlcg_args}")\
    endif()
}' "$QT_QML_MACROS"
fi

# Rewrite absolute paths embedded in compiled objects so rebuilders match.
QT_REPRO_CFLAGS="-ffile-prefix-map=${QT_SRCDIR}=. -ffile-prefix-map=${BUILD_DIR}=. -ffile-prefix-map=${HOME}=."

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
    -DCMAKE_C_FLAGS_INIT="$QT_REPRO_CFLAGS" \
    -DCMAKE_CXX_FLAGS_INIT="$QT_REPRO_CFLAGS" \
    -DCMAKE_UNITY_BUILD=OFF \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
    -DCMAKE_MESSAGE_LOG_LEVEL=WARNING \
    -Wno-dev

cmake --build . --parallel "$(nproc)"
cmake --install . > /dev/null

cd "$BUILD_DIR"
rm -rf build_qt_host

# Build Qt for Android arm64-v8a
mkdir -p build_qt_android && cd build_qt_android

: "${FFMPEG_DIR:?FFMPEG_DIR must point to the staged FFmpeg build (lib/, include/)}"

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
    -DFFMPEG_DIR="$FFMPEG_DIR" \
    -DFEATURE_ffmpeg=ON \
    -DQT_DEFAULT_MEDIA_BACKEND=ffmpeg \
    -DCMAKE_C_FLAGS_INIT="$QT_REPRO_CFLAGS" \
    -DCMAKE_CXX_FLAGS_INIT="$QT_REPRO_CFLAGS" \
    -DCMAKE_UNITY_BUILD=OFF \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
    -DCMAKE_MESSAGE_LOG_LEVEL=WARNING \
    -Wno-dev

cmake --build . --parallel "$(nproc)"
cmake --install . > /dev/null

# Without this, the ffmpeg multimedia plugin is built but
# cannot dlopen libav* at runtime, and QtMultimedia falls back to the legacy
# androidmediaplugin backend (breaking QCamera / QR scanning).
cp -av "$FFMPEG_DIR"/lib/*.so "$HOME/qt/$QT_VERSION/android_arm64_v8a/lib/"

cd "$BUILD_DIR"
rm -rf build_qt_android

find "$QT_SRCDIR" -name "*.o" -delete 2>/dev/null || true
rm -rf "$QT_SRCDIR"/.git "$QT_SRCDIR"/qtwebengine 2>/dev/null || true
