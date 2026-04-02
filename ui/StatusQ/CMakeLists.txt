cmake_minimum_required(VERSION 3.19)

project(StatusQ)

option(STATUSQ_BUILD_SANITY_CHECKER "Enable to build StatusQ Sanity Checker application" ON)
option(STATUSQ_BUILD_TESTS "Enable to build StatusQ UI auto tests" ON)
option(STATUSQ_STATIC_LIB "Enable to build StatusQ as a static library" OFF)

# Allow files to be excluded
set(STATUSQ_SANITY_CHECKER_EXCLUDE_FILES "" CACHE STRING "Semicolon-separated list of files to exclude from sanity checker")


set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Although SHARED libraries set this to ON by default,
# all static libraries, that are built into this SHARED,
# should also be build with -fPIC.
# This fixes it.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

if(MSVC)
  add_definitions(/MP)
endif()

find_package(QT NAMES Qt6 REQUIRED COMPONENTS Core)

find_package(Qt${QT_VERSION_MAJOR} COMPONENTS
        Core CorePrivate Qml Gui Quick QuickControls2 WebChannel Svg QmlPrivate QuickPrivate REQUIRED)

# --- QML test hooks flag and TestConfig generation ---
option(STATUSQ_TESTMODE "Enable QML test hooks (TestConfig.testMode)" OFF)
set(TEST_MODE false)
if(STATUSQ_TESTMODE)
    set(TEST_MODE true)
endif()

# Generate TestConfig.qml into the build tree
set(_gen_qml ${CMAKE_CURRENT_BINARY_DIR}/src/StatusQ/Core/TestConfig.qml)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/src/StatusQ/Core)
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/src/StatusQ/Core/TestConfig.qml.in
  ${_gen_qml}
  @ONLY
)
if(NOT EXISTS ${_gen_qml})
  message(FATAL_ERROR "Expected generated file missing: ${_gen_qml}")
endif()

# When loading QML from source (not bundled), also copy to source directory
if(NOT ${STATUSQ_BUNDLE_RESOURCES})
  configure_file(${_gen_qml} ${CMAKE_CURRENT_SOURCE_DIR}/src/StatusQ/Core/TestConfig.qml COPYONLY)
endif()

# Generate a .qrc that includes the generated QML
set(_gen_qrc ${CMAKE_CURRENT_BINARY_DIR}/TestConfig.generated.qrc)
file(WRITE ${_gen_qrc}
  "<RCC>\n"
  "  <qresource prefix=\"/StatusQ\">\n"
  "    <file alias=\"Core/TestConfig.qml\">${_gen_qml}</file>\n"
  "  </qresource>\n"
  "</RCC>\n"
)

qt_add_resources(STATUSQ_TESTCONFIG_RCC ${_gen_qrc})
# --- END test hooks ---

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    find_package(Qt${QT_VERSION_MAJOR} COMPONENTS QuickTest REQUIRED)
endif()

add_subdirectory(../../vendor/SortFilterProxyModel SortFilterProxyModel)

target_compile_options(SortFilterProxyModel PRIVATE -w)

### StatusQ library
### TODO: Move to a subdirectory for readability and better structure

