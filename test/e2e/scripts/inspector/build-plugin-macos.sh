#!/bin/bash
# Builds the Qt inspector plugin for macOS.
# usage: build-plugin-macos.sh <output directory>
# Result: <output directory>/plugins/generic/libqmlinspector.dylib
#
# With no QT_PREFIX, installs Qt 6.11.0 (the Qt of the CI .app) and points the
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
PLUGIN_REF="${PLUGIN_REF:-edbf498b167750d2d08aae8093de07339219a507}"
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
  qt="$qt_cache/6.11.0/macos"
  bundle=1
  if [ ! -f "$qt/lib/cmake/Qt6/Qt6Config.cmake" ]; then
    venv="$qt_cache/aqt-venv"
    if [ ! -x "$venv/bin/aqt" ]; then
      python3 -m venv "$venv"
      "$venv/bin/pip" install -q aqtinstall
    fi
    "$venv/bin/aqt" install-qt mac desktop 6.11.0 clang_64 -O "$qt_cache" --timeout 3000
  fi
fi

generator="Unix Makefiles"
if command -v ninja >/dev/null 2>&1; then
  generator="Ninja"
fi
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
