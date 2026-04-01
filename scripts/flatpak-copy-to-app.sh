#!/usr/bin/env bash
# Flatpak build-commands script: installs everything into /app
# Called by flatpak-builder via app.status.desktop.yml
set -eo pipefail

PREFIX="/app"

# Binary, runtime libraries, and QML resources
install -Dm755 bin/nim_status_client "$PREFIX/bin/nim_status_client"
cp -P bin/StatusQ/libStatusQ.so "$PREFIX/lib/"
install -Dm644 resources.rcc "$PREFIX/resources.rcc"

# Wrapper script (the flatpak entry point)
install -Dm755 flatpak-wrapper.sh "$PREFIX/bin/nim_status_client_wrapped"

# Qt libraries, plugins, QML, WebEngine
cp -r qt-libs/lib/*       "$PREFIX/lib/"
mkdir -p "$PREFIX/lib/qt6"
cp -r qt-libs/plugins     "$PREFIX/lib/qt6/plugins"
cp -r qt-libs/qml         "$PREFIX/lib/qt6/qml"
install -Dm755 qt-libs/libexec/QtWebEngineProcess "$PREFIX/libexec/QtWebEngineProcess"
cp -r qt-libs/resources    "$PREFIX/resources"
cp -r qt-libs/translations "$PREFIX/translations"

# Native libraries (status-go, keycard, sds, nwaku)
cp -P native-libs/*.so* "$PREFIX/lib/"

# System libraries (GStreamer, NSS, PC/SC, Kerberos)
cp -P sys-libs/*.so*              "$PREFIX/lib/"        2>/dev/null || true
cp -r sys-libs/gstreamer-1.0      "$PREFIX/lib/"        2>/dev/null || true
cp -r sys-libs/nss                "$PREFIX/lib/"        2>/dev/null || true

# Resources (icons, desktop file, appdata)
ICON_DIR="$PREFIX/share/icons/hicolor"
install -Dm644 status-512.png "$ICON_DIR/512x512/apps/app.status.desktop.png"

mkdir -p "$PREFIX/share/applications"
cat > "$PREFIX/share/applications/app.status.desktop.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Status
Comment=Decentralised messaging, crypto wallet, and Web3 browser
Exec=nim_status_client_wrapped
Icon=app.status.desktop
Type=Application
Categories=Network;InstantMessaging;Chat;
DESKTOP
