#!/usr/bin/env bash
# Adds build-config.json to an APK and signs it again.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <input.apk> <output.apk>" >&2
  exit 1
fi

INPUT="$1"
OUTPUT="$2"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ASSET=assets/build-config.json

: "${STATUS_APP_KEYSTORE_PATH:?}" "${STATUS_APP_KEYSTORE_PASSWORD:?}"
: "${STATUS_APP_KEY_ALIAS:?}" "${STATUS_APP_KEY_PASSWORD:?}"

if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
  BUILD_TOOLS="$(find "${ANDROID_SDK_ROOT}/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n1)"
  PATH="${PATH}:${BUILD_TOOLS}"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp "${INPUT}" "${WORK}/app.apk"

STALE=()
while IFS= read -r ENTRY; do
  case "${ENTRY}" in
    META-INF/MANIFEST.MF|META-INF/*.SF|META-INF/*.RSA|META-INF/*.DSA|META-INF/*.EC|"${ASSET}")
      STALE+=("${ENTRY}") ;;
  esac
done < <(unzip -Z1 "${WORK}/app.apk")
if [[ ${#STALE[@]} -gt 0 ]]; then
  aapt remove "${WORK}/app.apk" "${STALE[@]}"
fi

mkdir -p "${WORK}/assets"
"${REPO}/scripts/write-build-config.sh" "${WORK}/${ASSET}"
if [[ -f "${WORK}/${ASSET}" ]]; then
  (cd "${WORK}" && aapt add app.apk "${ASSET}" >/dev/null)
fi

zipalign -P 16 -f 4 "${WORK}/app.apk" "${WORK}/aligned.apk"

mkdir -p "$(dirname "${OUTPUT}")"
apksigner sign \
  --ks "${STATUS_APP_KEYSTORE_PATH}" --ks-pass env:STATUS_APP_KEYSTORE_PASSWORD \
  --ks-key-alias "${STATUS_APP_KEY_ALIAS}" --key-pass env:STATUS_APP_KEY_PASSWORD \
  --out "${OUTPUT}" "${WORK}/aligned.apk"
rm -f "${OUTPUT}.idsig"
apksigner verify "${OUTPUT}"
