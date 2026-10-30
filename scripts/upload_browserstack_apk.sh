#!/usr/bin/env bash
set -euo pipefail

# Upload APK to BrowserStack and output JSON response to stdout
# Usage: ./upload_browserstack_apk.sh <apk_path_or_url>
# URLs must be publicly accessible (BrowserStack fetches directly)
# Diagnostics go to stderr: Jenkins parses stdout as JSON.
# With the defaults, 3 attempts of at most 180 s plus the waits fit the 15-minute stage timeout.

APK_SOURCE="${1:?Usage: $0 <apk_path_or_url>}"
: "${BROWSERSTACK_USERNAME:?required}"
: "${BROWSERSTACK_ACCESS_KEY:?required}"
ATTEMPTS="${BROWSERSTACK_UPLOAD_ATTEMPTS:-3}"
RETRY_DELAY="${BROWSERSTACK_UPLOAD_RETRY_DELAY:-30}"
if ! [[ "${ATTEMPTS}" =~ ^[0-9]+$ ]] || (( 10#${ATTEMPTS} < 1 )); then
  echo "Error: BROWSERSTACK_UPLOAD_ATTEMPTS must be a whole number of at least 1" >&2
  exit 1
fi
[[ "${RETRY_DELAY}" =~ ^[0-9]+$ ]] || { echo "Error: BROWSERSTACK_UPLOAD_RETRY_DELAY must be a whole number of seconds" >&2; exit 1; }
ATTEMPTS=$(( 10#${ATTEMPTS} ))
RETRY_DELAY=$(( 10#${RETRY_DELAY} ))

APK_NAME=$(basename "${APK_SOURCE%%\?*}")
CUSTOM_ID=$(printf '%s' "${APK_NAME}" | tr -cs '[:alnum:]._-' '-' | cut -c1-100)

if [[ "${APK_SOURCE}" == http* ]]; then
  FORM_KEY="url="
else
  [[ -f "${APK_SOURCE}" ]] || { echo "Error: File not found: ${APK_SOURCE}" >&2; exit 1; }
  FORM_KEY="file=@"
fi

HEADERS=$(mktemp)
trap 'rm -f "${HEADERS}"' EXIT

rc=1
for (( attempt = 1; attempt <= ATTEMPTS; attempt++ )); do
  rc=0
  # curl leaves this file untouched when there is no response, so clear the last status.
  : > "${HEADERS}"
  # Credentials reach curl as a config line on stdin, not in argv, which other
  # processes on the agent can read.
  response=$(printf 'user = "%s:%s"\n' "${BROWSERSTACK_USERNAME}" "${BROWSERSTACK_ACCESS_KEY}" | \
    curl --request POST "https://api-cloud.browserstack.com/app-automate/upload" \
      --silent --show-error --fail-with-body --max-time 180 \
      --dump-header "${HEADERS}" \
      --config - \
      --form "${FORM_KEY}${APK_SOURCE}" \
      --form "custom_id=${CUSTOM_ID}") || rc=$?

  if [[ ${rc} -eq 0 ]]; then
    printf '%s\n' "${response}"
    exit 0
  fi

  status=$(awk '{ sub(/\r$/, "") } toupper($1) ~ /^HTTP/ { code = $2 } END { print code }' "${HEADERS}")
  echo "BrowserStack upload attempt ${attempt}/${ATTEMPTS} failed: curl exit ${rc}, HTTP ${status:-none}" >&2
  grep -i -E '^(date|retry-after|x-request-id|x-amzn-requestid|cf-ray):' "${HEADERS}" >&2 || true
  [[ -n "${response}" ]] && echo "Response body: ${response}" >&2

  # Retrying cannot fix a 4xx (bad credentials or URL), except 408 (timeout) and 429 (rate limit).
  [[ "${status}" == 4* && "${status}" != 408 && "${status}" != 429 ]] && exit "${rc}"
  if (( attempt < ATTEMPTS )); then
    wait_s=$(( RETRY_DELAY * attempt ))
    retry_after=$(awk -F': *' 'tolower($1) == "retry-after" { gsub(/\r/, "", $2); print $2 }' "${HEADERS}")
    if [[ "${retry_after}" =~ ^[0-9]{1,18}$ ]]; then
      retry_after=$(( 10#${retry_after} > 120 ? 120 : 10#${retry_after} ))
      (( retry_after > wait_s )) && wait_s=${retry_after}
    fi
    sleep "${wait_s}"
  fi
done

exit "${rc}"
