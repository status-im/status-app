#!/usr/bin/env bash
# Downloads the unsigned app of a GitHub Actions run, verifies its attestation and unpacks it.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo 'fetch-bundle.sh <run_id> <linux|macos|windows|android|ios> <dest_dir>' >&2
  exit 1
fi

RUN_ID="$1"
PLATFORM="$2"
DEST="$3"
REPO=status-im/status-app

case "${PLATFORM}" in
  macos)   ARTIFACT=Status-macos-aarch64-bundle;  FILE=Status-macos-aarch64-bundle.tar.gz ;;
  linux)   ARTIFACT=Status-linux-x86_64-bundle;   FILE=Status-linux-x86_64-bundle.tar.gz ;;
  windows) ARTIFACT=Status-windows-x86_64-bundle; FILE=Status-windows-x86_64-bundle.tar.gz ;;
  android) ARTIFACT=Status-android-arm64-bundle;  FILE=StatusPR-bundle.apk ;;
  ios)     ARTIFACT=Status-ios-arm64-unsigned;    FILE=StatusPR-unsigned.ipa ;;
  *) echo "ERROR: unknown platform: ${PLATFORM}" >&2; exit 1 ;;
esac

rm -rf "${DEST}"
mkdir -p "${DEST}"
gh run download "${RUN_ID}" --repo "${REPO}" --name "${ARTIFACT}" --dir "${DEST}"

SOURCE="$(gh attestation verify "${DEST}/${FILE}" --repo "${REPO}" \
  --signer-workflow "${REPO}/.github/workflows/ci.yml" --deny-self-hosted-runners --format json \
  --jq '.[0].verificationResult.signature.certificate | "\(.sourceRepositoryRef) \(.sourceRepositoryDigest)"')"
SOURCE_REF="${SOURCE% *}"
SOURCE_SHA="${SOURCE#* }"
echo "Built from ${SOURCE_REF} (${SOURCE_SHA})"

if [[ "${RELEASE:-false}" == "true" && ! "${SOURCE_REF}" =~ ^refs/(heads/(master|release/.+)|tags/.+)$ ]]; then
  echo "ERROR: a release must be built from master, release/* or a tag, not ${SOURCE_REF}" >&2
  exit 1
fi

case "${PLATFORM}" in
  macos|linux|windows) tar -C "${DEST}" -xzf "${DEST}/${FILE}"; rm "${DEST}/${FILE}" ;;
  ios) unzip -q "${DEST}/${FILE}" -d "${DEST}"; rm "${DEST}/${FILE}" ;;
esac

git fetch --quiet --tags "https://github.com/${REPO}.git" "${SOURCE_SHA}"
git describe --tags --always "${SOURCE_SHA}" > "${DEST}/VERSION"
echo "${SOURCE_SHA}" > "${DEST}/COMMIT"
