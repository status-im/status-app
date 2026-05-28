#!/usr/bin/env bash
# Assemble the Status Desktop AppDir for AppImage packaging.
# https://docs.appimage.org/reference/appdir.html
set -euo pipefail

# Native libraries built from source: status-go, keycard, sds, optionally nwaku.
copy_native_libs() {
  local dest="$1"
  echo "Bundling native libraries..."
  cp -P vendor/status-go/build/bin/libstatus.so* "$dest/"
  cp -P "${STATUSKEYCARD_QT_LIBDIR:?STATUSKEYCARD_QT_LIBDIR must be set}"/libstatus-keycard-qt.so* "$dest/"
  cp -P "${NIM_SDS_SOURCE_DIR:?NIM_SDS_SOURCE_DIR must be set}/build/libsds.so" "$dest/"
  if [[ "${USE_NWAKU:-}" == "true" ]]; then
    cp -P "${NWAKU_SOURCE_DIR:?NWAKU_SOURCE_DIR must be set}/build/libwaku.so" "$dest/"
  fi
}

# System libraries from the Ubuntu build image: GStreamer, NSS, PC/SC.
copy_system_libs() {
  local dest="$1"
  echo "Bundling system libraries..."
  cp -P /usr/lib/x86_64-linux-gnu/libgst*.so* "$dest/"
  cp -r /usr/lib/x86_64-linux-gnu/gstreamer-1.0 "$dest/"
  cp -r /usr/lib/x86_64-linux-gnu/nss "$dest/"
  cp -P /usr/local/lib/x86_64-linux-gnu/libpcsclite*.so* "$dest/"
}

DEST="${APP_DIR:?APP_DIR must be set}/usr"
rm -rf "${APP_DIR}"

mkdir -p \
  "${DEST}/bin" \
  "${DEST}/lib" \
  "${DEST}/libexec" \
  "${DEST}/qml" \
  "${DEST}/plugins/platforminputcontexts" \
  "${DEST}/lib/pcsc/drivers" \
  "${APP_DIR}/etc/reader.conf.d"

cp bin/nim_status_client "${DEST}/bin/"
cp bin/StatusQ/* "${DEST}/lib/"
cp resources.rcc "${DEST}/"
cp nim-status.desktop "${APP_DIR}/."
cp -R bin/lib/* "${DEST}/lib/"
cp status.png "${APP_DIR}/status.png"
cp status.png "${DEST}/"

copy_native_libs "${DEST}/lib"
cp "${FCITX5_QT}" "${DEST}/plugins/platforminputcontexts/"

# Qt WebEngine only (process + resources + locales)
copy_qt_webengine() {
  local dest="$1"
  local QT_SOURCE="${QTDIR:?QTDIR must be set}"
  echo "Bundling Qt WebEngine resources..."
  cp "${QT_SOURCE}"/libexec/QtWebEngineProcess "$dest/"
  chmod +x "$dest/QtWebEngineProcess"
  cp "${QT_SOURCE}"/resources/* "$dest/"
  cp -r "${QT_SOURCE}"/translations/qtwebengine_locales "$dest/"
}

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
