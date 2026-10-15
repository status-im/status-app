#!/usr/bin/env bash
# Build the COLRv0 emoji font from the sources fetched by fetch-sources.sh.
#
# Takes ~7 minutes. The result is committed to the repo, so this only needs
# re-running when manifest.json changes.
set -euo pipefail

cd "$(dirname "$0")"
WORK="${WORK_DIR:-.work}"
VENV="$WORK/venv"
REPO_ROOT=$(git rev-parse --show-toplevel)

[[ -d $WORK/svg ]] || { echo "ERROR: run ./fetch-sources.sh first" >&2; exit 1; }

read -r OUTPUT FORMAT FAMILY UPEM WIDTH ASCENDER DESCENDER <<<"$(
    python3 - <<'PY'
import json
f = json.load(open('manifest.json'))['font']
print(f['output'], f['color_format'], f['family'].replace(' ', ' '),
      f['upem'], f['width'], f['ascender'], f['descender'])
PY
)"
FAMILY=${FAMILY//$' '/ }

if [[ ! -x $VENV/bin/nanoemoji ]]; then
    echo "==> creating toolchain venv"
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q --upgrade pip
    "$VENV/bin/pip" install -q -r requirements.txt
fi

echo "==> building $FORMAT font (upem=$UPEM width=$WIDTH asc=$ASCENDER desc=$DESCENDER)"
rm -rf "$WORK/build"
PATH="$PWD/$VENV/bin:$PATH" "$VENV/bin/nanoemoji" \
    --color_format "$FORMAT" \
    --family "$FAMILY" \
    --upem "$UPEM" --width "$WIDTH" --ascender "$ASCENDER" --descender "$DESCENDER" \
    --output_file emoji.ttf \
    --build_dir "$WORK/build" \
    "$WORK"/svg/*.svg

echo "==> adding FE0F-less ligature aliases"
mkdir -p "$(dirname "$REPO_ROOT/$OUTPUT")"
"$VENV/bin/python" fix_fe0f.py "$WORK/build/emoji.ttf" "$REPO_ROOT/$OUTPUT"

"$VENV/bin/python" - "$REPO_ROOT/$OUTPUT" <<'PY'
import sys
from fontTools.ttLib import TTFont
font = TTFont(sys.argv[1], lazy=True)
cmap = font.getBestCmap()
print(f"==> {sys.argv[1]}")
print(f"    COLR v{font['COLR'].version}, {len(font['COLR'].ColorLayers)} colour glyphs, "
      f"{len(cmap)} codepoints, upem {font['head'].unitsPerEm}, "
      f"advance {font['hmtx'][cmap[0x1F600]][0]}")
PY
echo "==> done; run the StatusQ emoji conformance test before committing"
