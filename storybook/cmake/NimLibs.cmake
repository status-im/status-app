# Builds storybook/nim/storybook_nim.nim into a static library (StorybookNim)
# so Storybook hosts the same Nim libraries the Status app links.
# Option STORYBOOK_NIM_LIBS (default ON when Nim and vendor/nim-qtcamera exist).

set(STATUS_ROOT "${CMAKE_CURRENT_LIST_DIR}/../..")

find_program(NIM_EXECUTABLE nim
  HINTS "${STATUS_ROOT}/vendor/nimbus-build-system/vendor/Nim/bin" NO_DEFAULT_PATH)
find_program(NIM_EXECUTABLE nim)

# The archive's dependency tracking relies on add_custom_command(DEPFILE),
# which the Makefile generators support from CMake 3.20 (Storybook itself
# accepts 3.19). Without it the archive would silently go stale.
set(_storybook_nim_min_cmake 3.20)

set(_storybook_nim_default OFF)
# Not on Windows yet: the custom command below lacks the app build's
# clang/MSVC-target Nim flags and prl-to-pc's generated-mode pkg-config setup.
if (NOT WIN32 AND NIM_EXECUTABLE
    AND CMAKE_VERSION VERSION_GREATER_EQUAL _storybook_nim_min_cmake
    AND EXISTS "${STATUS_ROOT}/vendor/nim-qtcamera/qtcamera.nim")
  set(_storybook_nim_default ON)
endif()
option(STORYBOOK_NIM_LIBS "Link Nim libraries (nim-qtcamera) into Storybook" ${_storybook_nim_default})

if (STORYBOOK_NIM_LIBS)
  if (NOT NIM_EXECUTABLE)
    message(FATAL_ERROR "STORYBOOK_NIM_LIBS is ON but no Nim compiler was found (run `make update`)")
  endif()
  if (CMAKE_VERSION VERSION_LESS _storybook_nim_min_cmake)
    message(FATAL_ERROR "STORYBOOK_NIM_LIBS needs CMake >= ${_storybook_nim_min_cmake} "
      "(dependency tracking via DEPFILE); found ${CMAKE_VERSION}. "
      "Upgrade CMake or configure with -DSTORYBOOK_NIM_LIBS=OFF.")
  endif()

  set(_nim_dir "${CMAKE_BINARY_DIR}/nim")
  set(_nim_out "${_nim_dir}/libstorybook_nim.a")
  # seaqt locates Qt through pkg-config at Nim compile time.
  set(_nim_pkgconfig "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_LIBS}/pkgconfig")

  set(_nim_depfile "${_nim_dir}/libstorybook_nim.d")
  set(_nim_args
    --app:staticlib --noMain --mm:orc --threads:on
    --hints:off -d:release -d:qtcameraNoPermissionPlugin --noNimblePath
    "--path:${STATUS_ROOT}/vendor/nim-seaqt"
    "--path:${STATUS_ROOT}/vendor/nimqml-seaqt/src"
    "--path:${STATUS_ROOT}/vendor/nim-result"
    "--path:${STATUS_ROOT}/vendor/nim-qtcamera")
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
    COMMAND ${CMAKE_COMMAND} -E env "PKG_CONFIG_PATH=${_nim_pkgconfig}:$ENV{PKG_CONFIG_PATH}"
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
    DEPFILE "${_nim_depfile}"
    COMMENT "Building Nim libraries for Storybook"
    VERBATIM)
  add_custom_target(StorybookNimBuild DEPENDS "${_nim_out}")

  add_library(StorybookNim STATIC IMPORTED GLOBAL)
  set_target_properties(StorybookNim PROPERTIES IMPORTED_LOCATION "${_nim_out}")
  add_dependencies(StorybookNim StorybookNimBuild)
  target_link_libraries(StorybookNim INTERFACE
    Qt::Multimedia Qt::Qml Qt::Quick Qt::Widgets Qt::Gui Qt::Core)
  target_include_directories(StorybookNim INTERFACE "${CMAKE_CURRENT_LIST_DIR}/../nim")
  target_compile_definitions(StorybookNim INTERFACE STORYBOOK_HAS_NIM)
endif()
