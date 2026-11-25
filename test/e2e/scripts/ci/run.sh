#!/bin/bash
# Runs the suite on a CI runner of any of the three systems: unpacks the build,
# starts the local Waku fleet and calls pytest.
# usage: run.sh <directory with the build> <plugins directory> <pytest arguments>
set -euo pipefail

scripts=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
repo=$(CDPATH= cd -- "$scripts/../../.." && pwd)
pkg=$1
plugins=$2
shift 2
tmp=${RUNNER_TEMP:?}
uv_version=0.13.9

# Python and the Windows app take a Windows path.
native() {
    if command -v cygpath > /dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi
}

# Linux runs the tests in the image, which has its own Python.
native_tests() { # <app> <python of the venv> <pytest arguments>
    local app=$1 python=$2
    shift 2
    cd "$scripts/.."
    cp configs/_local.ci.py configs/_local.py
    uv venv --quiet --python 3.14 .venv
    uv pip install --quiet --python "$python" -r requirements.txt
    AUT_PATH=$(native "$app")
    INSPECTOR_PLUGINS=$(native "$plugins")
    export AUT_PATH INSPECTOR_PLUGINS
    export STATUS_RUNTIME_HTTP_API=False STATUS_RUNTIME_WS_API=False STATUS_RUNTIME_TEST_MODE=1
    export E2E_LOCAL_WAKU_FLEET=1
    "$python" -m pytest -p no:cacheprovider "$@"
}

mkdir -p "$tmp/aut"
case "$(uname -s)" in
    Linux)
        tar -xzf "$pkg"/*.tar.gz -C "$tmp/aut"
        (cd "$tmp/aut" && ./*.AppImage --appimage-extract > /dev/null)
        ldconfig -p | grep 'libpq\.so\.5' > /dev/null || { sudo apt-get update -q && sudo apt-get install -y -q libpq5; }
        "$repo/ci/build-image.sh" --pull tests
        APP="$tmp/aut/squashfs-root/AppRun" PLUGINS=$plugins IMAGE=$("$repo/ci/build-image.sh" --image tests) \
            "$scripts/inspector/run-in-docker.sh" "$@"
        ;;
    Darwin)
        export HOMEBREW_NO_AUTO_UPDATE=1
        brew install --quiet libpq
        hdiutil attach -quiet -nobrowse -readonly -mountpoint "$tmp/dmg" "$pkg"/*.dmg
        cp -R "$tmp"/dmg/*.app "$tmp/aut/"
        hdiutil detach -quiet "$tmp/dmg"
        curl -LsSf "https://astral.sh/uv/$uv_version/install.sh" | sh
        export PATH="$HOME/.local/bin:$PATH"
        "$scripts/start-waku-fleet.sh" "$tmp/waku"
        # On the runner's 1024x768 screen four of the fourteen critical tests fail.
        # The mode is taken by number: the display's colour depth is not one a mode string can name.
        # Without that mode the run goes on at the runner's own screen size.
        brew install --quiet displayplacer \
            && screen=$(displayplacer list | awk '/Persistent screen id:/ { print $4; exit }') \
            && mode=$(displayplacer list | awk '/res:1920x1080 hz:60/ { sub(":", "", $2); print $2; exit }') \
            && [ -n "$mode" ] \
            && displayplacer "id:$screen mode:$mode origin:(0,0) degree:0" \
            || echo "::warning::The screen was not switched to 1920x1080; some tests need that size."
        native_tests "$(ls -d "$tmp"/aut/*.app)" .venv/bin/python "$@"
        ;;
    *)
        7z x -bso0 -bsp0 "-o$(cygpath -w "$tmp/aut")" "$(cygpath -w "$(ls "$pkg"/*.7z)")"
        pwsh -NoProfile -Command "irm https://astral.sh/uv/$uv_version/install.ps1 | iex"
        PATH="$(cygpath -u "$USERPROFILE")/.local/bin:$PATH"
        export PATH
        pwsh -NoProfile -File "$(cygpath -w "$scripts/start-waku-fleet-windows.ps1")" -WorkDir "$(cygpath -w "$tmp/waku")"
        export QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu
        # On the runner's 1024x768 screen four of the fourteen critical tests fail.
        pwsh -NoProfile -Command 'Set-DisplayResolution -Width 1920 -Height 1080 -Force'
        native_tests "$tmp/aut/Status/bin/Status.exe" .venv/Scripts/python.exe "$@"
        ;;
esac
