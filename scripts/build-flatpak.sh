#!/usr/bin/env bash
# Build script for Status Desktop Flatpak
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

# Validate prerequisites
[[ -f "bin/nim_status_client" ]] || { echo "ERROR: bin/nim_status_client not found. Run 'make nim_status_client' first."; exit 1; }
[[ -d "${QTDIR:-}" ]] || { echo "ERROR: Qt not found at ${QTDIR:-<unset>}. Set QTDIR."; exit 1; }

# Clean and prepare staging directories
rm -rf "${FLATPAK_BUILD_DIR}" "${FLATPAK_REPO_DIR}" qt-libs native-libs sys-libs
mkdir -p "$(dirname "${OUTPUT_PATH}")" native-libs sys-libs

# Stage libraries into project root so flatpak-builder sandbox can access them
copy_qt qt-libs
copy_native_libs native-libs
copy_system_libs sys-libs
copy_krb5_libs sys-libs

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

