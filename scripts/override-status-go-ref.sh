#!/usr/bin/env bash
# Re-pin the status-go dependency to the given ref (SHA, branch, or PR number).
set -euo pipefail

REF="${1:?Usage: $(basename "$0") <status-go-ref>}"

REPO="https://github.com/status-im/status-go.git"
MANIFEST="$(dirname "$0")/../nim_status_client.nimble"

# The manifest pins by SHA, so a branch or PR number has to be resolved first.
if [[ "${REF}" =~ ^[0-9a-f]{40}$ ]]; then
  SHA="${REF}"
else
  SHA="$(git ls-remote "${REPO}" \
           "refs/heads/${REF}" "refs/tags/${REF}" "refs/pull/${REF}/head" \
         | head -n 1 | cut -f 1)"
  if [[ -z "${SHA}" ]]; then
    echo "error: '${REF}' resolves to nothing in ${REPO}" >&2
    exit 1
  fi
fi

if ! grep -qE "^requires \"${REPO}#[0-9a-f]+\"" "${MANIFEST}"; then
  echo "error: no status-go requires line in ${MANIFEST}" >&2
  exit 1
fi
sed -i -E "s|^(requires \"${REPO}#)[0-9a-f]+\"|\1${SHA}\"|" "${MANIFEST}"
echo "status-go pinned to ${SHA}"

# The lock has to agree with the manifest before anything resolves.
( cd "$(dirname "${MANIFEST}")" && nimble lock )
