#!/usr/bin/env bash
set -euo pipefail

# Upload APK to BrowserStack and output JSON response to stdout
# Usage: ./upload_browserstack_apk.sh <apk_path_or_url>
# URLs must be publicly accessible (BrowserStack fetches directly)

APK_SOURCE="${1:?Usage: $0 <apk_path_or_url>}"
: "${BROWSERSTACK_USERNAME:?required}"
: "${BROWSERSTACK_ACCESS_KEY:?required}"

APK_NAME=$(basename "${APK_SOURCE%%\?*}")
CUSTOM_ID=$(printf '%s' "${APK_NAME}" | tr -cs '[:alnum:]._-' '-' | cut -c1-100)

if [[ "${APK_SOURCE}" == http* ]]; then
  FORM_KEY="url="
else
  [[ -f "${APK_SOURCE}" ]] || { echo "Error: File not found: ${APK_SOURCE}" >&2; exit 1; }
  FORM_KEY="file=@"
fi

curl --request POST "https://api-cloud.browserstack.com/app-automate/upload" \
  --silent --show-error --fail-with-body \
  --user "${BROWSERSTACK_USERNAME}:${BROWSERSTACK_ACCESS_KEY}" \
  --form "${FORM_KEY}${APK_SOURCE}" \
  --form "custom_id=${CUSTOM_ID}"
