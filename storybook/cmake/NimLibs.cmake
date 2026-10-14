# Builds storybook/nim/storybook_nim.nim into a static library (StorybookNim)
# so Storybook hosts the same Nim libraries the Status app links
# (nim-qtcamera, nim-qrscan and its ZXing). Required: Storybook's pages and
# tests use them, as the app's QML does.

set(STATUS_ROOT "${CMAKE_CURRENT_LIST_DIR}/../..")
include(${CMAKE_CURRENT_LIST_DIR}/NimEnv.cmake)

find_program(NIM_EXECUTABLE nim
  HINTS "${STATUS_ROOT}/vendor/nimbus-build-system/vendor/Nim/bin" NO_DEFAULT_PATH)
find_program(NIM_EXECUTABLE nim)
if (NOT NIM_EXECUTABLE)
  message(FATAL_ERROR "No Nim compiler found: run `make update` in ${STATUS_ROOT}")
endif()

# The archive's dependency tracking relies on add_custom_command(DEPFILE),
# which the Makefile generators support from CMake 3.20 (Storybook itself
# accepts 3.19). Without it the archive would silently go stale.
if (CMAKE_VERSION VERSION_LESS 3.20)
  message(FATAL_ERROR "Storybook's Nim libraries need CMake >= 3.20 "
    "(dependency tracking via DEPFILE); found ${CMAKE_VERSION}. Upgrade CMake.")
endif()

set(_nim_dir "${CMAKE_BINARY_DIR}/nim")
if (WIN32)
  set(_nim_out "${_nim_dir}/storybook_nim.lib")
else()
  set(_nim_out "${_nim_dir}/libstorybook_nim.a")
endif()

# ZXing (readers + C API) for nim-qrscan, from its nested submodule. Nim
# checks the archive exists at compile time; the hosts link it.
# zxing-cpp 3 needs C++20 and only picks it when the standard is unset;
# Storybook sets 17. Both overrides are scoped to this subdirectory.
set(_zxing_saved_shared ${BUILD_SHARED_LIBS})
set(_zxing_saved_std ${CMAKE_CXX_STANDARD})
set(BUILD_SHARED_LIBS OFF)
set(CMAKE_CXX_STANDARD 20)
set(ZXING_READERS ON CACHE BOOL "" FORCE)
set(ZXING_WRITERS OFF CACHE STRING "" FORCE)
set(ZXING_C_API ON CACHE BOOL "" FORCE)
# Only core/ (the library, C API included): the top level also adds the C
# wrapper's demo, a CTest entry and a configure-time stb download.
add_subdirectory("${STATUS_ROOT}/vendor/nim-qrscan/vendor/zxing-cpp/core"
  "${CMAKE_BINARY_DIR}/zxing" EXCLUDE_FROM_ALL)
set(BUILD_SHARED_LIBS ${_zxing_saved_shared})
set(CMAKE_CXX_STANDARD ${_zxing_saved_std})
# Storybook enables AUTOMOC globally; ZXing has no Qt code to moc.
set_target_properties(ZXing PROPERTIES POSITION_INDEPENDENT_CODE ON
  AUTOMOC OFF AUTOUIC OFF AUTORCC OFF)

set(_nim_depfile "${_nim_dir}/libstorybook_nim.d")
set(_nim_args
  --app:staticlib --noMain --mm:orc --threads:on
  --hints:off -d:release -d:qtcameraNoPermissionPlugin --noNimblePath
  "--path:${STATUS_ROOT}/vendor/nim-seaqt"
  "--path:${STATUS_ROOT}/vendor/nimqml-seaqt/src"
  "--path:${STATUS_ROOT}/vendor/nim-result"
  "--path:${STATUS_ROOT}/vendor/nim-qtcamera"
  "--path:${STATUS_ROOT}/vendor/nim-qrscan"
  "--path:${STATUS_ROOT}/src/app/global"
  "-d:qrscanZxingLib=$<TARGET_FILE:ZXing>")

