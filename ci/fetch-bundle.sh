#!/usr/bin/env bash
# Downloads the unsigned app of a GitHub Actions run, verifies its attestation and unpacks it.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo 'fetch-bundle.sh <run_id> <linux|macos|windows|android|android-aab|ios> <dest_dir>' >&2
  exit 1
fi

RUN_ID="$1"
PLATFORM="$2"
DEST="$3"
REPO=status-im/status-app

case "${PLATFORM}" in
  macos)   NAME=macos-aarch64-bundle;  EXT=tar.gz ;;
  linux)   NAME=linux-x86_64-bundle;   EXT=tar.gz ;;
  windows) NAME=windows-x86_64-bundle; EXT=tar.gz ;;
  android) NAME=android-arm64-bundle;  EXT=apk ;;
  android-aab) NAME=android-arm64-bundle; EXT=aab ;;
  ios)     NAME=ios-arm64-unsigned;    EXT=ipa ;;
  *) echo "ERROR: unknown platform: ${PLATFORM}" >&2; exit 1 ;;
esac
APP="${DEST}/bundle.${EXT}"

# The artifact is named Status-<ref>-<commit>-<name> and not zipped:
# `gh run download` cannot read those.
ARTIFACT_ID="$(gh api --paginate "repos/${REPO}/actions/runs/${RUN_ID}/artifacts" \
  --jq ".artifacts[] | select(.name | endswith(\"-${NAME}.${EXT}\")) | .id")"
if [[ ! "${ARTIFACT_ID}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: run ${RUN_ID} has no artifact named *-${NAME}.${EXT}" >&2
  exit 1
fi

rm -rf "${DEST}"
mkdir -p "${DEST}"
gh api "repos/${REPO}/actions/artifacts/${ARTIFACT_ID}/zip" > "${APP}"

SOURCE="$(gh attestation verify "${APP}" --repo "${REPO}" \
  --signer-workflow "${REPO}/.github/workflows/ci.yml" --deny-self-hosted-runners --format json \
  --jq '.[0].verificationResult.signature.certificate | "\(.sourceRepositoryRef) \(.sourceRepositoryDigest)"')"
SOURCE_REF="${SOURCE% *}"
SOURCE_SHA="${SOURCE#* }"
echo "Built from ${SOURCE_REF} (${SOURCE_SHA})"

# The refs ci.yml builds the release variant from.
if [[ "${RELEASE:-false}" == "true" && ! "${SOURCE_REF}" =~ ^refs/(heads/release/|tags/).+$ ]]; then
  echo "ERROR: a release must be built from a release/* branch or a tag, not ${SOURCE_REF}" >&2
  exit 1
fi

case "${PLATFORM}" in
  macos|linux|windows) tar -C "${DEST}" -xzf "${APP}"; rm "${APP}" ;;
  ios) unzip -q "${APP}" -d "${DEST}"; rm "${APP}" ;;
esac

git fetch --quiet --tags "https://github.com/${REPO}.git" "${SOURCE_SHA}"
git describe --tags --always "${SOURCE_SHA}" > "${DEST}/VERSION"
echo "${SOURCE_SHA}" > "${DEST}/COMMIT"
