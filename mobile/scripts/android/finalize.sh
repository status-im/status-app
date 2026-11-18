#!/usr/bin/env bash
# Adds build-config.json to an APK or an app bundle (AAB) and signs it again.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <input.apk|input.aab> <output>" >&2
  exit 1
fi

INPUT="$1"
OUTPUT="$2"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# A bundle keeps the app's files in its base module.
ASSET=assets/build-config.json
if [[ "${INPUT}" == *.aab ]]; then
  ASSET="base/${ASSET}"
fi

: "${STATUS_APP_KEYSTORE_PATH:?}" "${STATUS_APP_KEYSTORE_PASSWORD:?}"
: "${STATUS_APP_KEY_ALIAS:?}" "${STATUS_APP_KEY_PASSWORD:?}"

if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
  BUILD_TOOLS="$(find "${ANDROID_SDK_ROOT}/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n1)"
  PATH="${BUILD_TOOLS}:${PATH}"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp "${INPUT}" "${WORK}/app"

# jarsigner, which signs the bundle, would keep the first signature next to its own.
STALE=()
while IFS= read -r ENTRY; do
  case "${ENTRY}" in
    META-INF/MANIFEST.MF|META-INF/*.SF|META-INF/*.RSA|META-INF/*.DSA|META-INF/*.EC|"${ASSET}")
      STALE+=("${ENTRY}") ;;
  esac
done < <(unzip -Z1 "${WORK}/app")
if [[ ${#STALE[@]} -gt 0 ]]; then
  aapt remove "${WORK}/app" "${STALE[@]}"
fi

mkdir -p "$(dirname "${WORK}/${ASSET}")"
"${REPO}/scripts/write-build-config.sh" "${WORK}/${ASSET}"
(cd "${WORK}" && aapt add app "${ASSET}" >/dev/null)

mkdir -p "$(dirname "${OUTPUT}")"
if [[ "${INPUT}" == *.aab ]]; then
  jarsigner -keystore "${STATUS_APP_KEYSTORE_PATH}" -storepass:env STATUS_APP_KEYSTORE_PASSWORD \
    -keypass:env STATUS_APP_KEY_PASSWORD -signedjar "${OUTPUT}" "${WORK}/app" "${STATUS_APP_KEY_ALIAS}"
else
  zipalign -P 16 -f 4 "${WORK}/app" "${WORK}/aligned.apk"
  apksigner sign \
    --ks "${STATUS_APP_KEYSTORE_PATH}" --ks-pass env:STATUS_APP_KEYSTORE_PASSWORD \
    --ks-key-alias "${STATUS_APP_KEY_ALIAS}" --key-pass env:STATUS_APP_KEY_PASSWORD \
    --out "${OUTPUT}" "${WORK}/aligned.apk"
  rm -f "${OUTPUT}.idsig"
  apksigner verify "${OUTPUT}"
fi
