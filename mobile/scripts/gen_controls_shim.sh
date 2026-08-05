#!/usr/bin/env bash
# qmlcachegen cannot follow QtQuick.Controls' optional style imports; expose one
# concrete style under the module name "QtQuick.Controls" so the compiler can
# resolve Controls-derived types. Compile-time only, nothing is shipped.
set -eo pipefail

QT_QML_DIR="$1"   # Qt qml import root, e.g. <qt>/android_arm64_v8a/qml
OUT_DIR="$2"      # shim root; pass to qmlcachegen as -I <OUT_DIR>
STYLE="${3:-Universal}"

SRC="$QT_QML_DIR/QtQuick/Controls/$STYLE"
DST="$OUT_DIR/QtQuick/Controls"

[[ -d "$SRC" ]] || { echo "gen_controls_shim: style dir not found: $SRC" >&2; exit 1; }

rm -rf "$DST"
mkdir -p "$DST"
cp -R "$SRC/." "$DST/"
# Re-home the module; drop "prefer" so types resolve from this copy. Incomplete
# styles keep their "import QtQuick.Controls.Basic auto" fallback line.
sed -i.bak -e "s/^module QtQuick\.Controls\.$STYLE$/module QtQuick.Controls/" -e '/^prefer /d' "$DST/qmldir"
rm -f "$DST/qmldir.bak"
grep -q '^module QtQuick\.Controls$' "$DST/qmldir" || {
    echo "gen_controls_shim: failed to rewrite module line in $DST/qmldir" >&2
    exit 1
}
