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
  GIT_TAG 031d8d15e78fbf578888d06958860ba1c07a9736
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

qt_import_qml_plugins(${PROJECT_NAME})
qt_finalize_executable(${PROJECT_NAME})
