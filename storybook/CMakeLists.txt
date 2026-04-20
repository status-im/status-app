cmake_minimum_required(VERSION 3.19)
project(Storybook)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

if (WIN32)
    # Override the default output directories for different configurations
    foreach(OUTPUTCONFIG ${CMAKE_CONFIGURATION_TYPES})
        string(TOUPPER ${OUTPUTCONFIG} OUTPUTCONFIG)
        set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${CMAKE_ARCHIVE_OUTPUT_DIRECTORY})
        set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
        set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
    endforeach()
endif()

if(MSVC)
  add_definitions(/MP)
endif()

if (APPLE)
    set(MACOS_VERSION_MIN_FLAGS -mmacosx-version-min=14.0)
endif()

find_package(QT NAMES Qt5 Qt6 REQUIRED COMPONENTS Core)

find_package(Qt${QT_VERSION_MAJOR} COMPONENTS Core Gui Quick QuickControls2 Test
    QuickTest Qml WebView REQUIRED)

set(STATUSQ_BUILD_SANITY_CHECKER OFF)
set(STATUSQ_BUILD_TESTS OFF)
set(STATUSQ_STATIC_LIB ON)
set(STATUSQ_SHADOW_BUILD OFF)

add_subdirectory(../ui/StatusQ StatusQ)

include(FetchContent)
FetchContent_Declare(
  QmlStorybook

  GIT_REPOSITORY https://github.com/status-im/QmlStorybook.git
  GIT_TAG fc13fc5fdba86da17e71e5985178d2a8fdb5cb3e
)
FetchContent_MakeAvailable(QmlStorybook)

file(GLOB_RECURSE CORE_QML_FILES
    "../ui/app/*.qml" "../ui/imports/*.qml"
    "../ui/app/*/qmldir" "../ui/imports/*/qmldir"
)

file(GLOB_RECURSE CORE_JS_FILES "../ui/app/*.js")

file(GLOB_RECURSE STORYBOOK_QML_FILES "stubs/*.qml" "mocks/*.qml" "pages/*.qml"
    "src/*.qml" "src/qmldir")

file(GLOB_RECURSE TEST_QML_FILES "qmlTests/*.qml")

qt_add_executable(
  ${PROJECT_NAME} MANUAL_FINALIZATION
  main.cpp
  main.qml
  ${CORE_QML_FILES}
  ${CORE_JS_FILES}
  ${STORYBOOK_QML_FILES}
  README.md
   # Require for loading WalletConnect SDK;
   # TODO #14696: remove this dependency
   resources.qrc
   storybook-resources.qrc
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
        QML_IMPORT_ROOT="${CMAKE_CURRENT_LIST_DIR}"
        STATUSQ_MODULE_IMPORT_PATH="${STATUSQ_MODULE_IMPORT_PATH}"
        $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>
    )

target_link_libraries(
    ${PROJECT_NAME} PRIVATE Qt::Core Qt::Gui Qt::Quick Qt::QuickControls2
    Qt::WebView StatusQ QmlStorybookLib)

add_executable(
  QmlFilesServer
  qmlfilesserver_main.cpp
)

target_compile_definitions(QmlFilesServer PRIVATE
        QML_IMPORT_ROOT="${CMAKE_CURRENT_LIST_DIR}"
        STATUSQ_MODULE_IMPORT_PATH="${STATUSQ_MODULE_IMPORT_PATH}"
    )

target_link_libraries(
    QmlFilesServer PUBLIC Qt::Core QmlStorybookLib)

enable_testing()

add_executable(
  PagesValidator
  validator_main.cpp
)

target_link_libraries(
    PagesValidator PUBLIC Qt::Core Qt::Gui Qt::Quick Qt::QuickControls2 Qt::WebView StatusQ QmlStorybookLib)

target_compile_definitions(PagesValidator PRIVATE
        QML_IMPORT_ROOT="${CMAKE_CURRENT_LIST_DIR}"
        STATUSQ_MODULE_IMPORT_PATH="${STATUSQ_MODULE_IMPORT_PATH}"
    )

