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
        Core CorePrivate Qml Gui Quick QuickControls2 WebChannel Svg REQUIRED)

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

# For shadow build OFF mode, also copy to source directory
if(NOT ${STATUSQ_SHADOW_BUILD})
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

if (NOT DEFINED STATUSQ_SHADOW_BUILD)

    #   About the STATUSQ_SHADOW_BUILD option.
    #
    #   This is an option that defaults to OFF in Debug mode and ON otherwise.
    #   When ON:
    #     - resources are compiled into a shared library
    #   When OFF:
    #     - no resources are compiled, it's expected to use QML/JS sources
    #
    #   STATUSQ_SHADOW_BUILD mode is created for storybook hot reloading
    #   without copying all qml files to build directory.
    #
    #   It's expected for the app to add ${STATUSQ_MODULE_IMPORT_PATH} to
    #   QQmlApplicationEngine::addImportPath.
    #

    if (CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(STATUSQ_SHADOW_BUILD OFF)
    else()
        set(STATUSQ_SHADOW_BUILD ON)
    endif()
endif()

set(STATUSQ_SOURCE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/src/StatusQ")

if (${STATUSQ_SHADOW_BUILD})
    set(STATUSQ_MODULE_IMPORT_PATH ":/")
else()
    set(STATUSQ_MODULE_IMPORT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/src")
endif()

if (NOT PROJECT_IS_TOP_LEVEL)
    set(STATUSQ_MODULE_IMPORT_PATH "${STATUSQ_MODULE_IMPORT_PATH}" PARENT_SCOPE)
    set(STATUSQ_SHADOW_BUILD "${STATUSQ_SHADOW_BUILD}" PARENT_SCOPE)
endif ()

if (${STATUSQ_STATIC_LIB})
    set(LIB_TYPE STATIC)
else()
    set(LIB_TYPE SHARED)
endif ()

add_library(StatusQ ${LIB_TYPE}
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
        include/StatusQ/statusemojimodel.h
        include/StatusQ/statussyntaxhighlighter.h
        include/StatusQ/stringutilsinternal.h
        include/StatusQ/systemutilsinternal.h
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
        src/statusemojimodel.cpp
        src/statussyntaxhighlighter.cpp
        src/stringutilsinternal.cpp
        src/systemutilsinternal.cpp
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
                RUNTIME DESTINATION StatusQ
                LIBRARY DESTINATION StatusQ
                ARCHIVE DESTINATION StatusQ
                )
    endif()
endif()

FetchContent_Declare(
  QtModelsToolkit

  GIT_REPOSITORY https://github.com/status-im/QtModelsToolkit.git
  GIT_TAG b249dc22be1e1e728acce90065f943d7db3636e5
)

FetchContent_MakeAvailable(QtModelsToolkit)

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
    )
endif()

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_link_libraries(StatusQ PRIVATE
            Qt::QuickTest
            )
endif()

target_include_directories(StatusQ PUBLIC include)

### QML compilation and resource bundling (Release / shadow build only)
if (${STATUSQ_SHADOW_BUILD})
    add_definitions(-DBUNDLE_QML_RESOURCES)

    set(_SQ_SRC "${CMAKE_CURRENT_SOURCE_DIR}/src/StatusQ")

    # --- Helper: add a QML submodule as a STATIC target linked into StatusQ ---
    function(statusq_add_qml_submodule TARGET_NAME MODULE_URI SRC_SUBDIR)
        cmake_parse_arguments(ARG "" "" "SINGLETONS;EXCLUDE_SUBDIRS;SOURCES" ${ARGN})
        set(_src_dir "${_SQ_SRC}/${SRC_SUBDIR}")

        # Collect QML/JS files recursively
        file(GLOB_RECURSE _all_files RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
            "${_src_dir}/*.qml" "${_src_dir}/*.js" "${_src_dir}/*.mjs")

        # Exclude sub-module directories if specified
        if(ARG_EXCLUDE_SUBDIRS)
            set(_qml_files)
            foreach(f IN LISTS _all_files)
                set(_skip FALSE)
                foreach(excl IN LISTS ARG_EXCLUDE_SUBDIRS)
                    if(f MATCHES "src/StatusQ/${SRC_SUBDIR}/${excl}/")
                        set(_skip TRUE)
                        break()
                    endif()
                endforeach()
                if(NOT _skip)
                    list(APPEND _qml_files "${f}")
                endif()
            endforeach()
        else()
            set(_qml_files "${_all_files}")
        endif()

        # Set resource alias: strip module source prefix so URI path provides the directory
        # e.g. URI "StatusQ.Core" → prefix "/StatusQ/Core/" + alias "StatusBaseText.qml"
        foreach(f IN LISTS _qml_files)
            string(REGEX REPLACE "^src/StatusQ/${SRC_SUBDIR}/" "" _alias "${f}")
            set_source_files_properties("${f}" PROPERTIES QT_RESOURCE_ALIAS "${_alias}")
        endforeach()

        # Mark singletons
        if(ARG_SINGLETONS)
            set(_singleton_paths)
            foreach(s IN LISTS ARG_SINGLETONS)
                list(APPEND _singleton_paths "src/StatusQ/${SRC_SUBDIR}/${s}")
            endforeach()
            set_source_files_properties(${_singleton_paths} PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
        endif()

        # Collect qmldir and other non-QML resources
        set(_res_files)
        if(EXISTS "${_src_dir}/qmldir")
            set(_qmldir_path "src/StatusQ/${SRC_SUBDIR}/qmldir")
            set_source_files_properties("${_qmldir_path}" PROPERTIES QT_RESOURCE_ALIAS "qmldir")
            list(APPEND _res_files "${_qmldir_path}")
        endif()
        foreach(_pattern LICENSE README.md)
            if(EXISTS "${_src_dir}/${_pattern}")
                set(_res_path "src/StatusQ/${SRC_SUBDIR}/${_pattern}")
                set_source_files_properties("${_res_path}" PROPERTIES QT_RESOURCE_ALIAS "${_pattern}")
                list(APPEND _res_files "${_res_path}")
            endif()
        endforeach()

        string(REPLACE "." "/" _uri_path "${MODULE_URI}")
        qt_add_qml_module(${TARGET_NAME}
            URI "${MODULE_URI}"
            VERSION 0.1
            RESOURCE_PREFIX "/"
            NO_PLUGIN
            STATIC
            OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${_uri_path}"
            QML_FILES ${_qml_files}
            RESOURCES ${_res_files}
        )

        # Add C++ sources if specified (for QML_ELEMENT type registration)
        if(ARG_SOURCES)
            target_sources(${TARGET_NAME} PRIVATE ${ARG_SOURCES})
            target_include_directories(${TARGET_NAME} PRIVATE
                "${CMAKE_CURRENT_SOURCE_DIR}/include"
                "${CMAKE_CURRENT_SOURCE_DIR}/include/StatusQ"
                "${CMAKE_CURRENT_SOURCE_DIR}/src")
            target_link_libraries(${TARGET_NAME} PRIVATE
                Qt::Core Qt::Qml Qt::Quick Qt::QuickPrivate Qt::QuickControls2)
        endif()

        # Link with WHOLE_ARCHIVE to prevent linker from stripping static constructors
        # (module registration and resource initialization)
        target_link_libraries(StatusQ PRIVATE
            "$<LINK_LIBRARY:WHOLE_ARCHIVE,${TARGET_NAME}>")
    endfunction()

    # --- Primary module: StatusQ.Core (attached to StatusQ target) ---
    file(GLOB _core_qml RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
        "${_SQ_SRC}/Core/*.qml" "${_SQ_SRC}/Core/*.js")
    foreach(f IN LISTS _core_qml)
        string(REGEX REPLACE "^src/StatusQ/Core/" "" _alias "${f}")
        set_source_files_properties("${f}" PROPERTIES QT_RESOURCE_ALIAS "${_alias}")
    endforeach()
    set_source_files_properties(
        src/StatusQ/Core/ColorUtils.qml
        src/StatusQ/Core/LocaleUtils.qml
        src/StatusQ/Core/StatusSharedUpdateTimer.qml
        PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
    set(_core_qmldir "src/StatusQ/Core/qmldir")
    set_source_files_properties("${_core_qmldir}" PROPERTIES QT_RESOURCE_ALIAS "qmldir")

    qt_add_qml_module(StatusQ
        URI "StatusQ.Core"
        VERSION 0.1
        RESOURCE_PREFIX "/"
        NO_PLUGIN
        OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/StatusQ/Core"
        QML_FILES ${_core_qml}
        RESOURCES ${_core_qmldir}
    )

    # --- Submodules (STATIC targets linked into StatusQ) ---

    statusq_add_qml_submodule(StatusQ_CoreTheme "StatusQ.Core.Theme" "Core/Theme"
        SINGLETONS Assets.qml Fonts.qml ThemeUtils.qml
        SOURCES
            include/StatusQ/theme.h
            include/StatusQ/themepalette.h
            include/StatusQ/statuscolors.h
            src/theme.cpp
            src/themepalette.cpp
            src/statuscolors.cpp)

    statusq_add_qml_submodule(StatusQ_CoreUtils "StatusQ.Core.Utils" "Core/Utils"
        SINGLETONS AmountsArithmetic.qml Emoji.qml ModelUtils.qml OperatorsUtils.qml StringUtils.qml Utils.qml
        EXCLUDE_SUBDIRS emojibase-parser)

    statusq_add_qml_submodule(StatusQ_CoreBackpressure "StatusQ.Core.Backpressure" "Core/Backpressure"
        SINGLETONS Backpressure.qml)

    statusq_add_qml_submodule(StatusQ_Controls "StatusQ.Controls" "Controls"
        EXCLUDE_SUBDIRS Validators)

    statusq_add_qml_submodule(StatusQ_ControlsValidators "StatusQ.Controls.Validators" "Controls/Validators")

    statusq_add_qml_submodule(StatusQ_Components "StatusQ.Components" "Components"
        EXCLUDE_SUBDIRS private)

    statusq_add_qml_submodule(StatusQ_ComponentsPrivate "StatusQ.Components.private" "Components/private")

    statusq_add_qml_submodule(StatusQ_Popups "StatusQ.Popups" "Popups"
        EXCLUDE_SUBDIRS Dialog)

    statusq_add_qml_submodule(StatusQ_PopupsDialog "StatusQ.Popups.Dialog" "Popups/Dialog")

    statusq_add_qml_submodule(StatusQ_Layout "StatusQ.Layout" "Layout")

    statusq_add_qml_submodule(StatusQ_Platform "StatusQ.Platform" "Platform")

    statusq_add_qml_submodule(StatusQ_Validators "StatusQ.Validators" "Validators")

    # --- Asset resources (binary assets — no QML compilation) ---
    set(STATUSQ_ASSET_QRC_FILES
        src/assets/fonts/fonts.qrc
        src/assets/img/img.qrc
        src/assets/png/png.qrc
        src/assets/twemoji/twemoji.qrc
        src/assets/twemoji/twemoji-svg.qrc
    )
    if(ANDROID OR IOS)
        list(APPEND STATUSQ_ASSET_QRC_FILES src/assets/png/png-mobile.qrc)
    else()
        list(APPEND STATUSQ_ASSET_QRC_FILES src/assets/png/png-desktop.qrc)
    endif()

    if (${STATUSQ_STATIC_LIB})
        qt_add_resources(STATUSQ_ASSET_QRC ${STATUSQ_ASSET_QRC_FILES})
    else()
        qt_add_big_resources(STATUSQ_ASSET_QRC ${STATUSQ_ASSET_QRC_FILES})
    endif()

    target_sources(StatusQ PRIVATE ${STATUSQ_ASSET_QRC})
endif()

install(TARGETS StatusQ
        RUNTIME DESTINATION StatusQ
        LIBRARY DESTINATION StatusQ
        )

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
