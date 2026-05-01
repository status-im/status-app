#!/usr/bin/env bash
set -ef pipefail

DOTHERSIDE=${DOTHERSIDE:-"../vendors/status-desktop/vendor/DOtherSide"}
LIB_DIR=${LIB_DIR}
LIB_SUFFIX=${LIB_SUFFIX:-""}
LIB_EXT=${LIB_EXT:-".a"}

BASEDIR=$(dirname "$0")

# Load common config variables
source "$BASEDIR/commonCmakeConfig.sh"

BUILD_DIR="${DOTHERSIDE}/build/${OS}"

if [[ "${LIB_EXT}" == ".so" ]]; then
    ENABLE_DYNAMIC_LIBS=ON
    ENABLE_STATIC_LIBS=OFF
    DOTHERSIDE_LIB_NAME="libDOtherSide${LIB_SUFFIX}${LIB_EXT}"
fi

if [[ "${LIB_EXT}" == ".a" ]]; then
    ENABLE_DYNAMIC_LIBS=OFF
    ENABLE_STATIC_LIBS=ON
    DOTHERSIDE_LIB_NAME="libDOtherSideStatic${LIB_SUFFIX}${LIB_EXT}"
fi

echo "Building DOtherSide for ${ARCH} using compiler: ${CC}"

printf 'COMMON_CMAKE_CONFIG: %s\n' "${COMMON_CMAKE_CONFIG[@]}"

EXTRA_CMAKE_ARGS=()
if [[ -n "${QML_DEBUG_PORT}" ]]; then
    EXTRA_CMAKE_ARGS+=("-DQML_DEBUG_PORT=${QML_DEBUG_PORT}")
fi

cmake -S "${DOTHERSIDE}" -B "${BUILD_DIR}" \
    "${COMMON_CMAKE_CONFIG[@]}" \
    "${EXTRA_CMAKE_ARGS[@]}" \
    -DENABLE_DOCS:BOOL=OFF \
    -DENABLE_DYNAMIC_LIBS:BOOL="${ENABLE_DYNAMIC_LIBS}" \
    -DENABLE_STATIC_LIBS:BOOL="${ENABLE_STATIC_LIBS}" \
    -DENABLE_TESTS:BOOL=OFF

make -C "${BUILD_DIR}" -j "$(nproc)"

DOTHERSIDE_LIB=$(find "${BUILD_DIR}" -name "${DOTHERSIDE_LIB_NAME}")

mkdir -p "${LIB_DIR}"
cp "${DOTHERSIDE_LIB}" "${LIB_DIR}/${DOTHERSIDE_LIB_NAME}"