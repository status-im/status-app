#!/usr/bin/env bash
# Build script for Status Desktop Flatpak.
#
# Flow:
#   1. stage_build_dir  – copy libraries into the project root so the
#                          flatpak-builder sandbox can access them.
#   2. bundle_flatpak   – invoke flatpak-builder and export the bundle.
set -eo pipefail

GIT_ROOT=$(cd "${BASH_SOURCE%/*}" && git rev-parse --show-toplevel)
cd "$GIT_ROOT"

# shellcheck source=scripts/lib-deps.sh
source "$(dirname "$0")/lib-deps.sh"

# Configuration (can be overridden via environment)
FLATPAK_MANIFEST="${FLATPAK_MANIFEST:-app.status.desktop.yml}"
FLATPAK_BUILD_DIR="${FLATPAK_BUILD_DIR:-tmp/flatpak-build}"
FLATPAK_REPO_DIR="${FLATPAK_REPO_DIR:-tmp/flatpak-repo}"
OUTPUT_PATH="${STATUS_CLIENT_FLATPAK:-pkg/status-desktop.flatpak}"

# ---------- Flatpak-only library helpers ----------

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

# ---------- Step 1: Stage build directory ----------

stage_build_dir() {
  echo "Staging libraries for flatpak-builder..."
  rm -rf "${FLATPAK_BUILD_DIR}" "${FLATPAK_REPO_DIR}" qt-libs native-libs sys-libs
  mkdir -p "$(dirname "${OUTPUT_PATH}")" native-libs sys-libs

  copy_qt qt-libs
  copy_native_libs native-libs
  copy_system_libs sys-libs
  copy_krb5_libs sys-libs
}

# ---------- Step 2: Bundle flatpak ----------

bundle_flatpak() {
  echo "Building Flatpak..."
  flatpak-builder \
    --force-clean \
    --disable-rofiles-fuse \
    --disable-cache \
    --repo="${FLATPAK_REPO_DIR}" \
    --jobs="$(nproc)" \
    "${FLATPAK_BUILD_DIR}" \
    "${FLATPAK_MANIFEST}"

  echo "Creating bundle..."
  flatpak build-bundle "${FLATPAK_REPO_DIR}" "${OUTPUT_PATH}" app.status.desktop

  # Clean up staging directories
  rm -rf qt-libs native-libs sys-libs

  echo ""
  echo "Build Complete..."
  ls -lh "${OUTPUT_PATH}"

  # Optional signing
  if [[ -n "${LINUX_GPG_PRIVATE_KEY_FILE:-}" ]]; then
    echo "Signing..."
    "${GIT_ROOT}/scripts/sign-linux-file.sh" "${OUTPUT_PATH}"
  fi
}

# ---------- Main ----------

# Validate prerequisites
[[ -f "bin/nim_status_client" ]] || { echo "ERROR: bin/nim_status_client not found. Run 'make nim_status_client' first."; exit 1; }
[[ -d "${QTDIR:-}" ]] || { echo "ERROR: Qt not found at ${QTDIR:-<unset>}. Set QTDIR."; exit 1; }

stage_build_dir
bundle_flatpak
