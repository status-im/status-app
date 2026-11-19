#!/usr/bin/env bash
# Removes from every Mach-O in an app bundle the architectures the main executable lacks.
# Usage: thin-macos-bundle.sh <app bundle> <main executable>
set -euo pipefail

ARCHS=$(lipo -archs "$2")
if [[ "${ARCHS}" == *" "* ]]; then
    echo "$2 is universal (${ARCHS}), keeping every architecture"
    exit 0
fi

BEFORE=$(du -sh "$1" | cut -f1)
ditto --arch "${ARCHS}" "$1" "$1.thin"
rm -rf "$1"
mv "$1.thin" "$1"
echo "Thinned $1 to ${ARCHS}: ${BEFORE} -> $(du -sh "$1" | cut -f1)"
