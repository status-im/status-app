#!/usr/bin/env bash
# Re-pin the status-go dependency to the given ref: a full or abbreviated
# SHA, a branch, a tag, or a PR number. Rewrites the requires line (its trailing
# comment is always `# statusgo`), re-locks and re-runs setup.
# Run it from a real clone: in a git worktree nimble 0.24.1 does not recognise
# the .git file and `nimble lock` exits 1 after writing the lock.
# The lock is solved against an EMPTY store: on a warm store nimble 0.24.1 lets
# entries it already holds into the solve, so the lock would differ per machine.
set -euo pipefail

REF="${1:?Usage: $(basename "$0") <status-go-ref>}"

REPO="https://github.com/status-im/status-go.git"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="${ROOT}/nim_status_client.nimble"

# mktemp -d without a template: the only form GNU and macOS share.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "${SCRATCH}"' EXIT

if [[ "${REF}" =~ ^[0-9a-f]{40}$ ]]; then
  SHA="${REF}"
elif [[ "${REF}" =~ ^[0-9a-f]{7,39}$ ]]; then
  # ls-remote cannot expand an abbreviation; a blobless clone can.
  git clone -q --filter=blob:none --no-checkout "${REPO}" "${SCRATCH}/status-go"
  SHA="$(git -C "${SCRATCH}/status-go" rev-parse --verify --quiet "${REF}^{commit}" || true)"
  if [[ -z "${SHA}" ]]; then
    echo "error: '${REF}' is not a unique commit prefix in ${REPO}" >&2
    exit 1
  fi
else
  # An annotated tag is listed twice (tag object and ^{} peeled commit); the
  # server lists refs by name, so preference is explicit, not head -n 1.
  SHA="$(git ls-remote "${REPO}" \
           "refs/heads/${REF}" "refs/tags/${REF}" "refs/tags/${REF}^{}" "refs/pull/${REF}/head" \
         | awk -v ref="${REF}" '
             $2 == "refs/heads/" ref        { head = $1 }
             $2 == "refs/tags/" ref "^{}"   { peeled = $1 }
             $2 == "refs/tags/" ref         { tag = $1 }
             $2 == "refs/pull/" ref "/head" { pull = $1 }
             END {
               if (head != "") print head
               else if (peeled != "") print peeled
               else if (tag != "") print tag
               else if (pull != "") print pull
             }')"
  if [[ -z "${SHA}" ]]; then
    echo "error: '${REF}' resolves to nothing in ${REPO}" >&2
    exit 1
  fi
fi

if ! grep -qE "^requires \"${REPO}#[0-9a-f]+\"" "${MANIFEST}"; then
  echo "error: no status-go requires line in ${MANIFEST}" >&2
  exit 1
fi
# Not `sed -i`: GNU and BSD sed disagree on its argument (BSD given `-i -E` silently edits nothing).
tmp="${SCRATCH}/nim_status_client.nimble"
sed -E "s|^requires \"${REPO}#[0-9a-f]+\".*|requires \"${REPO}#${SHA}\"  # statusgo|" "${MANIFEST}" > "${tmp}" \
  && cat "${tmp}" > "${MANIFEST}"
grep -q "^requires \"${REPO}#${SHA}\"" "${MANIFEST}" || { echo "error: pin not rewritten in ${MANIFEST}" >&2; exit 1; }
echo "status-go pinned to ${SHA}"

cd "${ROOT}"
LOCK_STORE="${SCRATCH}/store"
mkdir -p "${LOCK_STORE}"
NIMBLE_DIR="${LOCK_STORE}" nimble lock
nimble setup
