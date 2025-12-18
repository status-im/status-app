#!/usr/bin/env bash
set -eo pipefail

CWD=$(realpath "$(dirname "$0")")

ARCH=${ARCH:-amd64}
SDK=${SDK:-iphonesimulator}
BUILD_DIR=${BUILD_DIR:-"$CWD/../build"}
BUILD_TYPE=${BUILD_TYPE:-"apk"}
BUILD_VARIANT=${BUILD_VARIANT:-"release"}

QMAKE_BIN="${QMAKE:-qmake}"
QMAKE_CONFIG=("CONFIG+=device" "CONFIG+=release")

# Derive names from variant: pr -> StatusPR, release -> Status
OUTPUT_NAME="Status"
[[ "$BUILD_VARIANT" == "pr" ]] && OUTPUT_NAME="StatusPR"

echo "Building $OUTPUT_NAME for ${OS}, variant: ${BUILD_VARIANT}"

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

STATUS_DESKTOP=${STATUS_DESKTOP:-"../vendors/status-desktop"}
VERSION=$(cd "$STATUS_DESKTOP" && git describe --tags --always | cut -d- -f1 | cut -d. -f1-3 | sed 's/^v//')
BUILD_VERSION="${CHANGE_ID:+${CHANGE_ID}.}$(($(date +%s) / 60))"

echo "Version: $VERSION, build: $BUILD_VERSION"

if [[ "${OS}" == "android" ]]; then
  [[ -z "${JAVA_HOME}" ]] && { echo "JAVA_HOME is not set"; exit 1; }

  # Export BUILD_VARIANT for build.gradle to pick up
  export BUILD_VARIANT

  "$QMAKE_BIN" "$CWD/../wrapperApp/Status.pro" "${QMAKE_CONFIG[@]}" -spec android-clang \
    ANDROID_ABIS="${ANDROID_ABI:-arm64-v8a}" VERSION="$VERSION" -after

  make -j"$(nproc)" apk_install_target

  androiddeployqt \
    --input "$BUILD_DIR/android-${OUTPUT_NAME}-deployment-settings.json" \
    --output "$BUILD_DIR/android-build" \
    --android-platform android-35 \
    --verbose --aux-mode

  # Copy custom Android files, preserve Qt-generated libs.xml
  cp "$CWD/../android/qt${QT_MAJOR}"/{AndroidManifest.xml,build.gradle,settings.gradle,gradle.properties} "$BUILD_DIR/android-build/"
  rsync -a --exclude='libs.xml' "$CWD/../android/qt${QT_MAJOR}/res/" "$BUILD_DIR/android-build/res/" 2>/dev/null || true
  rsync -a "$CWD/../android/qt${QT_MAJOR}/src/" "$BUILD_DIR/android-build/src/" 2>/dev/null || true

  cd "$BUILD_DIR/android-build"

  # Build: aab -> bundle, apk -> assemble
  TASK="assemble"; [[ "$BUILD_TYPE" == "aab" ]] && TASK="bundle"
  gradle "${TASK}Release" --no-daemon

  OUTPUT_FILE="build/outputs/apk/release/android-build-release.apk"
  [[ "$BUILD_TYPE" == "aab" ]] && OUTPUT_FILE="build/outputs/bundle/release/android-build-release.aab"
  [[ ! -f "$OUTPUT_FILE" ]] && { echo "Error: $OUTPUT_FILE not found"; exit 1; }

  BIN_DIR=${BIN_DIR:-"$CWD/../bin/android/qt6"}
  mkdir -p "$BIN_DIR"
  cp "$OUTPUT_FILE" "$BIN_DIR/${OUTPUT_NAME}.${BUILD_TYPE}"
  echo "Build succeeded: $BIN_DIR/${OUTPUT_NAME}.${BUILD_TYPE}"

else
  "$QMAKE_BIN" "$CWD/../wrapperApp/Status.pro" "${QMAKE_CONFIG[@]}" -spec macx-ios-clang CONFIG+="$SDK" VERSION="$VERSION" -after

  XCODE_FLAGS=(-configuration Release -sdk "$SDK" -arch "$ARCH" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO CURRENT_PROJECT_VERSION="$BUILD_VERSION")
  BIN_DIR=${BIN_DIR:-"$CWD/../bin/ios"}

  xcodebuild "${XCODE_FLAGS[@]}" -target "Qt Preprocess" | xcbeautify
  xcodebuild "${XCODE_FLAGS[@]}" -target "$OUTPUT_NAME" install DSTROOT="$BIN_DIR" INSTALL_PATH="/" TARGET_BUILD_DIR="$BIN_DIR" | xcbeautify

  [[ ! -e "$BIN_DIR/${OUTPUT_NAME}.app/Info.plist" ]] && { echo "Build failed"; exit 1; }

  echo "Build succeeded: $BIN_DIR/${OUTPUT_NAME}.app"
fi
