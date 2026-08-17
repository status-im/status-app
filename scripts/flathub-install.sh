#!/usr/bin/env bash
set -eo pipefail

PREFIX="${FLATPAK_DEST:-/app}"
APP_ID="app.status.StatusDesktop"
NIM_SDS_SOURCE_DIR="${NIM_SDS_SOURCE_DIR:-vendor/nim-sds}"

need() { [[ -e "$1" ]] || { echo "ERROR: $1 missing; run the build first."; exit 1; }; }
need bin/nim_status_client
need bin/StatusQ/libStatusQ.so
need resources.rcc
need vendor/status-go/build/bin/libstatus.so.0
need "${NIM_SDS_SOURCE_DIR}/build/libsds.so"

# App binary, StatusQ, resource bundle
install -Dm755 bin/nim_status_client     "$PREFIX/bin/nim_status_client"
install -Dm755 bin/StatusQ/libStatusQ.so "$PREFIX/lib/libStatusQ.so"
install -Dm644 resources.rcc             "$PREFIX/resources.rcc"

# Native libs we build ourselves: status-go, keycard, sds (keep symlinks).
cp -P vendor/status-go/build/bin/libstatus.so* "$PREFIX/lib/"
cp -P vendor/status-keycard-qt/build/linux/libstatus-keycard-qt.so* "$PREFIX/lib/"
cp -P "${NIM_SDS_SOURCE_DIR}"/build/libsds.so* "$PREFIX/lib/"

# Entry point (see manifest "command")
install -Dm755 flatpak-wrapper.sh "$PREFIX/bin/nim_status_client_wrapped"

# Icons: hicolor icon for the desktop entry + the in-app window/tray icon
# (see determineStatusAppIconPath in src/nim_status_client.nim).
install -Dm644 status-512.png "$PREFIX/share/icons/hicolor/512x512/apps/${APP_ID}.png"
install -Dm644 status.png     "$PREFIX/status.png"

# Desktop entry, AppStream metainfo, license
install -Dm644 "${APP_ID}.desktop"      "$PREFIX/share/applications/${APP_ID}.desktop"
install -Dm644 "${APP_ID}.metainfo.xml" "$PREFIX/share/metainfo/${APP_ID}.metainfo.xml"
install -Dm644 LICENSE.md               "$PREFIX/share/licenses/${APP_ID}/LICENSE.md"
