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
FLAG_USE_KEYCARD_QT=${FLAG_USE_KEYCARD_QT:-$FLAG_USE_KEYCARD_QT}
FLAG_SINGLE_STATUS_INSTANCE_ENABLED=${FLAG_SINGLE_STATUS_INSTANCE_ENABLED:-0}
FLAG_BROWSER_ENABLED=${FLAG_BROWSER_ENABLED:-0}
FLAG_BUY_ENABLED=${FLAG_BUY_ENABLED:-1}
FLAG_SWAP_ENABLED=${FLAG_SWAP_ENABLED:-1}
FLAG_BRIDGE_ENABLED=${FLAG_BRIDGE_ENABLED:-1}

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
    PLATFORM_SPECIFIC=(--app:staticlib --os:android -d:android -d:androidNDK -d:chronicles_sinks=textlines[logcat],textlines[nocolors,dynamic],textlines[file,nocolors] \
        -d:taskpool)
fi

# AOT-compiled QML resources are handled by the AppResourcesPlugin.
# The plugin static lib is linked by cmake via mobile/wrapperApp/CMakeLists.txt.

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
    FLAG_USE_KEYCARD_QT=$FLAG_USE_KEYCARD_QT
    FLAG_BUY_ENABLED=$FLAG_BUY_ENABLED
    FLAG_SWAP_ENABLED=$FLAG_SWAP_ENABLED
    FLAG_BRIDGE_ENABLED=$FLAG_BRIDGE_ENABLED
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
    --opt:speed
    --cc:clang
    --cpu:"$CARCH"
    --noMain:on
    --clang.exe="$CC"
    --clang.linkerexe="$CC"
    --dynlibOverrideAll
    --nimcache:"$STATUS_DESKTOP"/nimcache
)

# On Android, the static lib is linked into Qt's shared MODULE (.so).
# Nim defaults to local-exec TLS model for staticlib, which is incompatible
# with shared libraries. Use global-dynamic TLS so the linker can relocate.
if [[ "$OS" == "android" ]]; then
    NIM_FLAGS+=(--passC:"-ftls-model=global-dynamic")
fi

if [ "$DEBUG" -eq 1 ]; then
    NIM_FLAGS+=(-d:debug -d:nimTypeNames)
else
    NIM_FLAGS+=(-d:release -d:production)
fi

# build status-client with feature flags
env "${FEATURE_FLAGS[@]}" ./vendor/nimbus-build-system/scripts/env.sh nim c "${PLATFORM_SPECIFIC[@]}" "${APP_CONFIG_DEFINES[@]}" ${QML_SERVER_DEFINES}  \
    -d:APP_AOT_COMPILE \
    "${NIM_FLAGS[@]}" \
    "$STATUS_DESKTOP"/src/nim_status_client.nim

mkdir -p "$LIB_DIR"

# On Android, Nim's --app:staticlib uses the host `ar` which can't handle
# cross-compiled ELF objects. Rebuild the archive using the NDK's llvm-ar.
if [[ "$OS" == "android" ]]; then
    NIMCACHE_DIR="$STATUS_DESKTOP/nimcache"
    ARCHIVE="$STATUS_DESKTOP/bin/libnim_status_client.a"
    echo "Rebuilding static archive with llvm-ar for Android..."
    rm -f "$ARCHIVE"
    set +f  # re-enable glob expansion (disabled by set -f at top)
    "$AR" rcs "$ARCHIVE" "$NIMCACHE_DIR"/*.o
    echo "Archive: $(du -h "$ARCHIVE" | cut -f1) with $(find "$NIMCACHE_DIR" -name '*.o' | wc -l | tr -d ' ') objects"
    set -f
fi

cp "$STATUS_DESKTOP/bin/libnim_status_client$LIB_EXT" "$LIB_DIR/libnim_status_client$LIB_EXT"
