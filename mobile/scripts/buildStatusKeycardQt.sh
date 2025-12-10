#!/usr/bin/env bash
set -ef pipefail

BASEDIR=$(dirname "$0")

# Load common config variables
source "${BASEDIR}/commonCmakeConfig.sh"

STATUS_KEYCARD_QT=${STATUS_KEYCARD_QT:="../vendors/status-desktop"}
KEYCARD_QT=${KEYCARD_QT:=""}
LIB_DIR=${LIB_DIR}
LIB_EXT=${LIB_EXT:=".a"}

BUILD_DIR=${BUILD_DIR:="${STATUS_KEYCARD_QT}/build/${OS}/${ARCH}"}
BUILD_SHARED_LIBS=ON

if [[ "${LIB_EXT}" == ".a" ]]; then
    BUILD_SHARED_LIBS=OFF
fi

echo "Building status-keycard-qt for ${ARCH} using compiler: ${CC}"
echo "BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}"

printf 'COMMON_CMAKE_CONFIG: %s\n' "${COMMON_CMAKE_CONFIG[@]}"

# Set OpenSSL paths (REQUIRED for key derivation in session_manager.cpp)
MOBILE_ROOT="$(cd "${BASEDIR}/.." && pwd)"
if [[ "$OS" == "android" ]]; then
    OPENSSL_BUILD_DIR="${MOBILE_ROOT}/build/${OS}/qt6/openssl-${OS}-${ARCH}"
elif [[ "$OS" == "ios" ]]; then
    # iOS OpenSSL is built per-architecture
    OPENSSL_BUILD_DIR="${MOBILE_ROOT}/build/${OS}/qt6/openssl-${OS}-${ARCH}"
else
    OPENSSL_BUILD_DIR="${MOBILE_ROOT}/build/${OS}/openssl-${OS}-${ARCH}"
fi
OPENSSL_BUILD_INCLUDE_DIR="${OPENSSL_BUILD_DIR}/include"
OPENSSL_SOURCE_INCLUDE_DIR="${MOBILE_ROOT}/vendors/openssl/include"
OPENSSL_CRYPTO_LIBRARY="${LIB_DIR}/libcrypto_3${LIB_EXT}"

echo "OpenSSL paths:"
echo "  Build include dir: ${OPENSSL_BUILD_INCLUDE_DIR}"
echo "  Source include dir: ${OPENSSL_SOURCE_INCLUDE_DIR}"
echo "  Crypto library: ${OPENSSL_CRYPTO_LIBRARY}"

# Configure with CMake
# Use local keycard-qt for faster development builds (FetchContent will use this)
# If KEYCARD_QT path doesn't exist, FetchContent will clone from GitHub
if [[ -d "${KEYCARD_QT}" ]]; then
    echo "Using local keycard-qt from: ${KEYCARD_QT}"
    KEYCARD_QT_SOURCE_DIR_ARG="-DKEYCARD_QT_SOURCE_DIR=${KEYCARD_QT}"
else
    echo "Local keycard-qt not found, will fetch from GitHub"
    KEYCARD_QT_SOURCE_DIR_ARG=""
fi

cmake -S "${STATUS_KEYCARD_QT}" -B "${BUILD_DIR}" \
    "${COMMON_CMAKE_CONFIG[@]}" \
    -DBUILD_TESTING=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} \
    ${KEYCARD_QT_SOURCE_DIR_ARG} \
    -DOPENSSL_BUILD_INCLUDE_DIR="${OPENSSL_BUILD_INCLUDE_DIR}" \
    -DOPENSSL_SOURCE_INCLUDE_DIR="${OPENSSL_SOURCE_INCLUDE_DIR}" \
    -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_CRYPTO_LIBRARY}"

# Build the library
make -C "${BUILD_DIR}" status-keycard-qt -j "$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

# Create lib directory
mkdir -p "${LIB_DIR}"

# Find and copy the built library
# Note: keycard-qt is built as a static library and linked into libstatus-keycard-qt,
# so we only need to copy one library file
STATUS_KEYCARD_QT_LIB=$(find "${BUILD_DIR}" -name "libstatus-keycard-qt${LIB_EXT}" -o -name "libstatus-keycard-qt.dylib" | grep -v "\.so\." | head -n 1)

if [[ -z "${STATUS_KEYCARD_QT_LIB}" ]]; then
    # Try alternative patterns for static library
    STATUS_KEYCARD_QT_LIB=$(find "${BUILD_DIR}" -name "libstatus-keycard-qt.a" | head -n 1)
fi

if [[ -z "${STATUS_KEYCARD_QT_LIB}" ]]; then
    echo "Error: Could not find status-keycard-qt library in ${BUILD_DIR}"
    echo "Build directory contents:"
    find "${BUILD_DIR}" -name "*.so" -o -name "*.a" -o -name "*.dylib" | head -20
    exit 1
fi

cp "${STATUS_KEYCARD_QT_LIB}" "${LIB_DIR}/libstatus-keycard-qt${LIB_EXT}"
echo "Copied ${STATUS_KEYCARD_QT_LIB} to ${LIB_DIR}/libstatus-keycard-qt${LIB_EXT}"

