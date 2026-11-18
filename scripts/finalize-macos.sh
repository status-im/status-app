#!/usr/bin/env bash
# Turns the app bundle of `make bundle-macos` into the signed disk image.
set -eo pipefail

[[ $(uname) != 'Darwin' ]] && { echo 'This only works on macOS.' >&2; exit 1; }
[[ $# -ne 2 ]] && { echo 'finalize-macos.sh <app_bundle> <output_dmg>' >&2; exit 1; }

BUNDLE="${1}"
DMG="${2}"
[[ ! -d "${BUNDLE}/Contents/MacOS" ]] && { echo "Not an app bundle: ${BUNDLE}" >&2; exit 1; }

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "${SCRIPTS}")"
ENTITLEMENTS="${ENTITLEMENTS:-${REPO}/resources/Entitlements.plist}"
DMGBUILD="${DMGBUILD:-nix run ${REPO}#dmgbuild --}"

"${SCRIPTS}/write-build-config.sh" "${BUNDLE}/Contents/Resources/build-config.json"

xattr -cr "${BUNDLE}"

if [[ -n "${MACOS_CODESIGN_IDENT}" ]]; then
    "${SCRIPTS}/sign-macos-pkg.sh" "${BUNDLE}" "${MACOS_CODESIGN_IDENT}" \
        --entitlements "${ENTITLEMENTS}"
else
    codesign --force --deep --sign - "${BUNDLE}"
    codesign --verify --strict=all --deep "${BUNDLE}"
fi

mkdir -p "$(dirname "${DMG}")"
rm -f "${DMG}"
${DMGBUILD} -s "${SCRIPTS}/dmg-settings.py" -D app="${BUNDLE}" 'Status' "${DMG}"

if [[ -n "${MACOS_CODESIGN_IDENT}" ]]; then
    "${SCRIPTS}/sign-macos-pkg.sh" "${DMG}" "${MACOS_CODESIGN_IDENT}"
fi
