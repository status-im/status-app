#!/usr/bin/env bash
set -ef pipefail
set -o xtrace

QRCODEGEN=${QRCODEGEN:-"../vendors/status-desktop/vendor/QR-Code-generator/c"}
LIB_DIR=${LIB_DIR}

echo "Building QRCodeGen for ${ARCH} using compiler: ${CC}"
make -C "${QRCODEGEN}" clean
make -C "${QRCODEGEN}" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"

mkdir -p "${LIB_DIR}"
cp "${QRCODEGEN}/libqrcodegen.a" "${LIB_DIR}/libqrcodegen.a"
