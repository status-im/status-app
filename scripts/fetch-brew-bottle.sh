#!/usr/bin/env bash
set -eof pipefail

# This script is used to fetch HomeBrew bottles for OpenSSL.

trap "echo 'Failed to download bottle. Check your authentication token and network connection.'" EXIT ERR INT QUIT

function get_gh_pkgs_token() {
    curl --fail --show-error -Ls -u "${GITHUB_USER}:${GITHUB_TOKEN}" https://ghcr.io/token | jq -r '.token'
}

function get_bottle_json() {
    { curl --fail-with-body -sSL "https://formulae.brew.sh/api/formula/${1}.json" \
        | jq ".bottle.stable.files[\"${2}\"]";
    } || echo -e "Failed to get bottle files from:\n${BOTTLE_INFO}"
}

function fetch_bottle() {
    if [[ -n "${BEARER_TOKEN}" ]]; then
        AUTH=("-H" "Authorization: Bearer ${BEARER_TOKEN}")
    else
        AUTH=("-u" "_:_") # WARNING: Unauthorized requests can be throttled.
    fi
    curl --fail --show-error -Ls "${AUTH[@]}" -o "${1}" "${2}"
}

if [[ $(uname) != "Darwin" ]]; then
    echo "This script is intended for use on macOS!" >&2
    exit 1
fi

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <bottle_name> <bottle_filter1|bottle_filter2>" >&2
    exit 1
fi
BOTTLE_NAME="${1}"
BOTTLE_FILTER="${2}"
BOTTLE_PATH="/tmp/${BOTTLE_NAME}.tar.gz"

# GitHub Packages requires authentication.
GITHUB_USER="${GITHUB_USER:-_}"
GITHUB_TOKEN="${GITHUB_TOKEN:-_}"
if [[ "${GITHUB_USER}" == "_" ]] || [[ "${GITHUB_TOKEN}" == "_" ]]; then
    echo "No GITHUB_USER or GITHUB_TOKEN variable set!" >&2
    echo "GitHub Packages can throttle unauthorized requests." >&2
else
    echo "${BOTTLE_NAME} - Fetching GH Pkgs Token"
    BEARER_TOKEN=$(get_gh_pkgs_token)
fi

echo "${BOTTLE_NAME} - Finding bottle URL"
echo "${BOTTLE_NAME} - Selecting: ${BOTTLE_FILTER}"

BOTTLE_JSON=$(get_bottle_json "${BOTTLE_NAME}" "${BOTTLE_FILTER}")
BOTTLE_URL=$(echo "${BOTTLE_JSON}" | jq -r .url)
BOTTLE_SHA=$(echo "${BOTTLE_JSON}" | jq -r .sha256)

if [[ "${BOTTLE_URL}" == "null" ]] || [[ "${BOTTLE_SHA}" == "null" ]]; then
    echo "Failed to identify bottle URL or SHA256! Bottle dropped from Homebrew?" >&2
    exit 1
fi

echo "${BOTTLE_NAME} - Fetching bottle for macOS, bottle sha256: ${BOTTLE_SHA}"
fetch_bottle "${BOTTLE_PATH}" "${BOTTLE_URL}"
trap "rm -fr ${BOTTLE_PATH}" EXIT ERR INT QUIT

echo "${BOTTLE_NAME} - Checking SHA256 checksum"
BOTTLE_LOCAL_SHA=$(shasum -a 256 "${BOTTLE_PATH}" | awk '{print $1}')

if [[ "${BOTTLE_LOCAL_SHA}" != "${BOTTLE_SHA}" ]]; then
    echo "The SHA256 of downloaded bottle did not match!" >&2
    exit 1
fi

echo "${BOTTLE_NAME} - Unpacking bottle tarball"
mkdir -p "bottles/${BOTTLE_NAME}"
tar xzf "${BOTTLE_PATH}" --strip-components 2 -C "bottles/${BOTTLE_NAME}"
