#!/usr/bin/env bash
# Removes from every Mach-O in an app bundle the architectures the main executable lacks.
# Usage: thin-macos-bundle.sh <app bundle> <main executable>
set -euo pipefail

BUNDLE="$1"
EXECUTABLE="$2"

ARCHS=$(lipo -archs "${EXECUTABLE}")
if [[ "${ARCHS}" == *" "* ]]; then
    echo "${EXECUTABLE} is universal (${ARCHS}), keeping every architecture"
    exit 0
fi

BEFORE=$(du -sk "${BUNDLE}" | cut -f1)
COUNT=0
while IFS= read -r -d '' FILE; do
    FILE_ARCHS=$(lipo -archs "${FILE}" 2>/dev/null) || continue
    [[ "${FILE_ARCHS}" == *" "* && " ${FILE_ARCHS} " == *" ${ARCHS} "* ]] || continue
    # GNU stat (nix shell on CI) takes -c; BSD stat rejects -c and takes -f.
    MODE=$(stat -c '%a' "${FILE}" 2>/dev/null || stat -f '%Lp' "${FILE}")
    lipo -thin "${ARCHS}" "${FILE}" -output "${FILE}.thin"
    mv "${FILE}.thin" "${FILE}"
    chmod "${MODE}" "${FILE}"
    COUNT=$((COUNT + 1))
done < <(find "${BUNDLE}" -type f -print0)

AFTER=$(du -sk "${BUNDLE}" | cut -f1)
echo "Thinned ${COUNT} files to ${ARCHS}: $((BEFORE / 1024)) MB -> $((AFTER / 1024)) MB"
