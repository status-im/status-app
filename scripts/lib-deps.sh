#!/usr/bin/env bash
# Shared library dependency paths for packaging (AppImage & Flatpak).

# Native libraries built from source (status-go, keycard, sds, nwaku)
copy_native_libs() {
  local dest="$1"
  echo "Bundling native libraries..."
  cp -P vendor/status-go/build/bin/libstatus.so* "$dest/"
  local keycard="${STATUSKEYCARDGO:-vendor/status-keycard-go/build/libkeycard/libkeycard.so}"
  if [[ -f "$keycard" ]]; then
    cp -P "$keycard" "$dest/"
  fi
  if [[ -f "${NIM_SDS_SOURCE_DIR:-.}/build/libsds.so" ]]; then
    cp -P "${NIM_SDS_SOURCE_DIR:-.}/build/libsds.so" "$dest/"
  fi
  if [[ "${USE_NWAKU:-}" == "true" ]]; then
    cp "${NWAKU_SOURCE_DIR:-.}/build/libwaku.so" "$dest/"
  fi
}

# System libraries from Ubuntu build environment (GStreamer, NSS, PC/SC)
copy_system_libs() {
  local dest="$1"
  echo "Bundling system libraries..."
  cp -P /usr/lib/x86_64-linux-gnu/libgst*.so* "$dest/"
  cp -r /usr/lib/x86_64-linux-gnu/gstreamer-1.0 "$dest/"
  cp -r /usr/lib/x86_64-linux-gnu/nss "$dest/"
  cp -P /usr/local/lib/x86_64-linux-gnu/libpcsclite*.so* "$dest/"
}

# Kerberos chain (flatpak needs these; linuxdeployqt handles them for AppImage)
copy_krb5_libs() {
  local dest="$1"
  cp -P /usr/lib/x86_64-linux-gnu/libgssapi_krb5.so* \
        /usr/lib/x86_64-linux-gnu/libkrb5.so* \
        /usr/lib/x86_64-linux-gnu/libk5crypto.so* \
        /usr/lib/x86_64-linux-gnu/libkrb5support.so* \
        /usr/lib/x86_64-linux-gnu/libcom_err.so* \
        /usr/lib/x86_64-linux-gnu/libkeyutils.so* \
        "$dest/"
}

# Full Qt installation (libs, plugins, QML, WebEngine)
copy_qt() {
  local dest="$1"
  local QT_SOURCE="${QTDIR:?QTDIR must be set}"
  echo "Bundling Qt from ${QT_SOURCE}..."
  mkdir -p "$dest"/{lib,plugins,qml,libexec,resources,translations}
  cp -P "${QT_SOURCE}"/lib/libQt6*.so* "${QT_SOURCE}"/lib/libicu*.so* "$dest/lib/"
  # FFmpeg libraries bundled by Qt (required by qtmultimedia backend)
  cp -P "${QT_SOURCE}"/lib/libav*.so* "${QT_SOURCE}"/lib/libsw*.so* "$dest/lib/"
  cp -r "${QT_SOURCE}"/plugins/* "$dest/plugins/"
  cp -r "${QT_SOURCE}"/qml/* "$dest/qml/"
  cp "${QT_SOURCE}"/libexec/QtWebEngineProcess "$dest/libexec/"
  cp "${QT_SOURCE}"/resources/* "$dest/resources/"
  cp -r "${QT_SOURCE}"/translations/qtwebengine_locales "$dest/translations/"
}

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
