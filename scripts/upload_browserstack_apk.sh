#!/usr/bin/env bash
set -euo pipefail

# Upload APK to BrowserStack and output JSON response to stdout
# Requires environment variables:
#   APK_PATH - Path to the APK file
#   BROWSERSTACK_USERNAME - BrowserStack username
#   BROWSERSTACK_ACCESS_KEY - BrowserStack access key
#   BUILD_NUMBER - Build number (optional, defaults to current timestamp)

if [[ -z "${APK_PATH:-}" ]]; then
  echo "Error: APK_PATH environment variable is required" >&2
  exit 1
fi

if [[ ! -f "${APK_PATH}" ]]; then
  echo "Error: APK_PATH does not exist or is not a file: ${APK_PATH}" >&2
  exit 1
fi

if [[ ! -r "${APK_PATH}" ]]; then
  echo "Error: APK_PATH is not readable: ${APK_PATH}" >&2
  exit 1
fi

if [[ -z "${BROWSERSTACK_USERNAME:-}" ]]; then
  echo "Error: BROWSERSTACK_USERNAME environment variable is required" >&2
  exit 1
fi

if [[ -z "${BROWSERSTACK_ACCESS_KEY:-}" ]]; then
  echo "Error: BROWSERSTACK_ACCESS_KEY environment variable is required" >&2
  exit 1
fi

APK_NAME=$(basename "${APK_PATH}")
SANITIZED_NAME=$(printf '%s' "${APK_NAME}" | tr -cs '[:alnum:]._-' '-' | cut -c1-80)
BUILD_ID="${BUILD_NUMBER:-$(date +%s)}"
CUSTOM_ID="${SANITIZED_NAME}-${BUILD_ID}"

curl -s -u "${BROWSERSTACK_USERNAME}:${BROWSERSTACK_ACCESS_KEY}" \
  -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
  -F "file=@${APK_PATH}" \
  -F "custom_id=${CUSTOM_ID}"

