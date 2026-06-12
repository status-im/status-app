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
PROFILE=${PROFILE:-0}
FLAG_DAPPS_ENABLED=${FLAG_DAPPS_ENABLED:-0}
FLAG_CONNECTOR_ENABLED=${FLAG_CONNECTOR_ENABLED:-0}
FLAG_KEYCARD_ENABLED=${FLAG_KEYCARD_ENABLED:-0}
FLAG_SINGLE_STATUS_INSTANCE_ENABLED=${FLAG_SINGLE_STATUS_INSTANCE_ENABLED:-0}
FLAG_BROWSER_ENABLED=${FLAG_BROWSER_ENABLED:-0}
FLAG_BUY_ENABLED=${FLAG_BUY_ENABLED:-1}
FLAG_SWAP_ENABLED=${FLAG_SWAP_ENABLED:-1}
FLAG_BRIDGE_ENABLED=${FLAG_BRIDGE_ENABLED:-1}

BUNDLE_IDENTIFIER=${BUNDLE_IDENTIFIER:-"app.status.mobile"}
DESKTOP_VERSION=$(cd "$STATUS_DESKTOP" && ./scripts/version.sh)
STATUSGO_VERSION=$(cd "$STATUS_DESKTOP/vendor/status-go" && ./scripts/version.sh)

if [[ "$ARCH" == "x86_64" ]]; then
    CARCH="amd64"
else
    CARCH="$ARCH"
fi

if [[ "$OS" == "ios" ]]; then
    PLATFORM_SPECIFIC=(--app:staticlib -d:ios --os:ios)
else
    PLATFORM_SPECIFIC=(--app:lib --os:android -d:android -d:androidNDK -d:chronicles_sinks=textlines[logcat],textlines[file,nocolors] \
        --passL="-L$LIB_DIR" --passL="-lstatus_stub" --passL="-lStatusQ$LIB_SUFFIX" --passL="-lDOtherSide$LIB_SUFFIX" --passL="-lqrcodegen" --passL="-lssl_3" --passL="-lcrypto_3" --passL="-lstatus-keycard-qt" -d:taskpool)
fi

if [ -n "$USE_QML_SERVER" ]; then
  QML_SERVER_DEFINES="-d:USE_QML_SERVER=$USE_QML_SERVER"
else
  QML_SERVER_DEFINES=""
fi

echo "Building status-client for $ARCH using compiler: $CC"

cd "$STATUS_DESKTOP"

# --- seaqt Qt pkg-config wiring (Android + iOS) ----------------------------
# seaqt discovers Qt at nim-compile time via gorge("pkg-config Qt6Core").
# Neither mobile Qt kit ships .pc files (only .prl), so we generate them from
# the kit's .prl via prl-to-pc, put the in-repo .pcwrap on PATH (it forces
# --define-prefix and, when PKG_CONFIG_ARCH is set, rewrites bare module names
# to the arch-suffixed package names), and point PKG_CONFIG_PATH at the output.
#   - Android: libs are arch-suffixed (libQt6Core_arm64-v8a.so) → .pc named
#     Qt6Core_<abi>.pc, so we set PKG_CONFIG_ARCH for the wrapper rewrite.
#   - iOS: modules are frameworks (QtCore.framework) → .pc named Qt6Core.pc
#     directly, so NO arch rewrite; cflags use -F/-I framework Headers. The nim
#     build is --app:staticlib (no link), so framework *linking* is the Xcode
#     app project's job; only the framework cflags matter here.
# prl-to-pc is built from the vendor/prl-to-pc submodule by `make update` (host env).
if [[ "$OS" == "android" || "$OS" == "ios" ]]; then
    PRL_TO_PC_BIN="${PRL_TO_PC_BIN:-$STATUS_DESKTOP/vendor/prl-to-pc/prl_to_pc}"
    if [[ "$OS" == "android" ]]; then
        PC_TAG="$ANDROID_ABI"; PC_MARKER="Qt6Core_${ANDROID_ABI}.pc"
    else
        PC_TAG="ios"; PC_MARKER="Qt6Core.pc"
    fi
    QT_PC_DIR="$STATUS_DESKTOP/mobile/build/qt-pkgconfig/$PC_TAG"

    if [[ ! -x "$PRL_TO_PC_BIN" ]]; then
        echo "ERROR: prl-to-pc not found at $PRL_TO_PC_BIN — run 'make update' first." >&2
        exit 1
    fi
    # Generate once per kit (keyed on the Core .pc existing).
    if [[ ! -f "$QT_PC_DIR/$PC_MARKER" ]]; then
        echo "Generating Qt .pc files for $PC_TAG from $QT_DIR"
        mkdir -p "$QT_PC_DIR"
        "$PRL_TO_PC_BIN" "$QT_DIR/lib" "$QT_PC_DIR" "$QT_DIR" "$QT_DIR/bin"
    fi

    [[ "$OS" == "android" ]] && export PKG_CONFIG_ARCH="$ANDROID_ABI"
    export PKG_CONFIG_PATH="$QT_PC_DIR${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export PATH="$STATUS_DESKTOP/.pcwrap:$PATH"
fi
# ---------------------------------------------------------------------------

# build nim compiler with host env

# setting compile time feature flags
FEATURE_FLAGS=(
    FLAG_DAPPS_ENABLED=$FLAG_DAPPS_ENABLED
    FLAG_CONNECTOR_ENABLED=$FLAG_CONNECTOR_ENABLED
    FLAG_KEYCARD_ENABLED=$FLAG_KEYCARD_ENABLED
    FLAG_SINGLE_STATUS_INSTANCE_ENABLED=$FLAG_SINGLE_STATUS_INSTANCE_ENABLED
    FLAG_BROWSER_ENABLED=$FLAG_BROWSER_ENABLED
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
    -d:PUSH_TOPIC="$BUNDLE_IDENTIFIER"
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
elif [ "$PROFILE" -eq 1 ]; then
    NIM_FLAGS+=(-d:release -d:nimTypeNames)
else
    NIM_FLAGS+=(-d:release -d:production)
fi

# build status-client with feature flags
env "${FEATURE_FLAGS[@]}" ./vendor/nimbus-build-system/scripts/env.sh nim c "${PLATFORM_SPECIFIC[@]}" "${APP_CONFIG_DEFINES[@]}" ${QML_SERVER_DEFINES}  \
    "${NIM_FLAGS[@]}" \
    "$STATUS_DESKTOP"/src/nim_status_client.nim

mkdir -p "$LIB_DIR"

cp "$STATUS_DESKTOP/bin/libnim_status_client$LIB_EXT" "$LIB_DIR/libnim_status_client$LIB_EXT"