if (NOT DEFINED STATUSQ_BUNDLE_RESOURCES)

    #   About the STATUSQ_BUNDLE_RESOURCES option.
    #
    #   When ON:
    #     - QML/JS files are embedded as Qt resources in the library
    #     - Required for mobile builds (no filesystem access to sources)
    #   When OFF:
    #     - QML/JS files are loaded from the source directory at runtime
    #     - Used for desktop storybook hot reloading (edit & refresh)
    #
    #   Defaults to ON when building as a static lib (app/mobile) or in
    #   Release mode. OFF only for desktop Debug shared-lib builds (storybook).
    #
    #   The app must add ${STATUSQ_MODULE_IMPORT_PATH} to
    #   QQmlApplicationEngine::addImportPath.
    #

    if (STATUSQ_STATIC_LIB OR NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(STATUSQ_BUNDLE_RESOURCES ON)
    else()
        set(STATUSQ_BUNDLE_RESOURCES OFF)
    endif()
endif()

set(STATUSQ_SOURCE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/src/StatusQ")

if (${STATUSQ_BUNDLE_RESOURCES})
    set(STATUSQ_MODULE_IMPORT_PATH ":/")
else()
    set(STATUSQ_MODULE_IMPORT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/src")
endif()

if (NOT PROJECT_IS_TOP_LEVEL)
    set(STATUSQ_MODULE_IMPORT_PATH "${STATUSQ_MODULE_IMPORT_PATH}" PARENT_SCOPE)
    set(STATUSQ_BUNDLE_RESOURCES "${STATUSQ_BUNDLE_RESOURCES}" PARENT_SCOPE)
endif ()

if (${STATUSQ_STATIC_LIB})
    set(LIB_TYPE STATIC)
else()
    set(LIB_TYPE SHARED)
endif ()

if (${STATUSQ_BUNDLE_RESOURCES})
    add_definitions(-DBUNDLE_QML_RESOURCES)

    # Asset-only resources (fonts, images, twemoji) — no QML compilation needed
    set(STATUSQ_ASSET_QRC_FILES
        src/assets/fonts/fonts.qrc
        src/assets/img/img.qrc
        src/assets/png/png.qrc
        src/assets/twemoji/twemoji.qrc
        src/assets/twemoji/twemoji-svg.qrc)

    # Platform-specific PNG bundles
    if(ANDROID OR IOS)
        list(APPEND STATUSQ_ASSET_QRC_FILES
            src/assets/png/png-mobile.qrc
        )
    else()
        list(APPEND STATUSQ_ASSET_QRC_FILES
            src/assets/png/png-desktop.qrc
        )
    endif()

    if (${STATUSQ_STATIC_LIB})
        qt_add_resources(STATUSQ_ASSET_RCC ${STATUSQ_ASSET_QRC_FILES})
    else()
        qt_add_big_resources(STATUSQ_ASSET_RCC ${STATUSQ_ASSET_QRC_FILES})
    endif()
endif()

add_library(StatusQ ${LIB_TYPE}
        ${STATUSQ_ASSET_RCC}
        ${STATUSQ_TESTCONFIG_RCC}
        include/StatusQ/audioutils.h
        include/StatusQ/clipboardutils.h
        include/StatusQ/constantrole.h
        include/StatusQ/fastexpressionfilter.h
        include/StatusQ/fastexpressionrole.h
        include/StatusQ/fastexpressionsorter.h
        include/StatusQ/formatteddoubleproperty.h
        include/StatusQ/genericvalidator.h
        include/StatusQ/keychain.h
        include/StatusQ/NativeSwipeHandlerItem.h
        include/StatusQ/NativeIndicatorItem.h
        include/StatusQ/localnetworkpermission.h
        include/StatusQ/networkchecker.h
        include/StatusQ/oneoffilter.h
        include/StatusQ/permissionutilsinternal.h
        include/StatusQ/rxvalidator.h
        include/StatusQ/shareutils.h
        include/StatusQ/stablearraysorter.h
        include/StatusQ/statuscolors.h
        include/StatusQ/statusemojimodel.h
        include/StatusQ/statussyntaxhighlighter.h
        include/StatusQ/stringutilsinternal.h
        include/StatusQ/systemutilsinternal.h
        include/StatusQ/theme.h
        include/StatusQ/themepalette.h
        include/StatusQ/typesregistration.h
        include/StatusQ/undefinedfilter.h
        include/StatusQ/urlutils.h
        include/StatusQ/statuslayoutstate.h
        src/audioutils.cpp
        src/clipboardutils.cpp
        src/constantrole.cpp
        src/externc.cpp
        src/fastexpressionfilter.cpp
        src/fastexpressionrole.cpp
        src/fastexpressionsorter.cpp
        src/formatteddoubleproperty.cpp
        src/genericvalidator.cpp
        src/keychain.cpp
        src/localnetworkpermission.cpp
        src/localnetworkpermission_backend.h
        src/networkchecker.cpp
        src/oneoffilter.cpp
        src/permissionutilsinternal.cpp
        src/rxvalidator.cpp
        src/stablearraysorter.cpp
        src/statuscolors.cpp
        src/statusemojimodel.cpp
        src/statussyntaxhighlighter.cpp
        src/stringutilsinternal.cpp
        src/systemutilsinternal.cpp
        src/theme.cpp
        src/themepalette.cpp
        src/typesregistration.cpp
        src/undefinedfilter.cpp
        src/urlutils.cpp
        src/statuslayoutstate.cpp
        src/ios_utils.h

        src/StatusQ/Controls/NativeSwipeHandlerItem.cpp
        src/StatusQ/Controls/NativeIndicatorItem.cpp

        # wallet
        src/wallet/managetokenscontroller.cpp
        src/wallet/managetokenscontroller.h
        src/wallet/managetokensmodel.cpp
        src/wallet/managetokensmodel.h
        src/wallet/tokendata.cpp
        src/wallet/tokendata.h

        # onboarding
        src/onboarding/enums.h

        # l10n
        src/l10n/languagemodel.h
        src/l10n/languagemodel.cpp
        src/l10n/languageservice.h
        src/l10n/languageservice.cpp
        )

target_compile_features(StatusQ PRIVATE cxx_std_17)

# --- QML ahead-of-time compilation via qt_add_qml_module ---
# This enables qmlcachegen to pre-compile QML files to bytecode,
# eliminating runtime QML parsing overhead on Android.
if (${STATUSQ_BUNDLE_RESOURCES})
    # Collect all QML files from the StatusQ source tree
    file(GLOB_RECURSE STATUSQ_QML_FILES
        RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
        "src/StatusQ/*.qml"
    )

    # Collect JS files for compilation
    file(GLOB_RECURSE STATUSQ_JS_FILES
        RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
        "src/StatusQ/*.js"
        "src/StatusQ/*.mjs"
    )

    # Collect qmldir files as resources (not compiled, just bundled)
    file(GLOB_RECURSE STATUSQ_QMLDIR_FILES
        RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
        "src/StatusQ/*/qmldir"
    )

    # Other non-compiled resources (LICENSE, README, etc.)
    set(STATUSQ_OTHER_RESOURCES
        src/StatusQ/Core/Backpressure/LICENSE
        src/StatusQ/Core/Backpressure/README.md
    )

    # Set resource aliases: strip "src/StatusQ/" prefix so files end up at :/StatusQ/...
    # qt_add_qml_module places files under RESOURCE_PREFIX/URI_PATH/, so with
    # URI "StatusQ" and prefix "/", files go to :/StatusQ/<alias>.
    # We need alias "Components/Foo.qml" (not "src/StatusQ/Components/Foo.qml").
    foreach(_file IN LISTS STATUSQ_QML_FILES STATUSQ_JS_FILES STATUSQ_QMLDIR_FILES STATUSQ_OTHER_RESOURCES)
        string(REGEX REPLACE "^src/StatusQ/" "" _alias "${_file}")
        set_source_files_properties("${_file}" PROPERTIES QT_RESOURCE_ALIAS "${_alias}")
    endforeach()

    # Suppress QTP0004 warning — we have hand-written qmldir files for sub-modules
    qt_policy(SET QTP0004 OLD)

    # Static builds: generate a plugin target for QTPLUGIN / Q_IMPORT_PLUGIN.
    # Shared builds (Android): skip plugin — the QML engine loads the backing
    # library directly and finds resources via qmldir + qrc:/ prefix.
    if(STATUSQ_STATIC_LIB)
        set(_statusq_plugin_arg PLUGIN_TARGET statusqplugin)
    else()
        set(_statusq_plugin_arg NO_PLUGIN)
    endif()

    # --- Discover external QML dependencies via qmlimportscanner ---
    # Same pattern as AppResources: scan StatusQ's QML files for imports,
    # then pass them as DEPENDENCIES so the generated qmldir has `depends`
    # entries. This lets qmake's static-build scanner follow the chain
    # and link the correct Qt QML plugins (qtquick2plugin, etc.).
    get_filename_component(_qt_prefix "${Qt6_DIR}/../../.." ABSOLUTE)
    find_program(_STATUSQ_QMLIMPORTSCANNER qmlimportscanner
        HINTS "${_qt_prefix}/libexec" "${_qt_prefix}/bin")

    set(_statusq_qml_deps "")
    if(_STATUSQ_QMLIMPORTSCANNER)
        execute_process(
            COMMAND sh -c "\"${_STATUSQ_QMLIMPORTSCANNER}\" \
                -rootPath \"${CMAKE_CURRENT_SOURCE_DIR}/src\" \
                -importPath \"${_qt_prefix}/qml\" \
                -importPath \"${CMAKE_CURRENT_SOURCE_DIR}/src\" \
                2>/dev/null | grep '\"name\"' | \
                sed 's/.*\"name\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/' | \
                grep -v '^$' | sort -u"
            OUTPUT_VARIABLE _statusq_all_deps
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        if(_statusq_all_deps)
            string(REPLACE "\n" ";" _statusq_all_deps "${_statusq_all_deps}")
            set(_statusq_excluded_deps "QtWebEngine" "QtWebEngine.Controls")
            foreach(_dep IN LISTS _statusq_all_deps)
                if("${_dep}" MATCHES "^Qt" AND NOT "${_dep}" IN_LIST _statusq_excluded_deps)
                    list(APPEND _statusq_qml_deps "${_dep}")
                endif()
            endforeach()
            list(LENGTH _statusq_qml_deps _dep_count)
            message(STATUS "StatusQ: ${_dep_count} QML dependencies discovered")
        endif()
    endif()

    qt_add_qml_module(StatusQ
        URI "StatusQ"
        VERSION 0.1
        RESOURCE_PREFIX "/"
        ${_statusq_plugin_arg}
        DEPENDENCIES ${_statusq_qml_deps}
        QML_FILES ${STATUSQ_QML_FILES} ${STATUSQ_JS_FILES}
        RESOURCES ${STATUSQ_QMLDIR_FILES} ${STATUSQ_OTHER_RESOURCES}
        OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/StatusQ"
        NO_GENERATE_EXTRA_QMLDIRS
    )

endif()
# --- END QML ahead-of-time compilation ---

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    find_library(AppKit AppKit)
    find_library(Foundation Foundation)
    find_library(Security Security)
    find_library(LocalAuthentication LocalAuthentication)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${AppKit} ${Foundation} ${Security} ${LocalAuthentication})
    find_library(WebKit WebKit)
    find_library(QuartzCore QuartzCore)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${AppKit} ${Foundation} ${Security} ${LocalAuthentication} ${WebKit} ${QuartzCore})
    qt_import_plugins(${PROJECT_NAME} INCLUDE Qt6::QDarwinCameraPermissionPlugin)
    target_sources(StatusQ PRIVATE
        src/shareutils_other.cpp
        src/keychain_apple.mm
        src/StatusQ/Controls/NativeSwipeHandlerItem_macos.mm
        src/StatusQ/Controls/NativeIndicatorItem_macos.mm
    )
elseif (${CMAKE_SYSTEM_NAME} MATCHES "iOS")
    find_library(UIKit UIKit)
    find_library(Foundation Foundation)
    find_library(Security Security)
    find_library(LocalAuthentication LocalAuthentication)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${UIKit} ${Foundation} ${Security} ${LocalAuthentication})
    find_library(WebKit WebKit)
    find_library(UserNotifications UserNotifications)
    find_library(CoreMotion CoreMotion)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${UIKit} ${Foundation} ${Security} ${LocalAuthentication} ${WebKit} ${UserNotifications} ${CoreMotion})
    target_sources(StatusQ PRIVATE
        src/ios_utils.mm
        src/shareutils_ios.mm
        src/keychain_apple.mm
        src/StatusQ/Controls/NativeSwipeHandlerItem_ios.mm
        src/StatusQ/Controls/NativeIndicatorItem_ios.mm
        src/localnetworkpermission_ios.mm
    )
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Android")
    target_sources(StatusQ PRIVATE
        src/keychain_android.cpp
        src/safutils_android.cpp
        src/StatusQ/Controls/NativeSwipeHandlerItem_android.cpp
        src/StatusQ/Controls/NativeIndicatorItem_android.cpp
        src/shareutils_android.cpp
    )
