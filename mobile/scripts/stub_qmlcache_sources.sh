#!/usr/bin/env bash
# Points every .qml/.js/.mjs entry of a qmlcachegen-filtered qrc at one empty file.
# The type loader runs these files from their AOT units and only needs the names in
# qrc (directory listings, file selectors), so the source text is dead weight.
# usage: stub_qmlcache_sources.sh <name_qmlcache.qrc> <stub file>
set -euo pipefail
qrc=$1
stub=$2

: > "$stub"
sed -E -i.bak "s#(<file [^>]*>)[^<]*\\.(qml|js|mjs)(</file>)#\\1${stub}\\3#" "$qrc"
rm -f "$qrc.bak"
