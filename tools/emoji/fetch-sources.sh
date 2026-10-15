#!/usr/bin/env bash
# Fetch the pinned emoji sources listed in manifest.json into .work/
#
#   .work/svg/                 twemoji artwork (one SVG per emoji)
#   .work/emojibase/           emojibase raw data used to build the catalogue
#
# Everything here is derived from manifest.json; edit that file to bump a version.
set -euo pipefail

cd "$(dirname "$0")"
WORK="${WORK_DIR:-.work}"

read -r TW_REPO TW_TAG TW_SHA TW_PATH TW_FILES EB_REPO EB_COMMIT <<<"$(
    python3 - <<'PY'
import json
m = json.load(open('manifest.json'))
a, d = m['artwork'], m['metadata']
print(a['repo'], a['tag'], a['tarball_sha256'], a['svg_path'], a['expected_files'],
      d['repo'], d['commit'])
PY
)"

mkdir -p "$WORK"

echo "==> twemoji $TW_TAG"
TARBALL="$WORK/twemoji-$TW_TAG.tar.gz"
if [[ ! -f $TARBALL ]]; then
    curl -sSfL -o "$TARBALL" "https://codeload.github.com/$TW_REPO/tar.gz/refs/tags/$TW_TAG"
fi
echo "$TW_SHA  $TARBALL" | sha256sum --check --status \
    || { echo "ERROR: tarball checksum mismatch for $TARBALL" >&2; exit 1; }

rm -rf "$WORK/svg" && mkdir -p "$WORK/svg"
tar xzf "$TARBALL" -C "$WORK/svg" --strip-components=3 --wildcards "*/$TW_PATH/*.svg"
COUNT=$(find "$WORK/svg" -name '*.svg' | wc -l)
[[ $COUNT -eq $TW_FILES ]] \
    || { echo "ERROR: expected $TW_FILES SVGs, extracted $COUNT" >&2; exit 1; }
echo "    $COUNT SVGs -> $WORK/svg"

echo "==> emojibase ${EB_COMMIT:0:12}"
mkdir -p "$WORK/emojibase"
python3 - "$WORK/emojibase" "$EB_REPO" "$EB_COMMIT" <<'PY'
import json, os, sys, urllib.request
out, repo, commit = sys.argv[1:4]
for path in json.load(open('manifest.json'))['metadata']['files']:
    dest = os.path.join(out, os.path.basename(path))
    urllib.request.urlretrieve(
        f"https://raw.githubusercontent.com/{repo}/{commit}/{path}", dest)
    print(f"    {os.path.basename(path)} ({os.path.getsize(dest) // 1024} KB)")
PY

echo "==> done"
