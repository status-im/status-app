#!/usr/bin/env bash
#
# Cleanup fdroiddata directory
# Uses Docker alpine to remove files owned by Docker user (vagrant/root)
# that Jenkins user cannot delete directly
#

set -e

FDROIDDATA_PATH="${FDROIDDATA_PATH:-${WORKSPACE}/fdroiddata}"

if [ -d "$FDROIDDATA_PATH" ]; then
    echo "Removing fdroiddata directory: $FDROIDDATA_PATH"
    docker run --rm -v "$(dirname "$FDROIDDATA_PATH"):/workspace" alpine:latest \
        sh -c "rm -rf /workspace/$(basename "$FDROIDDATA_PATH")"
fi
