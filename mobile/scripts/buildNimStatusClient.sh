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
# Pinned statusgo (issue 0010): the store/scratch copy has no .git, so the
# version is the pin revision, read from the store entry's nimblemeta.json
# via the resolved nimble.paths. A developed checkout keeps `git describe`.
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
    -d:lto
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
    NIM_FLAGS+=(-d:release -d:nimTypeNames)
else
    NIM_FLAGS+=(-d:release -d:production)
fi

# Build status-client with feature flags.
#
# `nim` comes from PATH, and PATH is what carries the pinned compiler (issue
# 0018): nimble injects <store>/pkgs2/nim-<ver>-<checksum>/bin into the
# environment of its tasks and hooks, and a `source ./env.sh` shell (the
# documented bootstrap, BUILDING.md) does the same for a bare `make
# mobile-build` — so this compile uses exactly the compiler
# nim_status_client.nimble pins, with no compiler on the machine. This used to
# go through nimbus-build-system's scripts/env.sh, which — with USE_SYSTEM_NIM=1,
# the only mode this repo ever ran — did nothing but echo "[using system Nim]"
# and exec the same `nim`. NBS is gone; so is the wrapper.
#
# "comes from PATH" is a claim, so ASSERT it (issue 0018 review, R3): this is
# the one Nim compile the driver does not own — `nim app status.nims
# --os:android|ios` delegates the mobile leg to make — so it carries the same
# guard the driver's guardPinnedCompiler() applies to the client, the test suite
# and the Windows launcher. The pin is read from the same two files the driver
# reads (never hardcoded): the manifest's `requires "nim == X"` and
# nimble.lock's packages.nim.checksums.sha1, which together name the store
# entry pkgs2/nim-<version>-<checksum>. STATUS_NIM deliberately overrides it.
NIM=${STATUS_NIM:-nim}
if [[ -z "${STATUS_NIM:-}" ]]; then
    NIM_EXE=$(command -v nim || true)
    if [[ -z "$NIM_EXE" ]]; then
        echo "ERROR: no \`nim\` on PATH. Bootstrap the shell first: nimble setup && source ./env.sh" 1>&2
        exit 1
    fi
    PIN_VER=$(sed -n -E 's/^[[:space:]]*requires[[:space:]]+"nim[[:space:]]*==[[:space:]]*([^"[:space:]]+)".*/\1/p' \
        "$STATUS_DESKTOP/nim_status_client.nimble" 2>/dev/null || true)
    # [{] / [}] rather than escaped braces: an ERE brace is an interval operator.
    PIN_SHA=$(sed -n -E '/"nim"[[:space:]]*:[[:space:]]*[{]/,/[}]/{s/.*"sha1"[[:space:]]*:[[:space:]]*"([0-9a-f]+)".*/\1/p;}' \
        "$STATUS_DESKTOP/nimble.lock" 2>/dev/null || true)
    if [[ -n "$PIN_VER" ]]; then
        if [[ -n "$PIN_SHA" ]]; then
            WANT="/pkgs2/nim-$PIN_VER-$PIN_SHA/"
        else
            WANT="/pkgs2/nim-$PIN_VER-"
        fi
        if [[ "$NIM_EXE" != *"$WANT"* ]]; then
            echo "ERROR: the Nim about to compile the client is NOT the pinned compiler." 1>&2
            echo "  running: $NIM_EXE" 1>&2
            echo "  pinned:  <store>${WANT}bin/nim   (nim_status_client.nimble: requires \"nim == $PIN_VER\")" 1>&2
            echo "Bootstrap the shell so the pin wins the PATH race:" 1>&2
            echo "  nimble setup && source ./env.sh" 1>&2
            echo "STATUS_NIM=<path> deliberately overrides this check." 1>&2
            exit 1
        fi
    fi
fi

env "${FEATURE_FLAGS[@]}" "$NIM" c "${PLATFORM_SPECIFIC[@]}" "${APP_CONFIG_DEFINES[@]}" ${QML_SERVER_DEFINES}  \
    "${NIM_FLAGS[@]}" \
    "$STATUS_DESKTOP"/src/nim_status_client.nim

mkdir -p "$LIB_DIR"

cp "$STATUS_DESKTOP/bin/libnim_status_client$LIB_EXT" "$LIB_DIR/libnim_status_client$LIB_EXT"