add_test(NAME PagesValidator COMMAND PagesValidator)

add_executable(QmlTests
    qmlTests/main.cpp
    ${TEST_QML_FILES})

target_compile_definitions(QmlTests PRIVATE
        QML_IMPORT_ROOT="${CMAKE_CURRENT_LIST_DIR}"
        STATUSQ_MODULE_IMPORT_PATH="${STATUSQ_MODULE_IMPORT_PATH}"
        QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qmlTests")
target_link_libraries(QmlTests PRIVATE
  Qt::QuickTest Qt::Qml Qt::Core Qt::Gui Qt::Quick Qt::QuickControls2
  StatusQ SortFilterProxyModel QmlStorybookLib)
add_test(NAME QmlTests COMMAND QmlTests -platform offscreen)

# ----------------------------------------------------------------------------
# Optional: Nim model A/B benchmark (BENCH_MODELS=ON)
# ----------------------------------------------------------------------------
# Builds storybook/qmlTests/nimbench/bench_lib.nim as a static library and
# links it (along with libDOtherSideStatic.a) into the QmlTests executable.
# The bench QObject is exposed as the `benchHarness` QML context property
# from qmlTests/main.cpp (gated on BENCH_MODELS).
#
# Default builds are unaffected; opt in with `-DBENCH_MODELS=ON`.
option(BENCH_MODELS "Build the Nim grouped_account_assets_model benchmark" OFF)

if(BENCH_MODELS)
    set(NIMBENCH_DIR ${CMAKE_CURRENT_SOURCE_DIR}/qmlTests/nimbench)
    set(BENCH_LIB_OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/libbench_models.a)
    set(STATUS_DESKTOP_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/..)

    file(GLOB_RECURSE BENCH_NIM_SOURCES
        "${NIMBENCH_DIR}/*.nim")

    # Compile the Nim static lib via env.sh (sets up the vendored Nim
    # toolchain + nimqml from nimbus-build-system).
    #
    # CRITICAL: --noConfig prevents nim from walking up to the BASE repo's
    # nim.cfg (the worktree lives inside the base repo, so the parent-walk
    # picks up `path = "src"` pointing at master's src/ and resolves
    # imports to the OLD ref-object files instead of the worktree's NEW
    # value-type files).  We pass everything the bench needs explicitly.
    add_custom_command(
        OUTPUT ${BENCH_LIB_OUTPUT}
        COMMAND ${STATUS_DESKTOP_ROOT}/env.sh nim c
                  --skipParentCfg:on
                  --skipProjCfg:on
                  --app:staticlib --noMain
                  --mm:refc
                  -d:release --opt:speed
                  --threads:on
                  --tlsEmulation:off
                  --debugger:native
                  --cc:clang
                  --passC:-mmacosx-version-min=14.0
                  # Don't emit dlopen()s - the C++ host links DOtherSideStatic
                  # so the symbols are already in the executable.
                  --dynlibOverrideAll
                  --path:${STATUS_DESKTOP_ROOT}/src
                  --path:${STATUS_DESKTOP_ROOT}/vendor/nimqml/src
                  --path:${STATUS_DESKTOP_ROOT}/vendor/nim-stint
                  --path:${STATUS_DESKTOP_ROOT}/vendor/nim-stew
                  --path:${STATUS_DESKTOP_ROOT}/vendor/nimcrypto
                  --path:${STATUS_DESKTOP_ROOT}/vendor/nim-serialization
                  --path:${STATUS_DESKTOP_ROOT}/vendor/nim-faststreams
                  --path:${STATUS_DESKTOP_ROOT}/vendor/nim-results
                  --path:${STATUS_DESKTOP_ROOT}/vendor/nim-unittest2
                  --nimcache:${CMAKE_CURRENT_BINARY_DIR}/nimbench_cache
                  -o:${BENCH_LIB_OUTPUT}
                  ${NIMBENCH_DIR}/bench_lib.nim
        DEPENDS ${BENCH_NIM_SOURCES}
        WORKING_DIRECTORY ${STATUS_DESKTOP_ROOT}
        COMMENT "Building bench_models.a (Nim static lib)"
        VERBATIM
    )
    add_custom_target(bench_models_lib DEPENDS ${BENCH_LIB_OUTPUT})

    add_library(bench_models STATIC IMPORTED GLOBAL)
    set_target_properties(bench_models PROPERTIES
        IMPORTED_LOCATION ${BENCH_LIB_OUTPUT})
    add_dependencies(bench_models bench_models_lib)

    # DOtherSide static (built separately via `make storybook-bench`).
    set(DOTHERSIDE_STATIC_LIB
        ${STATUS_DESKTOP_ROOT}/vendor/DOtherSide/build/Qt${QT_VERSION_MAJOR}.${Qt${QT_VERSION_MAJOR}_VERSION_MINOR}.${Qt${QT_VERSION_MAJOR}_VERSION_PATCH}/lib/libDOtherSideStatic.a)
    if(NOT EXISTS ${DOTHERSIDE_STATIC_LIB})
        # Fallback: glob for any libDOtherSideStatic.a under vendor/DOtherSide/build
        file(GLOB_RECURSE _doth_candidates
             ${STATUS_DESKTOP_ROOT}/vendor/DOtherSide/build/*/lib/libDOtherSideStatic.a)
        list(LENGTH _doth_candidates _doth_count)
        if(_doth_count GREATER 0)
            list(GET _doth_candidates 0 DOTHERSIDE_STATIC_LIB)
        endif()
    endif()
    message(STATUS "BENCH_MODELS: linking DOtherSideStatic from ${DOTHERSIDE_STATIC_LIB}")

    add_library(DOtherSideStatic STATIC IMPORTED GLOBAL)
    set_target_properties(DOtherSideStatic PROPERTIES
        IMPORTED_LOCATION ${DOTHERSIDE_STATIC_LIB})

    # DOtherSideStatic was built with Qt::WebView support, so QmlTests must
    # link it too even though no test uses it directly.
    target_link_libraries(QmlTests PRIVATE
        bench_models DOtherSideStatic Qt::WebView)
    target_compile_definitions(QmlTests PRIVATE BENCH_MODELS=1)
endif()

set(OVERRIDE_STORE_PATHS_WITH_STUBS_IN_QTCREATOR OFF CACHE BOOL
  "Resolve store components as stubs instead of actual ones in QtCreator")

list(APPEND QML_DIRS "${CMAKE_SOURCE_DIR}/../ui/app")
list(APPEND QML_DIRS "${CMAKE_SOURCE_DIR}/../ui/imports")
list(APPEND QML_DIRS "${CMAKE_SOURCE_DIR}/../ui/StatusQ")
list(APPEND QML_DIRS "${CMAKE_SOURCE_DIR}/../ui/StatusQ/src")
list(APPEND QML_DIRS "${CMAKE_SOURCE_DIR}/../ui/StatusQ/tests/qml")
list(APPEND QML_DIRS "${CMAKE_SOURCE_DIR}/src")
list(APPEND QML_DIRS "${CMAKE_SOURCE_DIR}/pages")
list(APPEND QML_DIRS "${CMAKE_SOURCE_DIR}/mocks")
list(APPEND QML_DIRS "${QML_STORYBOOK_QML_IMPORT_PATH}")

if (OVERRIDE_STORE_PATHS_WITH_STUBS_IN_QTCREATOR)
  list(APPEND QML_DIRS "${CMAKE_SOURCE_DIR}/stubs")
endif()

set(QML_IMPORT_PATH "${QML_DIRS}" CACHE STRING "Qt Creator extra QML import paths" FORCE)

if (APPLE)
  find_library(AppKit AppKit)
  find_library(Foundation Foundation)
  target_link_libraries(${PROJECT_NAME} PRIVATE ${AppKit} ${Foundation})
endif()

set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
)

qt_import_qml_plugins(${PROJECT_NAME})
qt_finalize_executable(${PROJECT_NAME})