# seaqt locates Qt through pkg-config at Nim compile time: the Kit's own .pc
# files, or on Windows prl-to-pc's generated tree plus its pkg-config wrapper
# (as vendor/prl-to-pc/qt-pkgconfig.mk sets up for the app).
set(_nim_env "PKG_CONFIG_PATH=${QT6_INSTALL_PREFIX}/${QT6_INSTALL_LIBS}/pkgconfig:$ENV{PKG_CONFIG_PATH}")
if (WIN32)
  # Same toolchain as the app's Nim build (Makefile, win32): clang targeting
  # the MSVC ABI, so the archive links with Qt's msvc build.
  find_program(STORYBOOK_NIM_CLANG clang REQUIRED)
  list(APPEND _nim_args
    --cc:clang
    "--clang.exe:${STORYBOOK_NIM_CLANG}"
    "--clang.linkerexe:${STORYBOOK_NIM_CLANG}"
    "--passC:--target=x86_64-pc-windows-msvc -fms-runtime-lib=dll"
    "--passL:--target=x86_64-pc-windows-msvc -fuse-ld=lld -fms-runtime-lib=dll")

  get_filename_component(_qt_kit "${QT6_INSTALL_PREFIX}" NAME)
  get_filename_component(_qt_version_dir "${QT6_INSTALL_PREFIX}" DIRECTORY)
  get_filename_component(_qt_version "${_qt_version_dir}" NAME)
  set(_pc_tree "${STATUS_ROOT}/vendor/prl-to-pc/${_qt_version}/${_qt_kit}/lib/pkgconfig")
  set(_pc_wrapper_dir "${STATUS_ROOT}/vendor/prl-to-pc/.pcwrap")
  if (EXISTS "${_pc_tree}")
    if (NOT EXISTS "${_pc_wrapper_dir}/pkg-config.exe")
      message(FATAL_ERROR "prl-to-pc's pkg-config wrapper is missing: run `make qt-pkgconfig` in ${STATUS_ROOT}")
    endif()
    file(TO_NATIVE_PATH "${_pc_wrapper_dir}" _pc_wrapper_native)
    storybook_nim_env_var(_pc_env PKG_CONFIG_PATH "${_pc_tree}" "$ENV{PKG_CONFIG_PATH}")
    storybook_nim_env_var(_path_env PATH "${_pc_wrapper_native}" "$ENV{PATH}")
    set(_nim_env "${_pc_env}" "PKG_CONFIG_PREFIX_OVERRIDE=Qt*=${QT6_INSTALL_PREFIX}" "${_path_env}")
  else()
    storybook_nim_env_var(_nim_env PKG_CONFIG_PATH
      "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_LIBS}/pkgconfig" "$ENV{PKG_CONFIG_PATH}")
  endif()
endif()

# '|'-joined: a ;-list doesn't survive the custom command's quoting.
string(REPLACE ";" "|" _nim_args_joined "${_nim_args}")

# The wrapper writes a depfile listing every Nim module, {.compile.}'d C++
# source/header and Nim config file the build read, so updating any vendored
# dependency (nim-seaqt, nimqml-seaqt, nim-result, ...) or the app's
# config.nims / nim.cfg rebuilds the archive and relinks its hosts.
if (POLICY CMP0116)
  cmake_policy(SET CMP0116 NEW)
endif()

add_custom_command(
  OUTPUT "${_nim_out}"
  COMMAND ${CMAKE_COMMAND} -E env ${_nim_env}
    ${CMAKE_COMMAND}
    "-DNIM=${NIM_EXECUTABLE}"
    "-DNIM_ARGS=${_nim_args_joined}"
    "-DNIM_SOURCE=${CMAKE_CURRENT_LIST_DIR}/../nim/storybook_nim.nim"
    "-DNIMCACHE=${_nim_dir}/cache"
    "-DOUTPUT=${_nim_out}"
    "-DDEPFILE=${_nim_depfile}"
    -P "${CMAKE_CURRENT_LIST_DIR}/NimBuildWithDepfile.cmake"
  DEPENDS
    "${CMAKE_CURRENT_LIST_DIR}/../nim/storybook_nim.nim"
    "${CMAKE_CURRENT_LIST_DIR}/NimBuildWithDepfile.cmake"
    ZXing
  DEPFILE "${_nim_depfile}"
  COMMENT "Building Nim libraries for Storybook"
  VERBATIM)
add_custom_target(StorybookNimBuild DEPENDS "${_nim_out}")

add_library(StorybookNim STATIC IMPORTED GLOBAL)
set_target_properties(StorybookNim PROPERTIES IMPORTED_LOCATION "${_nim_out}")
add_dependencies(StorybookNim StorybookNimBuild)
target_link_libraries(StorybookNim INTERFACE
  ZXing Qt::Multimedia Qt::Qml Qt::Quick Qt::Widgets Qt::Gui Qt::Core)
target_include_directories(StorybookNim INTERFACE "${CMAKE_CURRENT_LIST_DIR}/../nim")
