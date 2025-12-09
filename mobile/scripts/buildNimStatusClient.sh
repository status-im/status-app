#!/usr/bin/env bash
set -ef pipefail
set -o xtrace

STATUS_DESKTOP=${STATUS_DESKTOP:-"../vendors/status-desktop"}
ARCH=${ARCH:-"amd64"}
ANDROID_ABI=${ANDROID_ABI:-"arm64-v8a"}
LIB_DIR=${LIB_DIR}
LIB_SUFFIX=${LIB_SUFFIX:-""}
OS=${OS:-"android"}
DEBUG=${DEBUG:-0}
FLAG_DAPPS_ENABLED=${FLAG_DAPPS_ENABLED:-0}
FLAG_CONNECTOR_ENABLED=${FLAG_CONNECTOR_ENABLED:-0}
FLAG_KEYCARD_ENABLED=${FLAG_KEYCARD_ENABLED:-0}
FLAG_SINGLE_STATUS_INSTANCE_ENABLED=${FLAG_SINGLE_STATUS_INSTANCE_ENABLED:-0}
FLAG_BROWSER_ENABLED=${FLAG_BROWSER_ENABLED:-0}

DESKTOP_VERSION=$(eval cd "$STATUS_DESKTOP" && git describe --tags --dirty="-dirty" --always)
STATUSGO_VERSION=$(eval cd "$STATUS_DESKTOP/vendor/status-go" && git describe --tags --dirty="-dirty" --always)

if [[ "$ARCH" == "x86_64" ]]; then
    CARCH="amd64"
else
    CARCH="$ARCH"
fi

if [[ "$OS" == "ios" ]]; then
    PLATFORM_SPECIFIC=(--app:staticlib -d:ios --os:ios)
else
    PLATFORM_SPECIFIC=(--app:lib --os:android -d:android -d:androidNDK -d:chronicles_sinks=textlines[logcat],textlines[nocolors,dynamic],textlines[file,nocolors] \
        --passL="-L$LIB_DIR" --passL="-lstatus" --passL="-lStatusQ$LIB_SUFFIX" --passL="-lDOtherSide$LIB_SUFFIX" --passL="-lqrcodegen" --passL="-lqzxing" --passL="-lssl_3" --passL="-lcrypto_3" --passL="-lstatus-keycard-qt" -d:taskpool)
fi

if [ -n "$USE_QML_SERVER" ]; then
  QML_SERVER_DEFINES="-d:USE_QML_SERVER=$USE_QML_SERVER"
else
  QML_SERVER_DEFINES=""
fi

echo "Building status-client for $ARCH using compiler: $CC"

cd "$STATUS_DESKTOP"
# build nim compiler with host env

# setting compile time feature flags
FEATURE_FLAGS=(
    FLAG_DAPPS_ENABLED=$FLAG_DAPPS_ENABLED
    FLAG_CONNECTOR_ENABLED=$FLAG_CONNECTOR_ENABLED
    FLAG_KEYCARD_ENABLED=$FLAG_KEYCARD_ENABLED
    FLAG_SINGLE_STATUS_INSTANCE_ENABLED=$FLAG_SINGLE_STATUS_INSTANCE_ENABLED
    FLAG_BROWSER_ENABLED=$FLAG_BROWSER_ENABLED
)

# app configuration defines
APP_CONFIG_DEFINES=(
    --outdir:./bin
    -d:KDF_ITERATIONS=3200
    -d:DESKTOP_VERSION="$DESKTOP_VERSION"
    -d:STATUSGO_VERSION="$STATUSGO_VERSION"
    -d:GIT_COMMIT="$(git log --pretty=format:'%h' -n 1)"
)

NIM_FLAGS=(
    --mm:orc
    -d:useMalloc
    --opt:size
    --cc:clang
    --cpu:"$CARCH"
    --noMain:on
    --clang.exe="$CC"
    --clang.linkerexe="$CC"
    --dynlibOverrideAll
    --nimcache:"$STATUS_DESKTOP"/nimcache
)

if [ "$DEBUG" -eq 1 ]; then
    NIM_FLAGS+=(-d:debug -d:nimTypeNames)
else
    NIM_FLAGS+=(-d:release -d:lto -d:production)
fi

# build status-client with feature flags
env "${FEATURE_FLAGS[@]}" ./vendor/nimbus-build-system/scripts/env.sh nim c "${PLATFORM_SPECIFIC[@]}" "${APP_CONFIG_DEFINES[@]}" ${QML_SERVER_DEFINES}  \
    "${NIM_FLAGS[@]}" \
    "$STATUS_DESKTOP"/src/nim_status_client.nim

mkdir -p "$LIB_DIR"

cp "$STATUS_DESKTOP/bin/libnim_status_client$LIB_EXT" "$LIB_DIR/libnim_status_client$LIB_EXT"
