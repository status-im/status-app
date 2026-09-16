#!/usr/bin/env bash
set -eo pipefail

GO_VERSION="1.24.7"
GO_INSTALL_DIR="/usr/local/go"
QT_VERSION="6.11.0"
CMAKE_VERSION="3.31.6"
CMAKE_BREW_FORMULA_COMMIT_SHA="b4e46db74e74a8c1650b38b1da222284ce1ec5ce"
CMAKE_FORMULA_URL="https://raw.githubusercontent.com/Homebrew/homebrew-core/${CMAKE_BREW_FORMULA_COMMIT_SHA}/Formula/c/cmake.rb"
BREW_PREFIX=$(brew --prefix)
CMAKE_INSTALL_DIR="${BREW_PREFIX}/Cellar/cmake/${CMAKE_VERSION}"

# Prevent Homebrew from uprading things without permission.
export HOMEBREW_NO_INSTALL_UPGRADE=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
export HOMEBREW_NO_ENV_HINTS=1

function check_version {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: Installer intended for MacOS/Darwin!"
    exit 1
  fi
}

function install_build_dependencies {
  echo "Install build dependencies"
  brew install pkg-config libtool jq node@22 yarn protobuf aqtinstall xcbeautify
}

# nimble goes into a directory with no `nim` beside it: a nim there would shadow the pin.
NIMBLE_VERSION="0.24.1"
NIMBLE_SHA256_arm64="a4b9b4a98f109f5b8916bbc2ad67c2df2226fff79d29bdbdc51acb1fcc58d415"
NIMBLE_SHA256_x86_64="ec8984378ca54092fbe8e75d6fa307eb93880f71c17b77313e58a837a5a6a2f4"

function install_nimble {
  echo "Installing nimble ${NIMBLE_VERSION}"
  local asset sha
  if [[ "$(uname -m)" == "arm64" ]]; then
    asset="nimble-macosx_aarch64.tar.gz"; sha="${NIMBLE_SHA256_arm64}"
  else
    asset="nimble-macosx_x64.tar.gz"; sha="${NIMBLE_SHA256_x86_64}"
  fi
  curl -fsSLo /tmp/nimble.tar.gz \
    "https://github.com/nim-lang/nimble/releases/download/v${NIMBLE_VERSION}/${asset}"
  echo "${sha}  /tmp/nimble.tar.gz" | shasum -a 256 -c
  mkdir -p "${HOME}/.local/bin"
  tar -xzf /tmp/nimble.tar.gz -C "${HOME}/.local/bin"
  rm -f /tmp/nimble.tar.gz
  chmod 755 "${HOME}/.local/bin/nimble"
}

function install_qt {
  echo "Installing QT ${QT_VERSION}"
  aqt install-qt mac desktop ${QT_VERSION} clang_64 -m all
  aqt install-qt mac ios ${QT_VERSION} ios -m all
}

function install_cmake {
  echo "Installing CMake ${CMAKE_VERSION}"
  TAP_DIR="${BREW_PREFIX}/Library/Taps/local/homebrew-tmp/Formula"
  mkdir -p "${TAP_DIR}"
  curl -s -o "${TAP_DIR}/cmake.rb" "${CMAKE_FORMULA_URL}"
  brew uninstall cmake || true
  brew install 'local/tmp/cmake'
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
    ["amd64"]="1cbd7af6f07bc6fa1f8672f9b913c961986864100e467e0acdc942e0ae46fe68"
    ["arm64"]="25c64bfa8a8fd8e7f62fb54afa4354af8409a4bb2358c2699a1003b733e6fce5"
  )
  echo "Install GoLang ${GO_VERSION}"
  GO_ARCH=$(get_go_arch)
  GO_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  GO_TARBALL="go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz"
  # example: https://dl.google.com/go/go1.23.10.darwin-amd64.tar.gz
  wget -q "https://dl.google.com/go/${GO_TARBALL}" -O "${GO_TARBALL}"
  echo "${GO_SHA256_MAP[${GO_ARCH}]} ${GO_TARBALL}" | sha256sum -c
  tar -C "${GO_INSTALL_DIR%/go}" -xzf "${GO_TARBALL}"
  rm "${GO_TARBALL}"
  ln -s "${GO_INSTALL_DIR}/bin/go" /usr/local/bin
}

function success_message {
  msg="
SUCCESS!

Before you attempt to build status-desktop you'll need a few environment variables set:

export PATH=\$QTDIR:\$QTDIR/bin:\$HOME/.local/bin:\$PATH
export CMAKE_PREFIX_PATH=${CMAKE_INSTALL_DIR}
"
  echo $msg
}

if [ "$0" = "$BASH_SOURCE" ]; then
    check_version
    install_build_dependencies
    install_nimble
    install_cmake
    install_qt
    install_golang
    success_message
fi
