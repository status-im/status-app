#!/usr/bin/env bash

set -e

show_help() {
    cat << EOF
F-Droid Local Build Script

Runs the F-Droid build inside the fdroidserver Docker container.

USAGE:
    $0 [OPTIONS] [appid:versioncode]

OPTIONS:
    --no-cleanup    Don't remove container after build (useful for debugging)
    -h, --help      Show this help message

EXAMPLES:
    $0                                    # Build default (app.status.mobile:29500000)
    $0 app.status.mobile:29500000         # Build specific version
    $0 --no-cleanup app.status.mobile:29500000  # Keep container after build

ENVIRONMENT VARIABLES:
    FDROIDDATA_PATH    Path to fdroiddata repo (default: ./fdroiddata)

NOTE:
    The Status app build requires many hours due to Qt compilation.
    Make sure you have sufficient disk space (~100GB recommended).
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

DOCKER_IMAGE="registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie"
FDROIDDATA_PATH="${FDROIDDATA_PATH:-$SCRIPT_DIR/fdroiddata}"
DEFAULT_BUILD="app.status.mobile:29500000"
CONTAINER_NAME="fdroid-local-build-$$"
ENTRYPOINT_SCRIPT="$SCRIPT_DIR/../fdroid/fdroid-container-build.sh"

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# shellcheck disable=SC2317  # Used by trap
cleanup() {
    log_info "Cleaning up container..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

trap cleanup EXIT

NO_CLEANUP=false
BUILD_TARGET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cleanup)
            NO_CLEANUP=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            BUILD_TARGET="$1"
            shift
            ;;
    esac
done

BUILD_TARGET="${BUILD_TARGET:-$DEFAULT_BUILD}"

if [[ ! -d "$FDROIDDATA_PATH" ]]; then
    log_error "fdroiddata directory not found at: $FDROIDDATA_PATH"
    log_error "Set FDROIDDATA_PATH environment variable to the correct path"
    exit 1
fi

FDROIDDATA_PATH=$(cd "$FDROIDDATA_PATH" && pwd)
log_info "Using fdroiddata at: $FDROIDDATA_PATH"

APPID="${BUILD_TARGET%:*}"
if [[ ! -f "$FDROIDDATA_PATH/metadata/${APPID}.yml" ]]; then
    log_error "Metadata file not found: $FDROIDDATA_PATH/metadata/${APPID}.yml"
    exit 1
fi

log_info "Build target: $BUILD_TARGET"
log_info "Starting F-Droid build container..."
log_info "This may take a very long time (hours) for complex builds like Status app"
log_info "Container name: $CONTAINER_NAME"

if $NO_CLEANUP; then
    trap - EXIT
fi

BUILD_EXIT_CODE=0
docker run -i \
    --name "$CONTAINER_NAME" \
    -v "$FDROIDDATA_PATH:/fdroiddata" \
    -v "$ENTRYPOINT_SCRIPT:/entrypoint.sh:ro" \
    -e "BUILD_TARGET=$BUILD_TARGET" \
    -w /fdroiddata \
    "$DOCKER_IMAGE" \
    /bin/bash /entrypoint.sh || BUILD_EXIT_CODE=$?

if [[ $BUILD_EXIT_CODE -eq 0 ]]; then
    log_info "Build completed successfully!"
    log_info "Check $FDROIDDATA_PATH/tmp/ for output files"
else
    log_error "Build failed with exit code: $BUILD_EXIT_CODE"
    if $NO_CLEANUP; then
        log_info "Container preserved for debugging: $CONTAINER_NAME"
        log_info "Attach with: docker exec -it $CONTAINER_NAME /bin/bash"
    fi
fi

exit $BUILD_EXIT_CODE
