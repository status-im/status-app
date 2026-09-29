#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -r -- "$scratch"' EXIT
cat > "$scratch/go" <<'GO'
#!/usr/bin/env bash
printf '%s\n' "$TKL_TEST_METADATA"
exit "${TKL_TEST_GO_EXIT:-0}"
GO
chmod +x "$scratch/go"
export PATH="$scratch:$PATH"
export TKL_TEST_METADATA
for TKL_TEST_METADATA in 'build -tags=gowaku_no_rln,tkl' 'build -tags="gowaku_no_rln tkl"'; do
  bash "$repo/scripts/status_go_has_tkl.sh" unused
done
for TKL_TEST_METADATA in 'build -tags=gowaku_no_rln' 'build -tags=not_tkl' 'no build metadata'; do
  if bash "$repo/scripts/status_go_has_tkl.sh" unused; then
    echo "Incorrectly accepted untagged build metadata" >&2
    exit 1
  fi
done
TKL_TEST_METADATA='build -tags=tkl'
if TKL_TEST_GO_EXIT=1 bash "$repo/scripts/status_go_has_tkl.sh" unused; then
  echo "Ignored go version failure" >&2
  exit 1
fi
echo "Backend build-tag detection tests passed"
