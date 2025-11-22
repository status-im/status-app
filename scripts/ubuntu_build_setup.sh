#!/usr/bin/env bash
set -eo pipefail

GO_VERSION="1.24.7"
GO_INSTALL_DIR="/usr/local/go"
QT_VERSION="6.9.2"
QT_INSTALL_DIR="/opt/qt"

function check_version {
  source /etc/os-release
  [[ "${NAME}" != "Ubuntu" ]] && { echo "ERROR: This script only supports Ubuntu!"; exit 1; }
  [[ "${VERSION_ID}" != '22.04' ]] && { echo "ERROR: Ubuntu version not 22.04!"; exit 1; }
}

function install_build_dependencies {
  echo "Install build dependencies"
  apt update
  apt install -yq git wget build-essential \
    cmake extra-cmake-modules pkg-config protoc-gen-go \
    mesa-common-dev unixodbc-dev libpq-dev libglu1-mesa-dev libpcsclite-dev \
    libssl-dev libpulse-mainloop-glib0 libxkbcommon-x11-dev
}

function install_release_dependencies {
  echo "Install release dependencies"
  mkdir -p /usr/local/bin
  LINUXDEPLOYQT='linuxdeployqt-20230423-8428c59-x86_64.AppImage'
  curl -L "https://status-misc.ams3.digitaloceanspaces.com/desktop/${LINUXDEPLOYQT}" \
    -o /usr/local/bin/linuxdeployqt
  chmod a+x /usr/local/bin/linuxdeployqt

  apt install -yq gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
      gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools \
      gstreamer1.0-alsa gstreamer1.0-pulseaudio
}

function install_flatpak_dependencies {
  echo "Install flatpak dependencies"
  apt install -yq flatpak flatpak-builder elfutils appstream
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install --user -y flathub org.freedesktop.Platform//24.08
  flatpak install --user -y flathub org.freedesktop.Sdk//24.08
}

function install_runtime_dependencies {
  echo "Install runtime dependencies"
  # xvfb is needed in order run squish test into a headless server
  apt install -yq libxcomposite-dev xvfb libxft-dev \
      libxcb-shape0 libxcb-randr0 libxcb-render0 libxcb-icccm4 libxcb-image0 \
      libxcb-keysyms1 libxcb-render-util0 libxcb-xinerama0
}

function install_qt {
  echo "Install QT"
  apt install -y python3-pip
  pip install -U pip
  pip install aqtinstall
  aqt install-qt linux desktop ${QT_VERSION} linux_gcc_64 -m qtwebchannel \
  qtwebview qtwebsockets qt5compat \
  qtmultimedia qtwebengine qtpositioning qthttpserver \
  qtserialport qtshadertools qtimageformats qtscxml -O ${QT_INSTALL_DIR}
}

function get_go_arch {
  case "$(uname -m)" in
    "x86_64")  echo "amd64" ;;
    "aarch64") echo "arm64" ;;
    "armv*")   echo "armv6l" ;;
    *)         echo "UNKNOWN" ;;
  esac
}

function install_golang {
  if [[ -x "$(command -v go)" ]]; then
    echo "Already present: $(go version)"
    return
  fi
  declare -A GO_SHA256_MAP
  GO_SHA256_MAP=(
    ["amd64"]="535f9f81802499f2a7dbfa70abb8fda3793725fcc29460f719815f6e10b5fd60"
    ["arm64"]="bfb1f1df7173f44648ee070a39ab0481068632f595305a699d89cd56a33b8081"
    ["armv6l"]="b6e00c9a72406d394b9f167e74670e28b72ed559cca8115b21be1cb9d5316cb4"
  )
  echo "Install GoLang ${GO_VERSION}"
  GO_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  GO_ARCH=$(get_go_arch)
  GO_TARBALL="go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz"
  # example: https://dl.google.com/go/go1.23.10.linux-amd64.tar.gz
  wget -q "https://dl.google.com/go/${GO_TARBALL}" -O "${GO_TARBALL}"
  echo "${GO_SHA256_MAP[${GO_ARCH}]} ${GO_TARBALL}" | sha256sum -c
  tar -C "${GO_INSTALL_DIR}" -xzf "${GO_TARBALL}"
  rm "${GO_TARBALL}"
  ln -s "${GO_INSTALL_DIR}/go/bin/go" /usr/local/bin
}

function success_message {
  msg="
SUCCESS!

Before you attempt to build status-desktop you'll need a few environment variables set:

export QTDIR=${QT_INSTALL_DIR}/${QT_VERSION}/gcc_64
export PATH=\$QTDIR:\$QTDIR/bin:\$(go env GOPATH)\bin:$PATH
"
  echo $msg
}

if [ "$0" = "$BASH_SOURCE" ]; then
    check_version
    install_build_dependencies
    install_release_dependencies
    install_flatpak_dependencies
    install_runtime_dependencies
    install_qt
    install_golang
    success_message
fi
