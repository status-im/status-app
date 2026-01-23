#!/usr/bin/env bash

set -e pipefail

rm -rf "${APP_DIR}"

mkdir -p \
  "${APP_DIR}/usr/bin" \
  "${APP_DIR}/usr/lib" \
  "${APP_DIR}/usr/qml" \
  "${APP_DIR}/usr/plugins/platforminputcontexts" \
  "${APP_DIR}/etc/reader.conf.d" \
  "${APP_DIR}/usr/lib/pcsc/drivers" \
  "${APP_DIR}/usr/bin" \
  "${APP_DIR}/usr/libexec"

cp bin/nim_status_client "${APP_DIR}/usr/bin"
cp bin/StatusQ/* "${APP_DIR}/usr/lib"
cp -R bin/lib/* "${APP_DIR}/usr/lib"
cp nim-status.desktop "${APP_DIR}/."
cp status.png "${APP_DIR}/status.png"
cp status.png "${APP_DIR}/usr/"
cp -R resources.rcc "${APP_DIR}/usr/"
cp vendor/status-go/build/bin/libstatus.so "${APP_DIR}/usr/lib/"
cp vendor/status-go/build/bin/libstatus.so.0 "${APP_DIR}/usr/lib/"
cp "${STATUSKEYCARDGO}" "${APP_DIR}/usr/lib/"
if [ "${USE_NWAKU}" = "true" ]; then
  cp ${NWAKU_SOURCE_DIR}/build/libwaku.so "${APP_DIR}/usr/lib/"
fi
cp ${NIM_SDS_SOURCE_DIR}/build/libsds.so "${APP_DIR}/usr/lib/"
cp "${FCITX5_QT}" "${APP_DIR}/usr/plugins/platforminputcontexts/"

# Copy dependencies, which linuxdeployqt can't manage from nix store or system (FHS)
if [[ -z "${IN_NIX_SHELL}" ]]; then
    echo "Bundling gstreamer 1.0..."
    cp -r /usr/lib/x86_64-linux-gnu/nss "${APP_DIR}/usr/lib/"
    cp -P /usr/lib/x86_64-linux-gnu/libgst* "${APP_DIR}/usr/lib/"
    cp -r /usr/lib/x86_64-linux-gnu/gstreamer-1.0 "${APP_DIR}/usr/lib/"
    cp -r /usr/lib/x86_64-linux-gnu/gstreamer1.0 "${APP_DIR}/usr/lib/"

    # fix for missing QtWebEngineProcess since QT6
    cp /opt/qt/6.9.2/gcc_64/libexec/QtWebEngineProcess "${APP_DIR}/usr/libexec/"
    chmod +x "${APP_DIR}/usr/libexec/QtWebEngineProcess"

    # to fix : [0912/162517.794426:FATAL:v8_initializer.cc(625)] Error loading V8 startup snapshot file
    echo "Bundling Qt WebEngine resources..."
    cp /opt/qt/6.9.2/gcc_64/resources/* "${APP_DIR}/usr/libexec/"
    cp -r /opt/qt/6.9.2/gcc_64/translations/qtwebengine_locales "${APP_DIR}/usr/libexec/"

    echo "Bundling pcsc-lite 2.2.3..."
    cp -L /usr/local/lib/x86_64-linux-gnu/libpcsclite.so* "${APP_DIR}/usr/lib/"
    cp -L /usr/local/lib/x86_64-linux-gnu/libpcsclite_real.so* "${APP_DIR}/usr/lib/"
    cp -L /usr/local/lib/x86_64-linux-gnu/pkgconfig/libpcsclite.pc "${APP_DIR}/usr/lib/"

    chmod 755 "${APP_DIR}/usr/lib/libpcsclite.so"*
    chmod 755 "${APP_DIR}/usr/lib/libpcsclite_real.so"*
    chmod 755 "${APP_DIR}/usr/lib/libpcsclite.pc"

    echo "Bundling pcscd..."
    cp -L "/usr/local/sbin/pcscd"* "${APP_DIR}/usr/bin/"
    chmod 755 "${APP_DIR}/usr/bin/pcscd"*

    echo "Bundling Dash shell..."
    cp /usr/bin/dash "${APP_DIR}/usr/bin/"
    ln -rs "${APP_DIR}/usr/bin/dash" "${APP_DIR}/usr/bin/sh"

    echo "Bundling xdg-open wrapper..."
    cp scripts/xdg-open-wrapper.sh "${APP_DIR}/usr/bin/xdg-open"
else
    mkdir -p "${APP_DIR}"/usr/lib/{gstreamer1.0,gstreamer-1.0,nss}
    mkdir -p "${APP_DIR}"/usr/libexec

    echo "${GST_PLUGIN_SYSTEM_PATH_1_0}" | tr ':' '\n' | sort -u | xargs -I {} find {} -name "*.so" | xargs -I {} cp {} "${APP_DIR}/usr/lib/gstreamer-1.0/"
    cp -r "${GSTREAMER_PATH}/libexec/gstreamer-1.0" "${APP_DIR}/usr/lib/gstreamer1.0/"
    cp "${LIBKRB5_PATH}/lib/libcom_err.so.3" "${APP_DIR}/usr/lib/libcom_err.so.3"
    cp "${NSS_PATH}"/lib/{libfreebl3,libfreeblpriv3,libnssckbi,libnssdbm3,libsoftokn3}.{chk,so} "${APP_DIR}/usr/lib/nss/" || true
    cp "${QTWEBENGINE_PATH}/libexec/QtWebEngineProcess" "${APP_DIR}/usr/libexec/QtWebEngineProcess"
    cp "${QTWEBENGINE_PATH}"/resources/* "${APP_DIR}/usr/libexec/"
    cp -r "${QTWEBENGINE_PATH}/translations/qtwebengine_locales" "${APP_DIR}/usr/libexec/"

    #TODO: bundle pcsc-lite and pcscd in nix-shell

    chmod -R u+w "${APP_DIR}/usr"
fi
