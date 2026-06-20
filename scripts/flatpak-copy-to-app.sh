#!/usr/bin/env bash
# Runs inside the flatpak-builder sandbox as the status-desktop module's
# build-commands step (see app.status.desktop.yml). It assembles /app/* from:
#   - this module's source dir:    nim_status_client, libStatusQ.so,
#                                  resources.rcc, flatpak-wrapper.sh,
#                                  status-512.png, native-libs/
#   - the host's /opt/qt:          Qt 6 install
#     (filesystem=host:ro)
#   - the host's /usr:             krb5 + NSS PKCS#11 modules from /run/host/usr,
#     (filesystem=host-os:ro)        since the freedesktop runtime doesn't ship them
set -eo pipefail

PREFIX="/app"

# Qt location, handed in via qt.env (QT_DIR=... make flatpak; see bundle-flatpak.sh).
# Default kept in sync with ci/Dockerfile.x86_64's QT_VERSION.
[[ -f qt.env ]] && source qt.env
QT_SRC="${QT_DIR:-/opt/qt/6.11.0/gcc_64}"
# Host /usr reachable via --filesystem=host-os:ro (mounts under /run/host).
HOST_USR_LIB="/run/host/usr/lib/x86_64-linux-gnu"

[[ -d "$QT_SRC" ]] || { echo "ERROR: Qt not visible at $QT_SRC (set QT_DIR, or fix the /opt/qt default). Image Qt version mismatch, or --filesystem=host:ro missing?"; exit 1; }
[[ -d "$HOST_USR_LIB" ]] || { echo "ERROR: host /usr not visible at $HOST_USR_LIB. Is --filesystem=host-os:ro set?"; exit 1; }
[[ -d native-libs ]] || { echo "ERROR: native-libs/ missing from sandbox source dir. Manifest sources mis-staged?"; exit 1; }

# App binary, runtime libs, RCC bundle (from this module's sources)
install -Dm755 bin/nim_status_client      "$PREFIX/bin/nim_status_client"
install -Dm755 bin/StatusQ/libStatusQ.so  "$PREFIX/lib/libStatusQ.so"
install -Dm644 resources.rcc              "$PREFIX/resources.rcc"

# Wrapper script - the actual flatpak entry point (see manifest "command").
install -Dm755 flatpak-wrapper.sh "$PREFIX/bin/nim_status_client_wrapped"

# Qt 6 (libs, plugins, QML, WebEngine) - directly from host /opt/qt
mkdir -p "$PREFIX/lib/qt6"
cp -P "$QT_SRC"/lib/libQt6*.so* "$QT_SRC"/lib/libicu*.so* "$PREFIX/lib/"
cp -P "$QT_SRC"/lib/libav*.so*  "$QT_SRC"/lib/libsw*.so*  "$PREFIX/lib/"
cp -r "$QT_SRC"/plugins  "$PREFIX/lib/qt6/plugins"
cp -r "$QT_SRC"/qml      "$PREFIX/lib/qt6/qml"
install -Dm755 "$QT_SRC"/libexec/QtWebEngineProcess "$PREFIX/libexec/QtWebEngineProcess"
cp -r "$QT_SRC"/resources    "$PREFIX/resources"
cp -r "$QT_SRC"/translations "$PREFIX/translations"

# Native libs we built ourselves: status-go, keycard, sds. Brought in via
# manifest sources (see app.status.desktop.yml), so they appear in
# native-libs/ in this sandbox source dir.
cp -P native-libs/*.so* "$PREFIX/lib/"

# System libs the runtime doesn't ship: krb5 chain and NSS PKCS#11 modules.
# Read straight from the host's /usr/lib via the host-os mount.
cp -P "$HOST_USR_LIB"/libgssapi_krb5.so* "$HOST_USR_LIB"/libkrb5.so*       \
      "$HOST_USR_LIB"/libk5crypto.so*    "$HOST_USR_LIB"/libkrb5support.so* \
      "$HOST_USR_LIB"/libcom_err.so*     "$HOST_USR_LIB"/libkeyutils.so*    \
      "$PREFIX/lib/"
cp -r "$HOST_USR_LIB"/nss "$PREFIX/lib/"

# Icon (512x512 is what flathub accepts as the primary size for this app).
install -Dm644 status-512.png \
  "$PREFIX/share/icons/hicolor/512x512/apps/app.status.desktop.png"

# Desktop entry (checked-in repo file, staged into this dir by the manifest).
install -Dm644 app.status.desktop.desktop \
  "$PREFIX/share/applications/app.status.desktop.desktop"
