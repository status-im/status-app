#!/bin/bash
# Builds the Qt inspector plugin for Linux desktop against the Qt version of the
# CI-built app. Runs in ubuntu:22.04, the base of the CI build image.
# usage: build-plugin.sh <output directory>
# Result: <output directory>/plugins/generic/libqmlinspector.so
#
# The plugin's source is in its own repository. Set PLUGIN_SRC to build a local checkout;
# otherwise PLUGIN_REPO is cloned at PLUGIN_REF.
set -euo pipefail
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

docker run --rm -e OWNER="$(id -u):$(id -g)" -e QT_VERSION="$qt_version" \
  -v "$src:/src:ro" -v "$out:/out" -v "$qt_cache:/qt" \
  ubuntu:22.04 bash -euo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends build-essential cmake ninja-build python3-pip \
      ca-certificates libgl1-mesa-dev libxkbcommon-dev libvulkan-dev libfontconfig1 libdbus-1-3 > /dev/null
    python3 -m pip install --quiet aqtinstall
    [ -d "/qt/$QT_VERSION/gcc_64" ] || python3 -m aqt install-qt linux desktop "$QT_VERSION" linux_gcc_64 -O /qt --timeout 3000
    cmake -S /src/qt-plugin/generic-plugin -B /out -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH="/qt/$QT_VERSION/gcc_64" -DQMLINSPECTOR_QUICKWIDGETS=OFF
    cmake --build /out
    chown -R "$OWNER" /out /qt
  '
ls -l "$out/plugins/generic/libqmlinspector.so"
