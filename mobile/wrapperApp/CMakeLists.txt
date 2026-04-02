cmake_minimum_required(VERSION 3.19)
project(StatusMobile LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS
    Quick Gui Qml WebView Svg Widgets Multimedia QuickControls2 WebChannel Core5Compat LinguistTools)

qt_standard_project_setup(REQUIRES 6.5)
# Keep hand-written qmldir files in StatusQ and app QML modules
qt_policy(SET QTP0004 OLD)

option(FLAG_KEYCARD_ENABLED "Enable Keycard/NFC support" OFF)
option(APP_AOT_COMPILE "Enable QML AOT compilation" ON)
option(APP_RESOURCES_MOBILE "Mobile platform file selector" ON)

# ---- Platform optimizations ----

if(ANDROID)
    # Thin LTO: cross-module optimization with faster link times than full LTO.
    # Applied globally so all subdirectories (DOtherSide, StatusQ, AppResources)
    # are compiled with LTO and can be optimized across module boundaries.
    add_compile_options(-flto=thin)
    add_link_options(-flto=thin)

    # 16KB page alignment required for Android 15+ (API 35).
    # Also set per-target on StatusMobile, but global ensures all shared libs comply.
    add_link_options(-Wl,-z,max-page-size=16384)
endif()

set(STATUS_DESKTOP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../..")

# ---- Subdirectory deps (replaces separate build scripts) ----

# DOtherSide
set(ENABLE_DOCS OFF CACHE BOOL "" FORCE)
set(ENABLE_TESTS OFF CACHE BOOL "" FORCE)
set(ENABLE_DYNAMIC_LIBS OFF CACHE BOOL "" FORCE)
set(ENABLE_STATIC_LIBS ON CACHE BOOL "" FORCE)
add_subdirectory(${STATUS_DESKTOP_DIR}/vendor/DOtherSide
                 ${CMAKE_BINARY_DIR}/DOtherSide EXCLUDE_FROM_ALL)

# StatusQ (includes SCodes, MobileWebView, QtModelsToolkit, MobileUI)
set(STATUSQ_BUILD_SANITY_CHECKER OFF CACHE BOOL "" FORCE)
set(STATUSQ_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(STATUSQ_STATIC_LIB ON CACHE BOOL "" FORCE)
set(STATUSQ_SHADOW_BUILD ON CACHE BOOL "" FORCE)
add_subdirectory(${STATUS_DESKTOP_DIR}/ui/StatusQ
                 ${CMAKE_BINARY_DIR}/StatusQ EXCLUDE_FROM_ALL)

# AppResources (QML AOT compilation — StatusQ inclusion guarded internally)
set(APP_RESOURCES_STATIC_LIB ON CACHE BOOL "" FORCE)
add_subdirectory(${STATUS_DESKTOP_DIR}/ui/app_resources
                 ${CMAKE_BINARY_DIR}/AppResources EXCLUDE_FROM_ALL)

# ---- Pre-built libraries (Nim, Go, OpenSSL, QRCodeGen) ----
set(MOBILE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")

# Derive platform paths from cmake's own detection (not env vars)
if(ANDROID)
    set(_platform "android")
    if(ANDROID_ABI STREQUAL "arm64-v8a")
        set(_arch "arm64")
    elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
        set(_arch "arm")
    else()
        set(_arch "x86_64")
    endif()
elseif(IOS)
    set(_platform "ios")
    set(_arch "${CMAKE_OSX_ARCHITECTURES}")
else()
    message(FATAL_ERROR "Unsupported platform: expected ANDROID or IOS")
endif()
set(LIB_DIR "${MOBILE_DIR}/lib/${_platform}")

# status-keycard-qt (optional)
if(FLAG_KEYCARD_ENABLED)
    find_package(Qt6 REQUIRED COMPONENTS Nfc)
    set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
    set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    # OpenSSL paths for mobile builds (keycard needs crypto for key derivation)
    # These must be set before add_subdirectory since status-keycard-qt checks them.
    if(NOT DEFINED OPENSSL_CRYPTO_LIBRARY)
        if(ANDROID)
            set(OPENSSL_CRYPTO_LIBRARY "${LIB_DIR}/libcrypto_3.so" CACHE FILEPATH "" FORCE)
        else()
            set(OPENSSL_CRYPTO_LIBRARY "${LIB_DIR}/libcrypto_3.a" CACHE FILEPATH "" FORCE)
        endif()
    endif()
    if(NOT DEFINED OPENSSL_BUILD_INCLUDE_DIR)
        set(OPENSSL_BUILD_INCLUDE_DIR "${MOBILE_DIR}/build/${_platform}/openssl-${_platform}-${_arch}/include" CACHE PATH "" FORCE)
    endif()
    if(NOT DEFINED OPENSSL_SOURCE_INCLUDE_DIR)
        set(OPENSSL_SOURCE_INCLUDE_DIR "${MOBILE_DIR}/vendors/openssl/include" CACHE PATH "" FORCE)
    endif()
    add_subdirectory(${STATUS_DESKTOP_DIR}/vendor/status-keycard-qt
                     ${CMAKE_BINARY_DIR}/status-keycard-qt EXCLUDE_FROM_ALL)
endif()

# nim_status_client — static on both Android and iOS
add_library(nim_status_client STATIC IMPORTED GLOBAL)
set_target_properties(nim_status_client PROPERTIES
    IMPORTED_LOCATION "${LIB_DIR}/libnim_status_client.a"
)

# ---- Wrapper app ----
qt_add_executable(StatusMobile sources/main.cpp)

target_link_libraries(StatusMobile PRIVATE
    Qt6::Quick Qt6::Gui Qt6::Qml Qt6::WebView Qt6::Svg
    Qt6::Widgets Qt6::Multimedia Qt6::QuickControls2 Qt6::WebChannel Qt6::Core5Compat
    nim_status_client
    DOtherSideStatic
    StatusQ
    statusqplugin
    AppResourcesPlugin
    AppResourcesPluginPlugin
)

# The QML import scanner needs to know where our QML sources are.
# StatusMobile has no QML files itself — they live in AppResources and StatusQ.
# Without these paths, the scanner finds 0 imports and no QML plugins get linked
# (fatal on iOS static builds where plugins can't be loaded at runtime).
set_target_properties(StatusMobile PROPERTIES
    QT_QML_IMPORT_PATH "${STATUS_DESKTOP_DIR}/ui/StatusQ/src;${STATUS_DESKTOP_DIR}/ui/imports;${STATUS_DESKTOP_DIR}/ui/app"
    QT_QML_IMPORT_SCANNER_EXTRA_ROOT_PATHS "${STATUS_DESKTOP_DIR}/ui"
)
qt_import_qml_plugins(StatusMobile)

if(FLAG_KEYCARD_ENABLED)
    target_link_libraries(StatusMobile PRIVATE Qt6::Nfc status-keycard-qt)
    target_compile_definitions(StatusMobile PRIVATE FLAG_KEYCARD_ENABLED)
endif()

# ---- App identity ----
# BUILD_VARIANT controls app name and package ID (release, pr, debug).
# Debug display name ("Status Debug") is handled by gradle buildTypes.
set(BUILD_VARIANT "$ENV{BUILD_VARIANT}" CACHE STRING "Build variant: release or pr")

if(BUILD_VARIANT STREQUAL "pr")
    set(_app_name "StatusPR")
    set(_package_name "app.status.mobile.pr")
else()
    set(_app_name "Status")
    set(_package_name "app.status.mobile")
endif()

set_target_properties(StatusMobile PROPERTIES OUTPUT_NAME "${_app_name}")

# ---- Android ----
if(ANDROID)
    # Only link the stub — it provides the same C symbols as libstatus.so but
    # forwards calls via Binder IPC to the separate status-go service process.
    # libstatus.so and libstatus_service.so must NOT be linked here; they are
    # bundled in the APK (QT_ANDROID_EXTRA_LIBS) for the :statusgo service
    # process to load via System.loadLibrary().
    target_link_libraries(StatusMobile PRIVATE
        status_stub sds ssl_3 crypto_3 qrcodegen
    )
    target_link_directories(StatusMobile PRIVATE ${LIB_DIR})

    # Create a staging directory that merges custom Android sources with
    # dependency Java sources (MobileWebView). androiddeployqt overlays this
    # on top of Qt's default template and generates gradle.properties with
    # the correct local paths.
    set(_android_staging_dir "${CMAKE_BINARY_DIR}/android-package-staging")
    file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/../android/qt6/"
         DESTINATION "${_android_staging_dir}")

    # MobileWebView Java sources (fetched by StatusQ's FetchContent)
    if(DEFINED mobilewebview_SOURCE_DIR)
        set(_mwv_java "${mobilewebview_SOURCE_DIR}/mobilewebview/android/src")
        if(EXISTS "${_mwv_java}")
            file(COPY "${_mwv_java}/org"
                 DESTINATION "${_android_staging_dir}/src/")
        endif()
    endif()

    # Shared libs that Android needs to bundle into the APK separately.
    # Go/OpenSSL libs must remain as .so — they are loaded by JNI or have
    # separate process lifecycle (status_service runs in :StatusGoService).
    set_target_properties(StatusMobile PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${_android_staging_dir}"
        QT_ANDROID_EXTRA_LIBS
            "${LIB_DIR}/libstatus.so\;${LIB_DIR}/libstatus_stub.so\;${LIB_DIR}/libstatus_service.so\;${LIB_DIR}/libsds.so\;${LIB_DIR}/libssl_3.so\;${LIB_DIR}/libcrypto_3.so"
        QT_ANDROID_PACKAGE_NAME "${_package_name}"
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
        QT_ANDROID_VERSION_CODE "$ENV{VERSION_CODE}"
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 35
    )
endif()

# ---- iOS ----
if(IOS)
    target_link_libraries(StatusMobile PRIVATE
        status sds ssl_3 crypto_3 qrcodegen resolv
        "-framework LocalAuthentication" "-framework Security"
        "-framework CoreMotion" "-framework UIKit"
        "-framework Foundation" "-framework UserNotifications"
    )

    # Link Qt-bundled FFmpeg xcframeworks (CMake 3.28+ resolves the correct platform slice)
    qt_add_ios_ffmpeg_libraries(StatusMobile)
    target_link_directories(StatusMobile PRIVATE ${LIB_DIR})

    if(FLAG_KEYCARD_ENABLED)
        target_link_libraries(StatusMobile PRIVATE "-framework CoreNFC")
    endif()

    set_target_properties(StatusMobile PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/../ios/Info.plist"
        QT_IOS_LAUNCH_SCREEN "${CMAKE_CURRENT_SOURCE_DIR}/../ios/launch-image-universal.storyboard"
        MACOSX_BUNDLE_GUI_IDENTIFIER "${_package_name}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "8B5X2M6H2Y"
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
    )

    target_sources(StatusMobile PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../ios/Images.xcassets")
    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/../ios/Images.xcassets"
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

    if(FLAG_KEYCARD_ENABLED)
        set_target_properties(StatusMobile PROPERTIES
            XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/../ios/Status.entitlements")
    else()
        set_target_properties(StatusMobile PROPERTIES
            XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/../ios/Status-NoKeycard.entitlements")
    endif()
endif()

# ---- Translations ----
set(_i18n_dir "${STATUS_DESKTOP_DIR}/ui/i18n")
qt_add_translations(StatusMobile
    TS_FILES
        ${_i18n_dir}/qml_en.ts
        ${_i18n_dir}/qml_cs.ts
        ${_i18n_dir}/qml_ko.ts
        ${_i18n_dir}/qml_es.ts
    LUPDATE_TARGET update_translations
    LRELEASE_TARGET compile_translations
    LUPDATE_OPTIONS -locations none -no-obsolete
    LRELEASE_OPTIONS -removeidentical -compress -nounfinished
    RESOURCE_PREFIX "/i18n"
    MERGE_QT_TRANSLATIONS
    QT_TRANSLATION_CATALOGS qtbase qtmultimedia qtwebengine qtdeclarative
    SOURCE_TARGETS StatusMobile StatusQ AppResourcesPlugin
)
