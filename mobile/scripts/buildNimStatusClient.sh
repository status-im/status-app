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
# A pinned statusgo store copy has no .git, so its version is the pin revision,
# read from the store entry's nimblemeta.json via the resolved nimble.paths. A
# developed checkout keeps `git describe`.
if [[ -z "${STATUSGO_VERSION:-}" ]]; then
    if [[ -d "$STATUS_DESKTOP/vendor/status-go/.git" || -f "$STATUS_DESKTOP/vendor/status-go/.git" ]] \
       && grep -sqx statusgo "$STATUS_DESKTOP/nimble.overlay" 2>/dev/null; then
        STATUSGO_VERSION=$(cd "$STATUS_DESKTOP/vendor/status-go" && ./scripts/version.sh)
    else
        STATUSGO_STORE=$(sed -n 's|^--path:"\(.*/pkgs2/statusgo-[^"/]*\)".*|\1|p' "$STATUS_DESKTOP/nimble.paths" 2>/dev/null | head -1)
        STATUSGO_VERSION=$(sed -n 's|.*"vcsRevision": "\([0-9a-f]*\)".*|\1|p' "$STATUSGO_STORE/nimblemeta.json" 2>/dev/null | cut -c1-10)
    fi
fi

if [[ "$ARCH" == "x86_64" ]]; then
    CARCH="amd64"
else
    CARCH="$ARCH"
fi

if [[ "$OS" == "ios" ]]; then
    PLATFORM_SPECIFIC=(--app:staticlib -d:ios --os:ios)
else
    PLATFORM_SPECIFIC=(--app:lib --os:android -d:android -d:androidNDK -d:lto -d:chronicles_sinks=textlines[logcat],textlines[file,nocolors] \
        --passL="-L$LIB_DIR" --passL="-lstatus_stub" --passL="-lStatusQ$LIB_SUFFIX" --passL="-lqrcodegen" --passL="-lssl_3" --passL="-lcrypto_3" --passL="-lstatus-keycard-qt" -d:taskpool)
fi

if [ -n "$USE_QML_SERVER" ]; then
  QML_SERVER_DEFINES="-d:USE_QML_SERVER=$USE_QML_SERVER"
else
  QML_SERVER_DEFINES=""
fi

echo "Building status-client for $ARCH using compiler: $CC"

cd "$STATUS_DESKTOP"

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
    # NOTE: -d:lto is intentionally NOT here. On the iOS --app:staticlib target,
    # LTO bitcode in the .a is mis-optimized at Xcode's final link, miscompiling
    # std/json %* JObject construction (CreateAccountRequest.toJson() -> empty {},
    # breaking account creation). LTO is re-added for Android below, where it works.
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
    #TODO: filter nimqml logs and then set -d:debug instead of -d:release
    NIM_FLAGS+=(-d:release -d:nimTypeNames)
elif [ "$PROFILE" -eq 1 ]; then
    NIM_FLAGS+=(-d:release -d:nimTypeNames -d:qmldebug -d:qmlDebugPort:${QML_DEBUG_PORT:-49152} --passC:-DQT_QML_DEBUG)
else
    NIM_FLAGS+=(-d:release -d:production)
fi

# Build status-client with feature flags.
#
# This is the one Nim compile the driver does not own (`./status app
# --os:android|ios` delegates the mobile leg to make), so it resolves the
# pinned compiler the same way `./status` does — `nimble path nim` reads
# nimble's store, never PATH — and asserts its version against the manifest's
# `requires "nim == X"`. STATUS_NIM overrides both.
PIN_VER=$(sed -n -E 's/^[[:space:]]*requires[[:space:]]+"nim[[:space:]]*==[[:space:]]*([^"[:space:]]+)".*/\1/p' \
    "$STATUS_DESKTOP/nim_status_client.nimble" 2>/dev/null | head -n 1 || true)
NIM=${STATUS_NIM:-}
if [[ -z "$NIM" ]]; then
    # `nimble path nim` lists every nim the store holds, so pick the pin.
    while IFS= read -r candidate; do
        [[ -x "$candidate/bin/nim" ]] || continue
        if [[ "$("$candidate/bin/nim" --version | head -n 1)" == "Nim Compiler Version $PIN_VER "* ]]; then
            NIM="$candidate/bin/nim"; break
        fi
    done < <(cd "$STATUS_DESKTOP" && nimble path nim 2>/dev/null || true)
    [[ -n "$NIM" ]] || NIM=$(command -v nim || true)
    if [[ -z "$NIM" ]]; then
        echo "ERROR: no Nim $PIN_VER. Run \`./status app\` in $STATUS_DESKTOP first." 1>&2
        exit 1
    fi
fi
NIM_VER=$("$NIM" --version | head -n 1 | sed -n -E 's/^Nim Compiler Version ([^ ]+).*/\1/p')
if [[ -n "$PIN_VER" && "$NIM_VER" != "$PIN_VER" ]]; then
    echo "ERROR: $NIM is Nim $NIM_VER, the manifest pins $PIN_VER." 1>&2
    echo "Re-resolve with \`nimble setup\`; STATUS_NIM=<path> overrides this check." 1>&2
    exit 1
fi

env "${FEATURE_FLAGS[@]}" "$NIM" c "${PLATFORM_SPECIFIC[@]}" "${APP_CONFIG_DEFINES[@]}" ${QML_SERVER_DEFINES}  \
    "${NIM_FLAGS[@]}" \
    "$STATUS_DESKTOP"/src/nim_status_client.nim

mkdir -p "$LIB_DIR"

cp "$STATUS_DESKTOP/bin/libnim_status_client$LIB_EXT" "$LIB_DIR/libnim_status_client$LIB_EXT"
