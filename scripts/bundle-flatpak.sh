#!/usr/bin/env bash
# Build the flatpak and export a single-file .flatpak bundle.
#
# Required env (set by Makefile):
#   FLATPAK_BUILD_DIR      - working dir for flatpak-builder
#   FLATPAK_REPO_DIR       - OSTree repo to export into
#   STATUS_CLIENT_FLATPAK  - path of the .flatpak file to produce
# Optional:
#   LINUX_GPG_PRIVATE_KEY_FILE - if set, sign the resulting bundle
set -eo pipefail

GIT_ROOT=$(cd "${BASH_SOURCE%/*}" && git rev-parse --show-toplevel)
cd "$GIT_ROOT"

: "${FLATPAK_BUILD_DIR:?FLATPAK_BUILD_DIR must be set}"
: "${FLATPAK_REPO_DIR:?FLATPAK_REPO_DIR must be set}"
: "${STATUS_CLIENT_FLATPAK:?STATUS_CLIENT_FLATPAK must be set}"

APP_ID="app.status.StatusDesktop"
FLATPAK_MANIFEST="${FLATPAK_MANIFEST:-${APP_ID}.yml}"

# Required inputs from earlier targets
[[ -f "bin/nim_status_client" ]] || { echo "ERROR: bin/nim_status_client missing. Run 'make nim_status_client' first."; exit 1; }

mkdir -p "$(dirname "${STATUS_CLIENT_FLATPAK}")"
rm -rf "${FLATPAK_BUILD_DIR}" "${FLATPAK_REPO_DIR}"

# libsds.so is built outside the workspace tree (at $NIM_SDS_SOURCE_DIR);
# bring it into a known relative path so the manifest can reference it as
# a regular `type: file` source instead of needing host access.
: "${NIM_SDS_SOURCE_DIR:?NIM_SDS_SOURCE_DIR must be set}"
mkdir -p tmp/linux/flatpak/in
cp -P "${NIM_SDS_SOURCE_DIR}/build/libsds.so" tmp/linux/flatpak/in/

# Qt location for the in-sandbox copy step, handed across via qt.env (the
# sandbox can't read our env). Override: QT_DIR=/path/to/Qt/6.x/gcc_64 make flatpak
QT_DIR="${QT_DIR:-/opt/qt/6.11.0/gcc_64}"
[[ -d "$QT_DIR" ]] || { echo "ERROR: Qt not found at QT_DIR=$QT_DIR. Set QT_DIR to your Qt 6 gcc_64 dir."; exit 1; }
printf 'QT_DIR=%q\n' "$QT_DIR" > tmp/linux/flatpak/in/qt.env

# flatpak-builder
#   Reads ${FLATPAK_MANIFEST}, fetches/copies each source, runs each
#   module's build (libcanberra, pcsc-lite, libusb, ccid, then our
#   "simple" status-desktop module which calls flatpak-copy-to-app.sh
#   to install /app/*), and exports the result into ${FLATPAK_REPO_DIR}.
#   - --force-clean wipes ${FLATPAK_BUILD_DIR} to guarantee a fresh build
#   - --disable-rofiles-fuse avoids needing FUSE mounts inside CI
#   - --disable-cache forces a full rebuild every run (no per-module cache)
echo "Running flatpak-builder..."
flatpak-builder \
  --force-clean \
  --disable-rofiles-fuse \
  --disable-cache \
  --repo="${FLATPAK_REPO_DIR}" \
  --jobs="$(nproc)" \
  "${FLATPAK_BUILD_DIR}" \
  "${FLATPAK_MANIFEST}"

# flatpak build-bundle
#   Pulls the just-exported app ref out of ${FLATPAK_REPO_DIR} and
#   serializes it as a single self-contained .flatpak file that users
#   can install with `flatpak install --user <file>` without needing
#   our repo configured.
echo "Exporting bundle to ${STATUS_CLIENT_FLATPAK}..."
flatpak build-bundle "${FLATPAK_REPO_DIR}" "${STATUS_CLIENT_FLATPAK}" "${APP_ID}"

ls -lh "${STATUS_CLIENT_FLATPAK}"

if [[ -n "${LINUX_GPG_PRIVATE_KEY_FILE:-}" ]]; then
  echo "Signing ${STATUS_CLIENT_FLATPAK}..."
  "${GIT_ROOT}/scripts/sign-linux-file.sh" "${STATUS_CLIENT_FLATPAK}"
fi