else ()
    target_sources(StatusQ PRIVATE
        src/shareutils_other.cpp
        src/keychain_other.cpp
    )
endif ()

include(FetchContent)
set(FETCHCONTENT_TRY_FIND_PACKAGE_MODE NEVER)

if(IOS OR ANDROID OR CMAKE_SYSTEM_NAME MATCHES "Darwin")
    FetchContent_Declare(
      MobileWebView

      GIT_REPOSITORY https://github.com/status-im/mobilewebview.git
      GIT_TAG 4fd4683ea2dcf31d0bb3dcaff82c75dac8c1f559
      SOURCE_SUBDIR mobilewebview
    )
    FetchContent_MakeAvailable(MobileWebView)

    if(TARGET MobileWebView)
        target_link_libraries(StatusQ PRIVATE MobileWebView)
        target_compile_definitions(StatusQ PRIVATE STATUSQ_HAS_MOBILEWEBVIEW=1)
        if(ANDROID AND DEFINED mobilewebview_SOURCE_DIR)
            file(WRITE "${CMAKE_BINARY_DIR}/mobilewebview_java_dir.txt"
                "${mobilewebview_SOURCE_DIR}/mobilewebview/android/src")
        endif()
        install(TARGETS MobileWebView
                RUNTIME DESTINATION lib
                LIBRARY DESTINATION lib
                ARCHIVE DESTINATION lib
                )
    endif()
