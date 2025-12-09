#!/usr/bin/env bash
set -ef pipefail

BASEDIR=$(dirname "$0")

# Load common config variables
source "${BASEDIR}/commonCmakeConfig.sh"

KEYCARD_QT=${KEYCARD_QT:="/Users/alexjbanca/Repos/keycard-qt"}
LIB_DIR=${LIB_DIR}
LIB_EXT=${LIB_EXT:=".a"}

BUILD_DIR="${KEYCARD_QT}/build/${OS}/${ARCH}"
BUILD_SHARED_LIBS=ON

if [[ "${LIB_EXT}" == ".a" ]]; then
    BUILD_SHARED_LIBS=OFF
fi

echo "Building keycard-qt for ${ARCH} using compiler: ${CC} with CMAKE_TOOLCHAIN_FILE ${CMAKE_TOOLCHAIN_FILE}"
echo "BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}"

printf 'COMMON_CMAKE_CONFIG: %s\n' "${COMMON_CMAKE_CONFIG[@]}"

# Set OpenSSL paths for secure channel cryptography
# We need BOTH the source and build include directories:
# - Build dir has generated headers (configuration.h, opensslv.h, etc.)
# - Source dir has the main API headers (ec.h, evp.h, etc.)
MOBILE_ROOT="$(cd "${BASEDIR}/.." && pwd)"
# Note: BUILD_PATH from the makefile includes qt6 subdirectory for android
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
OPENSSL_SSL_LIBRARY="${LIB_DIR}/libssl_3${LIB_EXT}"

echo "OpenSSL paths:"
echo "  OPENSSL_BUILD_DIR=${OPENSSL_BUILD_DIR}"
echo "  OPENSSL_BUILD_INCLUDE_DIR=${OPENSSL_BUILD_INCLUDE_DIR}"
echo "  OPENSSL_SOURCE_INCLUDE_DIR=${OPENSSL_SOURCE_INCLUDE_DIR}"
echo "  OPENSSL_CRYPTO_LIBRARY=${OPENSSL_CRYPTO_LIBRARY}"
echo "  OPENSSL_SSL_LIBRARY=${OPENSSL_SSL_LIBRARY}"

# Configure with CMake
# Pass both OpenSSL include directories (build + source)
CMAKE_ARGS=(
    "${COMMON_CMAKE_CONFIG[@]}"
    -DBUILD_TESTING=OFF
    -DBUILD_EXAMPLES=OFF
    -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
    -DOPENSSL_BUILD_INCLUDE_DIR="${OPENSSL_BUILD_INCLUDE_DIR}"
    -DOPENSSL_SOURCE_INCLUDE_DIR="${OPENSSL_SOURCE_INCLUDE_DIR}"
    -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_CRYPTO_LIBRARY}"
    -DOPENSSL_SSL_LIBRARY="${OPENSSL_SSL_LIBRARY}"
)

# Add Android-specific flags only for Android builds
if [[ "$OS" == "android" ]]; then
    CMAKE_ARGS+=(
        -DUSE_ANDROID_NFC_BACKEND=OFF
        -DENABLE_QT_NFC_ANDROID_WORKAROUNDS=ON
    )
    echo "Android build: Using Android NFC backend"
else
    echo "iOS build: Using standard Qt NFC backend (CoreNFC)"
fi

cmake -S "${KEYCARD_QT}" -B "${BUILD_DIR}" "${CMAKE_ARGS[@]}"

# Build the library
make -C "${BUILD_DIR}" keycard-qt -j "$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

# Create lib directory
mkdir -p "${LIB_DIR}"

# Find and copy the built library
KEYCARD_QT_LIB=$(find "${BUILD_DIR}" -name "libkeycard-qt${LIB_EXT}" -o -name "libkeycard-qt.dylib" | grep -v "\.so\." | head -n 1)

if [[ -z "${KEYCARD_QT_LIB}" ]]; then
    # Try alternative patterns for static library
    KEYCARD_QT_LIB=$(find "${BUILD_DIR}" -name "libkeycard-qt.a" | head -n 1)
fi

if [[ -z "${KEYCARD_QT_LIB}" ]]; then
    echo "Error: Could not find keycard-qt library in ${BUILD_DIR}"
    exit 1
fi

cp "${KEYCARD_QT_LIB}" "${LIB_DIR}/libkeycard-qt${LIB_EXT}"
echo "Copied ${KEYCARD_QT_LIB} to ${LIB_DIR}/libkeycard-qt${LIB_EXT}"

# Update Android NFC backend selection in manifest
if [[ "${USE_ANDROID_NFC_BACKEND:-OFF}" == "ON" ]]; then
    echo "Android NFC backend enabled - updating manifest resources..."
    BOOLS_XML="${MOBILE_ROOT}/android/qt6/res/values/bools.xml"
    if [[ -f "${BOOLS_XML}" ]]; then
        sed -i.bak 's/<bool name="use_qt_nfc">true<\/bool>/<bool name="use_qt_nfc">false<\/bool>/' "${BOOLS_XML}"
        echo "Updated ${BOOLS_XML} to disable Qt NFC (use Android NFC backend)"
    else
        echo "Warning: ${BOOLS_XML} not found, cannot update NFC backend selection"
    fi
else
    echo "Qt NFC backend with workarounds enabled (default)"
fi

