#!/usr/bin/env bash
# Turns the folder of `make bundle-windows` into the signed installer.
set -eo pipefail

[[ $# -ne 2 ]] && { echo 'finalize-windows.sh <app_folder> <output_exe>' >&2; exit 1; }

DIST="${1}"
INSTALLER="${2}"
[[ ! -f "${DIST}/status.iss" ]] && { echo "Not an app folder: ${DIST}" >&2; exit 1; }
[[ -z "${DESKTOP_VERSION}" ]] && { echo 'Missing env variable: DESKTOP_VERSION' >&2; exit 1; }

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$(dirname "${INSTALLER}")"

"${SCRIPTS}/write-build-config.sh" "${DIST}/resources/build-config.json"

if [[ -n "${WINDOWS_CODESIGN_PFX_PATH}" ]]; then
    "${SCRIPTS}/sign-windows-bin.sh" "${DIST}"
fi

mkdir -p "${INSTALLER_DIR}"
rm -f "${INSTALLER}"
ISCC \
    -O"${INSTALLER_DIR}" \
    -D"BaseName=$(basename "${INSTALLER}" .exe)" \
    -D"Version=${DESKTOP_VERSION}" \
    "${DIST}/status.iss"

if [[ -n "${WINDOWS_CODESIGN_PFX_PATH}" ]]; then
    "${SCRIPTS}/sign-windows-bin.sh" "${INSTALLER_DIR}"
fi
