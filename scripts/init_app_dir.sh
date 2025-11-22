#!/usr/bin/env bash
# Assemble the Status Desktop app directory for packaging.
# Usage: init_app_dir.sh [appimage|flatpak]  (default: appimage)
set -euo pipefail

# shellcheck source=scripts/lib-deps.sh
source "$(dirname "$0")/lib-deps.sh"

MODE="${1:-appimage}"

case "$MODE" in
  appimage)
    DEST="${APP_DIR:?APP_DIR must be set}/usr"
    rm -rf "${APP_DIR}"
    ;;
  flatpak)
    DEST="/app"
    ;;
  *)
    echo "Unknown mode: $MODE (expected appimage or flatpak)" >&2
    exit 1
    ;;
esac

# Shared
mkdir -p \
  "${DEST}/bin" \
  "${DEST}/lib" \
  "${DEST}/libexec"

cp bin/nim_status_client "${DEST}/bin/"
cp bin/StatusQ/* "${DEST}/lib/"

if [[ "$MODE" == "appimage" ]]; then
  cp resources.rcc "${DEST}/"
  cp nim-status.desktop "${APP_DIR}/."

  mkdir -p \
    "${DEST}/qml" \
    "${DEST}/plugins/platforminputcontexts" \
    "${DEST}/lib/pcsc/drivers" \
    "${APP_DIR}/etc/reader.conf.d"

  cp -R bin/lib/* "${DEST}/lib/"
  cp status.png "${APP_DIR}/status.png"
  cp status.png "${DEST}/"

  copy_native_libs "${DEST}/lib"
  cp "${FCITX5_QT}" "${DEST}/plugins/platforminputcontexts/"

  # Copy dependencies which linuxdeployqt can't manage from nix store or system (FHS)
  if [[ -z "${IN_NIX_SHELL:-}" ]]; then
    copy_system_libs "${DEST}/lib"

    # gstreamer1.0 (note: distinct from gstreamer-1.0 copied by copy_system_libs)
    cp -r /usr/lib/x86_64-linux-gnu/gstreamer1.0 "${DEST}/lib/"

    copy_qt_webengine "${DEST}/libexec"

    # Extra pcsc files not covered by copy_system_libs
    echo "Bundling pcsc-lite extras..."
    cp -L /usr/local/lib/x86_64-linux-gnu/libpcsclite_real.so* "${DEST}/lib/"
    cp -L /usr/local/lib/x86_64-linux-gnu/pkgconfig/libpcsclite.pc "${DEST}/lib/"

    chmod 755 "${DEST}/lib/libpcsclite.so"*
    chmod 755 "${DEST}/lib/libpcsclite_real.so"*
    chmod 755 "${DEST}/lib/libpcsclite.pc"

    echo "Bundling pcscd..."
    cp -L "/usr/local/sbin/pcscd"* "${DEST}/bin/"
    chmod 755 "${DEST}/bin/pcscd"*

    echo "Bundling Dash shell..."
    cp /usr/bin/dash "${DEST}/bin/"
    ln -rs "${DEST}/bin/dash" "${DEST}/bin/sh"

    echo "Bundling xdg-open wrapper..."
    cp scripts/xdg-open-wrapper.sh "${DEST}/bin/xdg-open"
  else
    mkdir -p "${DEST}"/lib/{gstreamer1.0,gstreamer-1.0,nss}

    echo "${GST_PLUGIN_SYSTEM_PATH_1_0}" | tr ':' '\n' | sort -u | xargs -I {} find {} -name "*.so" | xargs -I {} cp {} "${DEST}/lib/gstreamer-1.0/"
    cp -r "${GSTREAMER_PATH}/libexec/gstreamer-1.0" "${DEST}/lib/gstreamer1.0/"
    cp "${LIBKRB5_PATH}/lib/libcom_err.so.3" "${DEST}/lib/libcom_err.so.3"
    cp "${NSS_PATH}"/lib/{libfreebl3,libfreeblpriv3,libnssckbi,libnssdbm3,libsoftokn3}.{chk,so} "${DEST}/lib/nss/" || true
    cp "${QTWEBENGINE_PATH}/libexec/QtWebEngineProcess" "${DEST}/libexec/QtWebEngineProcess"
    cp "${QTWEBENGINE_PATH}"/resources/* "${DEST}/libexec/"
    cp -r "${QTWEBENGINE_PATH}/translations/qtwebengine_locales" "${DEST}/libexec/"

    #TODO: bundle pcsc-lite and pcscd in nix-shell

    chmod -R u+w "${DEST}"
  fi

elif [[ "$MODE" == "flatpak" ]]; then
  mkdir -p \
    "${DEST}/lib/qt6/plugins" \
    "${DEST}/lib/qt6/qml" \
    "${DEST}/lib/gstreamer-1.0" \
    "${DEST}/resources" \
    "${DEST}/translations"

  # Wrapper script
  install -Dm755 flatpak-wrapper.sh "${DEST}/bin/nim_status_client_wrapped"

  # Build output libraries (DOtherSide, ZXing, etc.)
  cp -a bin/lib/* "${DEST}/lib/"

  # Pre-staged libraries (populated by scripts/build-flatpak.sh)
  cp -a native-libs/* "${DEST}/lib/"
  cp -a sys-libs/*.so* "${DEST}/lib/"
  cp -a sys-libs/nss "${DEST}/lib/"
  cp -a sys-libs/gstreamer-1.0/* "${DEST}/lib/gstreamer-1.0/"

  # Qt libraries and plugins
  cp -a qt-libs/lib/* "${DEST}/lib/"
  cp -a qt-libs/plugins/* "${DEST}/lib/qt6/plugins/"
  cp -a qt-libs/qml/* "${DEST}/lib/qt6/qml/"
  install -Dm755 qt-libs/libexec/QtWebEngineProcess "${DEST}/libexec/QtWebEngineProcess"
  cp -a qt-libs/resources/* "${DEST}/resources/"
  cp -a qt-libs/translations/qtwebengine_locales "${DEST}/translations/"

  # App resources
  install -Dm644 resources.rcc "${DEST}/resources.rcc"
  install -Dm644 status-512.png "${DEST}/status.png"

  # Desktop integration
  install -Dm644 nim-status.desktop "${DEST}/share/applications/app.status.desktop.desktop"
  sed -i 's|^Exec=.*|Exec=nim_status_client_wrapped|;s|^Icon=.*|Icon=app.status.desktop|' "${DEST}/share/applications/app.status.desktop.desktop"
  install -Dm644 status-512.png "${DEST}/share/icons/hicolor/512x512/apps/app.status.desktop.png"
  install -Dm644 app.status.desktop.appdata.xml "${DEST}/share/metainfo/app.status.desktop.appdata.xml"
fi
