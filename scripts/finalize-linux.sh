#!/usr/bin/env bash
# Turns the AppDir of `make bundle-linux` into the signed AppImage.
set -eo pipefail

[[ $# -ne 2 ]] && { echo 'finalize-linux.sh <app_dir> <output_appimage>' >&2; exit 1; }

APP_DIR="${1}"
APPIMAGE="${2}"
[[ ! -d "${APP_DIR}/usr/bin" ]] && { echo "Not an AppDir: ${APP_DIR}" >&2; exit 1; }

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPTS}/write-build-config.sh" "${APP_DIR}/usr/build-config"

mkdir -p "$(dirname "${APPIMAGE}")"
rm -f "${APPIMAGE}"
"${APPIMAGE_TOOL:-appimagetool}" "${APP_DIR}" "${APPIMAGE}"

if [[ -n "${IN_NIX_SHELL}" ]]; then
    patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 "${APPIMAGE}"
    patchelf --remove-rpath "${APPIMAGE}"
fi

if [[ -n "${LINUX_GPG_PRIVATE_KEY_FILE}" ]]; then
    "${SCRIPTS}/sign-linux-file.sh" "${APPIMAGE}"
fi