endif()

FetchContent_Declare(
  QtModelsToolkit

  GIT_REPOSITORY https://github.com/status-im/QtModelsToolkit.git
  GIT_TAG b249dc22be1e1e728acce90065f943d7db3636e5
)

FetchContent_MakeAvailable(QtModelsToolkit)

# QtModelsToolkit has integer narrowing warnings on arm64 iOS.
# Suppress -Werror for the third-party dependency.
if(TARGET QtModelsToolkit)
    target_compile_options(QtModelsToolkit PRIVATE -Wno-shorten-64-to-32)
endif()

FetchContent_Declare(
  MobileUI

  GIT_REPOSITORY https://github.com/status-im/MobileUI.git
  GIT_TAG 12802e2a1931917f84011bafecb2a86880ff110c
)
FetchContent_MakeAvailable(MobileUI)

# Build SCodes and ZXing as static deps so StatusQ can be shipped standalone.
# SCodes defaults BUILD_SHARED_LIBS to ON when it is undefined.
set(_statusq_build_shared_libs_was_defined FALSE)
if(DEFINED BUILD_SHARED_LIBS)
    set(_statusq_build_shared_libs_was_defined TRUE)
    set(_statusq_build_shared_libs_backup "${BUILD_SHARED_LIBS}")
endif()
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build SCodes/ZXing as static dependencies" FORCE)

