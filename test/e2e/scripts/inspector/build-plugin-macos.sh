#!/bin/bash
# Builds the Qt inspector plugin for macOS.
# usage: build-plugin-macos.sh <output directory>
# Result: <output directory>/plugins/generic/libqmlinspector.dylib
#
# With no QT_PREFIX, takes the Qt of the CI .app (QTDIR when it is that version,
# a download otherwise) and points the
# plugin at Contents/Frameworks inside that bundle. For a local app built with
# the Qt from `qmake`, pass that prefix and the plugin keeps those library paths:
#   QT_PREFIX="$(qmake -query QT_INSTALL_PREFIX)" build-plugin-macos.sh /tmp/qmlinspector
#
# The plugin's source is in its own repository. Set PLUGIN_SRC to build a local checkout;
# otherwise PLUGIN_REPO is cloned at PLUGIN_REF.
set -euo pipefail
if [ $# -ne 1 ]; then
  echo "usage: build-plugin-macos.sh <output directory>" >&2
  exit 2
fi
PLUGIN_REPO="${PLUGIN_REPO:-https://github.com/status-im/status-qml-inspector.git}"
versions="$(cd "$(dirname "$0")" && pwd)/versions.env"
PLUGIN_REF="${PLUGIN_REF:-$(sed -n 's/^PLUGIN_REF=//p' "$versions")}"
qt_version=$(sed -n 's/^QT_VERSION=//p' "$versions")
out=$(mkdir -p "$1" && cd "$1" && pwd)
qt_cache="${QT_CACHE:-$HOME/.cache/status-e2e-qt}"
mkdir -p "$qt_cache"

if [ -n "${PLUGIN_SRC:-}" ]; then
  src=$(cd "$PLUGIN_SRC" && pwd)
else
  src=$(mktemp -d)
  trap 'rm -rf "$src"' EXIT
  git clone --quiet "$PLUGIN_REPO" "$src"
  git -C "$src" checkout --quiet "$PLUGIN_REF"
fi

bundle=0
if [ -n "${QT_PREFIX:-}" ]; then
  qt=$(cd "$QT_PREFIX" && pwd)
else
  qt="$qt_cache/$qt_version/macos"
  bundle=1
  # QTDIR, which the app's own build uses, saves the download when it is the same version.
  if [ -n "${QTDIR:-}" ] && [ "$("$QTDIR/bin/qmake" -query QT_VERSION 2> /dev/null || true)" = "$qt_version" ]; then
    qt=$(cd "$QTDIR" && pwd)
  elif [ ! -f "$qt/lib/cmake/Qt6/Qt6Config.cmake" ]; then
    venv="$qt_cache/aqt-venv"
    if [ ! -x "$venv/bin/aqt" ]; then
      python3 -m venv "$venv"
      "$venv/bin/pip" install -q aqtinstall
    fi
    "$venv/bin/aqt" install-qt mac desktop "$qt_version" clang_64 -O "$qt_cache" --timeout 3000
  fi
fi

generator="Unix Makefiles"
if command -v ninja >/dev/null 2>&1; then
  generator="Ninja"
fi
# The source is cloned to a new directory each time; an earlier configuration names the old one.
rm -rf "$out/CMakeCache.txt" "$out/CMakeFiles"
cmake -S "$src/qt-plugin/generic-plugin" -B "$out" -G "$generator" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$qt" \
  -DCMAKE_OSX_ARCHITECTURES="$(uname -m)" \
  -DQMLINSPECTOR_QUICKWIDGETS=OFF
cmake --build "$out"

plugin="$out/plugins/generic/libqmlinspector.dylib"
if [ "$bundle" = 1 ]; then
  for fw in QtQuick QtWidgets QtOpenGL QtQml QtNetwork QtGui QtCore; do
    old=$(otool -L "$plugin" | awk -v fw="$fw" '$1 ~ fw ".framework/" { print $1; exit }')
    [ -n "$old" ] || continue
    install_name_tool -change "$old" \
      "@executable_path/../Frameworks/${fw}.framework/Versions/A/${fw}" "$plugin"
  done
  codesign -s - --force "$plugin"
fi
ls -l "$plugin"
