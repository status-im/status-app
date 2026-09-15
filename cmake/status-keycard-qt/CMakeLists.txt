# App-owned FetchContent orchestration for the status-keycard-qt vendor
# (issue 0011). This project owns the app's status-keycard-qt PIN; the nested
# keycard-qt pin stays owned by status-keycard-qt's own CMakeLists (it
# FetchContents keycard-qt itself — no parent cascade needed).
#
# Both the desktop Makefile ("status-keycard-qt" target) and
# mobile/scripts/buildStatusKeycardQt.sh configure THIS directory; every
# -D option (BUILD_SHARED_LIBS, BUILD_TESTING, OPENSSL_*, …) passes through
# unchanged because FetchContent adds the project in the same cache scope.
#
# Develop mode (status.nims, issues 0009/0011) redirects either content to a
# local checkout via the cache vars cmake derives from the content name
# (TOUPPER, hyphens preserved):
#   FETCHCONTENT_SOURCE_DIR_STATUS-KEYCARD-QT=<abs path to checkout>
#   FETCHCONTENT_SOURCE_DIR_KEYCARD-QT=<abs path to checkout>
# An EMPTY value behaves as unset (pinned fetch); the build recipes always
# pass both explicitly so no stale cache value can survive a mode flip.
cmake_minimum_required(VERSION 3.16)
project(status-keycard-qt-vendor LANGUAGES NONE)

include(FetchContent)

# Keep the built library at the build-dir root, where it landed when the
# vendor was the top-level project: the Makefiles' STATUSKEYCARD_QT_LIBDIR
# contract, the run targets' loader paths and the packaging copies all read
# it there (as a subproject it would otherwise land in
# _deps/status-keycard-qt-build/). Multi-config generators (MSVC) append
# $<CONFIG>, matching the Makefile's win32 STATUSKEYCARD_QT_LIB_SUBDIR.
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

FetchContent_Declare(
  status-keycard-qt
  GIT_REPOSITORY https://github.com/status-im/status-keycard-qt
  GIT_TAG 8582bffc915b9cfb4dc96be5c1b914b8d1ebbc18
)
FetchContent_MakeAvailable(status-keycard-qt)