FetchContent_Declare(
  SCodes

  GIT_REPOSITORY https://github.com/status-im/SCodes.git
  GIT_TAG 8d2baf1250393544b1949ff04b7414465b6d73cf
    SOURCE_SUBDIR src
)

FetchContent_MakeAvailable(SCodes)

if(_statusq_build_shared_libs_was_defined)
    set(BUILD_SHARED_LIBS "${_statusq_build_shared_libs_backup}" CACHE BOOL "Restore original shared/static policy" FORCE)
else()
    unset(BUILD_SHARED_LIBS CACHE)
endif()

target_link_libraries(StatusQ PRIVATE
        Qt::Core
        Qt::Qml
        Qt::Gui
        Qt::Quick
        Qt::QuickControls2
        Qt::WebChannel
        Qt::Svg
        Qt::QmlPrivate
        Qt::QuickPrivate
        SortFilterProxyModel
        QtModelsToolkit
        MobileUI
        SCodes
        )


if(TARGET SCodes)
    set_target_properties(SCodes PROPERTIES
        POSITION_INDEPENDENT_CODE ON
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON
    )
endif()

if(TARGET ZXing)
    set_target_properties(ZXing PROPERTIES
        POSITION_INDEPENDENT_CODE ON
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON
        # ZXing's PCH includes C++ headers but is compiled as C on iOS — disable.
        DISABLE_PRECOMPILE_HEADERS ON
    )
endif()

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_link_libraries(StatusQ PRIVATE
            Qt::QuickTest
            )
endif()

target_include_directories(StatusQ PUBLIC include)

install(TARGETS StatusQ
        RUNTIME DESTINATION lib
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        )

# Install the QML plugin + metadata (generated by qt_add_qml_module).
# Follow Qt's standard layout: plugin lib and qmldir go into
# qml/<ModuleName>/ so androiddeployqt/qmlimportscanner can discover them.
if(TARGET statusqplugin)
    install(TARGETS statusqplugin
            ARCHIVE DESTINATION qml/StatusQ
            LIBRARY DESTINATION qml/StatusQ
            RUNTIME DESTINATION qml/StatusQ
            )

    # qmldir (auto-generated by qt_add_qml_module with depends, classname, etc.)
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/StatusQ/qmldir" DESTINATION qml/StatusQ)
endif()

# https://doc.qt.io/qtcreator/creator-qml-modules-with-plugins.html#importing-qml-modules
set(QML_IMPORT_PATH
        ${CMAKE_SOURCE_DIR}/src;${QML_IMPORT_PATH}
        CACHE STRING "")

### Add other subdirectories

if (${STATUSQ_BUILD_SANITY_CHECKER})
    add_subdirectory(sanity_checker)
endif ()

if (${STATUSQ_BUILD_TESTS})
    enable_testing()
    add_subdirectory(tests)
endif ()
