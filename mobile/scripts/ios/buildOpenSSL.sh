#!/usr/bin/env bash
set -ef pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OPENSSL=${OPENSSL:-"../vendors/openssl"}
OS=${OS:-"ios"}
ARCH=${ARCH:-"x86_64"}
SDK=${SDK:-"iphonesimulator"}
LIB_PATH=${LIB_PATH:-"../lib/ios"}
LIB_EXT=${LIB_EXT:-".a"}
ANDROID_API=${ANDROID_API:-28}
BUILD_DIR=${BUILD_DIR:-"build-${TARGET}"}

TARGET="${OS}-${ARCH}"
SSL_BUILD_DIR=${BUILD_DIR}/openssl-${TARGET}
CRYPTO_OUTPUT_LIB=${LIB_PATH}/libcrypto_3${LIB_EXT}
SSL_OUTPUT_LIB=${LIB_PATH}/libssl_3${LIB_EXT}

PLATFORM_ARGS=""

if [[ "$OS" == "ios" ]]; then
  if [[ "$SDK" == "iphonesimulator" ]]; then
    case ${ARCH} in
    "x86_64") TARGET="iossimulator-x86_64-xcrun" ;;
    "arm64") TARGET="iossimulator-arm64-xcrun" ;;
    "x86") TARGET="iossimulator-i386-xcrun" ;;
    # default to system architecture
    # missing armv7 support for ios simulator
    *) TARGET="iossimulator-xcrun" ;;
    esac
  elif [[ "$SDK" == "iphoneos" ]]; then
    case ${ARCH} in
    "arm64") TARGET="ios64-xcrun" ;;
    *) TARGET="ios-xcrun" ;;
    esac
  fi
fi

if [[ "$OS" == "android" ]]; then
  PLATFORM_CONFIG_ARGS="-U__ANDROID_API__ -D__ANDROID_API__=${ANDROID_API}"
  PLATFORM_BUILD_ARGS="SHLIB_VERSION_NUMBER="
  cleanup() {
    if [[ "$OS" == "android" ]]; then
      patch -d ${OPENSSL} -R -p0 <"${SCRIPT_DIR}/openssl-patch.diff"
    fi
  }

  trap cleanup EXIT
  patch -d ${OPENSSL} -p0 <"${SCRIPT_DIR}/openssl-patch.diff"
fi

echo "Building OpenSSL for $TARGET with platform config args $PLATFORM_CONFIG_ARGS"

mkdir -p ${SSL_BUILD_DIR}

(
  cd ${SSL_BUILD_DIR}
  
  # - no-module: Makes legacy provider built-in to libcrypto (not a separate module)
  # - enable-legacy: Enables legacy algorithms including DES
  # This is required for GlobalPlatform SCP02 which uses single-DES
  # Reference: https://github.com/openssl/openssl/discussions/25793
  
  # Platform-specific config
  if [[ "$OS" == "ios" ]]; then
    # iOS uses static libraries (.a files)
    SHARED_FLAG="no-shared"
  else
    # Android uses shared libraries (.so files)
    SHARED_FLAG="shared"
  fi
  
  ${OPENSSL}/Configure --release "$TARGET" $PLATFORM_CONFIG_ARGS \
    no-module \
    enable-legacy \
    enable-des \
    enable-md2 \
    enable-rc5 \
    $SHARED_FLAG \
    no-tests \
    no-ui-console
  # Rebuilding isn't working with the default target, so we need to clean and build again
  make clean
  make -j$(sysctl -n hw.ncpu) $PLATFORM_BUILD_ARGS build_libs
)

mkdir -p "$LIB_PATH"

# For shared libraries (.so), OpenSSL creates libcrypto_3.so and libssl_3.so
# For static libraries (.a), it creates libcrypto.a and libssl.a
if [[ "$LIB_EXT" == ".so" ]]; then
  SRC_CRYPTO="${SSL_BUILD_DIR}/libcrypto_3${LIB_EXT}"
  SRC_SSL="${SSL_BUILD_DIR}/libssl_3${LIB_EXT}"
else
  SRC_CRYPTO="${SSL_BUILD_DIR}/libcrypto${LIB_EXT}"
  SRC_SSL="${SSL_BUILD_DIR}/libssl${LIB_EXT}"
fi

cp "${SRC_CRYPTO}" "$CRYPTO_OUTPUT_LIB"
cp "${SRC_SSL}" "$SSL_OUTPUT_LIB"
