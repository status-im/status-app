cmake_minimum_required(VERSION 3.19)

project(AppResources LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick QmlPrivate QuickPrivate)

option(APP_AOT_COMPILE "Enable QML AOT compilation for app resources" ON)
option(APP_RESOURCES_STATIC_LIB "Build AppResources as a static library" ON)
option(APP_RESOURCES_MOBILE "Build for mobile platform (swap +mobile file selector variants)" OFF)

qt_standard_project_setup(REQUIRES 6.5)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# =========================================================================
# Build StatusQ as a subdirectory so qmlcachegen can resolve import StatusQ.*
# This registers StatusQ's QML module metadata in the CMake build graph,
# allowing qmlcachegen to properly resolve types instead of doing expensive
# unresolved-type analysis.
# Guarded: when included from a parent project that already added StatusQ,
# the existing target is reused.
# =========================================================================
if(NOT TARGET StatusQ)
    set(STATUSQ_BUILD_SANITY_CHECKER OFF CACHE BOOL "" FORCE)
    set(STATUSQ_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(STATUSQ_STATIC_LIB ON CACHE BOOL "" FORCE)
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../StatusQ ${CMAKE_CURRENT_BINARY_DIR}/StatusQ EXCLUDE_FROM_ALL)
endif()

# QML import paths for qmlcachegen — includes StatusQ build output + app paths
set(QML_IMPORT_PATH
    "${CMAKE_CURRENT_BINARY_DIR}/StatusQ"
    "${CMAKE_CURRENT_SOURCE_DIR}/../StatusQ/src"
    "${CMAKE_CURRENT_SOURCE_DIR}/../imports"
    "${CMAKE_CURRENT_SOURCE_DIR}/../app"
    CACHE STRING "QML import paths for qmlcachegen"
)

# Suppress QTP0004 warning — we have hand-written qmldir files
qt_policy(SET QTP0004 OLD)

# =========================================================================
# Helper function: create a QML module from a directory
#
# Creates a static library target with qt_add_qml_module for all QML/JS
# files in the given source directory. Each module is kept small to avoid
# memory-hungry compilation units.
#
# Arguments:
#   IMPORT_ROOT  - Import root path (e.g., "../app" or "../imports")
#                  Used to derive URI and RESOURCE_PREFIX.
#
# This function scans IMPORT_ROOT recursively for directories containing
# a qmldir file. Each such directory becomes its own qt_add_qml_module
# target with NON-RECURSIVE file collection (only files in that directory,
# not subdirectories). This avoids the generated qmldir flattening
# subdirectory files into the root module.
#
# For each directory with a qmldir:
#   - TARGET_NAME = sanitized path (e.g., AppQml_AppLayouts_Wallet_controls)
#   - URI = path relative to IMPORT_ROOT with "/" → "."
#   - RESOURCE_PREFIX = /<import_root_name>
#   - Files at: :/RESOURCE_PREFIX/URI_AS_PATH/<filename>
# =========================================================================
function(add_all_qml_modules IMPORT_ROOT)
    # Derive RESOURCE_PREFIX from IMPORT_ROOT: "../app" → "/app"
    string(REGEX REPLACE "^\\.\\.\/" "" _prefix_name "${IMPORT_ROOT}")
    set(_res_prefix "/${_prefix_name}")

    # Find all directories containing a qmldir file
    file(GLOB_RECURSE _all_qmldirs "${IMPORT_ROOT}/*/qmldir")
    # Also check the import root itself
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${IMPORT_ROOT}/qmldir")
        list(APPEND _all_qmldirs "${IMPORT_ROOT}/qmldir")
    endif()

    foreach(_qmldir_path IN LISTS _all_qmldirs)
        get_filename_component(_dir "${_qmldir_path}" DIRECTORY)

        # Skip +mobile directories — they are file selector variants, not separate modules.
        # On mobile builds, their files are swapped into the parent module below.
        if("${_dir}" MATCHES "\\+mobile")
            continue()
        endif()

        # Make relative to CMAKE_CURRENT_SOURCE_DIR
        file(RELATIVE_PATH _rel_dir "${CMAKE_CURRENT_SOURCE_DIR}" "${_dir}")
        # If already relative (starts with ..), use as-is
        if(NOT IS_ABSOLUTE "${_dir}")
            set(_rel_dir "${_dir}")
        endif()

        # Derive URI: strip IMPORT_ROOT from dir, convert "/" to "."
        string(REGEX REPLACE "^${IMPORT_ROOT}/?" "" _uri_path "${_rel_dir}")
        if("${_uri_path}" STREQUAL "")
            continue()  # Skip import root itself if it has no QML files
        endif()
        string(REPLACE "/" "." _uri "${_uri_path}")

        # Create a sanitized target name
        string(REPLACE "/" "_" _target_name "${_prefix_name}_${_uri_path}")
        string(REPLACE "." "_" _target_name "${_target_name}")

        # Collect QML/JS files NON-RECURSIVELY (only this directory)
        file(GLOB _qml_files
            RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
            "${_rel_dir}/*.qml"
        )
        file(GLOB _js_files
            RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
            "${_rel_dir}/*.js"
        )

        # Check if the hand-written qmldir re-exports types from subdirectories
        # (entries like "Foo 1.0 subdir/Foo.qml"). If so, include those files
        # so the generated qmldir preserves the umbrella pattern.
        set(_qmldir_file "${_rel_dir}/qmldir")
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_qmldir_file}")
            file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/${_qmldir_file}" _qmldir_lines)
            foreach(_line IN LISTS _qmldir_lines)
                # Match lines like "TypeName 1.0 subdir/File.qml" or "singleton TypeName 1.0 subdir/File.qml"
                if("${_line}" MATCHES "([a-zA-Z/]+\\.qml)$")
                    set(_ref_file "${CMAKE_MATCH_1}")
                    # Only if it references a subdirectory (contains /)
                    if("${_ref_file}" MATCHES "/")
                        set(_full_path "${_rel_dir}/${_ref_file}")
                        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_full_path}" AND NOT "${_full_path}" IN_LIST _qml_files)
                            list(APPEND _qml_files "${_full_path}")
                        endif()
                    endif()
                endif()
            endforeach()
        endif()

        # Handle +mobile file selector variants.
        # First, always remove +mobile/ files from the glob results.
        list(FILTER _qml_files EXCLUDE REGEX "\\+mobile/")
        list(FILTER _js_files EXCLUDE REGEX "\\+mobile/")

        if(APP_RESOURCES_MOBILE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_rel_dir}/+mobile")
            # Mobile build: swap desktop files with +mobile variants.
            # +mobile files replace their desktop counterparts (same filename),
            # so qmlcachegen never sees imports for unavailable modules (e.g. QtWebEngine).
            file(GLOB _mobile_qml RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "${_rel_dir}/+mobile/*.qml")
            file(GLOB _mobile_js RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "${_rel_dir}/+mobile/*.js")
            foreach(_mfile IN LISTS _mobile_qml)
                get_filename_component(_mname "${_mfile}" NAME)
                # Remove the desktop version that this +mobile file replaces
                list(FILTER _qml_files EXCLUDE REGEX "/${_mname}$")
                list(FILTER _qml_files EXCLUDE REGEX "^${_rel_dir}/${_mname}$")
                # Add the +mobile version in its place
                list(APPEND _qml_files "${_mfile}")
            endforeach()
            foreach(_mfile IN LISTS _mobile_js)
                get_filename_component(_mname "${_mfile}" NAME)
                list(FILTER _js_files EXCLUDE REGEX "/${_mname}$")
                list(FILTER _js_files EXCLUDE REGEX "^${_rel_dir}/${_mname}$")
                list(APPEND _js_files "${_mfile}")
            endforeach()
            list(LENGTH _mobile_qml _mobile_count)
            if(_mobile_count GREATER 0)
                message(STATUS "  +mobile swap: ${_mobile_count} files replaced in ${_uri}")
            endif()
        endif()

        if(NOT _qml_files)
            continue()
        endif()

        # Detect "pragma Singleton" in QML files and set the QT_QML_SINGLETON_TYPE
        # property so qt_add_qml_module generates correct qmldir entries.
        foreach(_file IN LISTS _qml_files)
            file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/${_file}" _first_lines LIMIT_COUNT 5)
            foreach(_line IN LISTS _first_lines)
                if("${_line}" MATCHES "pragma Singleton")
                    set_source_files_properties("${_file}" PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
                    break()
                endif()
            endforeach()
        endforeach()

        # Skip qmlcachegen for files known to cause OOM
        foreach(_file IN LISTS _qml_files)
            foreach(_skip IN LISTS QML_AOT_SKIP_FILES)
                if("${_file}" MATCHES "${_skip}")
                    set_source_files_properties("${_file}" PROPERTIES QT_QML_SKIP_CACHEGEN TRUE)
                    message(STATUS "  Skipping cachegen for: ${_file}")
                endif()
            endforeach()
        endforeach()

        # Set resource aliases relative to the module directory
        # Root files: just filename. Subdirectory re-exports: keep subdir/filename.
        # +mobile files get aliased without the +mobile/ prefix so they replace
        # desktop files at the same resource path.
        foreach(_file IN LISTS _qml_files _js_files)
            string(REGEX REPLACE "^${_rel_dir}/" "" _alias "${_file}")
            string(REGEX REPLACE "^\\+mobile/" "" _alias "${_alias}")
            set_source_files_properties("${_file}" PROPERTIES QT_RESOURCE_ALIAS "${_alias}")
        endforeach()

        add_library(${_target_name} STATIC)

        qt_add_qml_module(${_target_name}
            URI "${_uri}"
            VERSION 1.0
            RESOURCE_PREFIX "${_res_prefix}"
            QML_FILES ${_qml_files} ${_js_files}
            OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${_uri_path}"
            NO_GENERATE_EXTRA_QMLDIRS
        )
        target_link_libraries(${_target_name} PRIVATE Qt6::Core Qt6::Qml Qt6::Quick Qt6::QmlPrivate Qt6::QuickPrivate)

        # Track targets and resource names via global properties (PARENT_SCOPE
        # doesn't accumulate properly across loop iterations in a function)
        set_property(GLOBAL APPEND PROPERTY APP_AOT_INCLUDED_QML_FILES ${_qml_files})
        set_property(GLOBAL APPEND PROPERTY APP_AOT_TARGETS_PROP ${_target_name})
        string(REPLACE "." "_" _uri_underscored "${_uri}")
        set_property(GLOBAL APPEND PROPERTY APP_AOT_RESOURCE_NAMES_PROP
            "qmake_${_uri_underscored}"
            "${_target_name}_raw_qml_0"
        )

        list(LENGTH _qml_files _count)
        message(STATUS "QML AOT module: ${_target_name} (${_count} QML files, URI=${_uri})")
    endforeach()
endfunction()

if(APP_AOT_COMPILE)

    set(APP_AOT_TARGETS "")

    # Files to skip qmlcachegen AOT compilation for (regex patterns).
    # These files cause excessive memory usage (>20GB) with --bare AOT mode.
    # They are still included as resources and get runtime bytecode caching.
    # The qmake build (mobile) compiles these fine without --bare.
    set(QML_AOT_SKIP_FILES
        "StatusChatInput\\.qml"
    )

    # =========================================================================
    # Auto-discover all QML modules from qmldir files
    # Each directory containing a qmldir becomes its own qt_add_qml_module
    # target with non-recursive file collection. This avoids the generated
    # qmldir flattening subdirectory files into parent modules.
    # =========================================================================

    add_all_qml_modules("../app")
    add_all_qml_modules("../imports")

    # Retrieve accumulated targets and resource names from global properties
    get_property(APP_AOT_TARGETS GLOBAL PROPERTY APP_AOT_TARGETS_PROP)
    get_property(APP_AOT_RESOURCE_NAMES GLOBAL PROPERTY APP_AOT_RESOURCE_NAMES_PROP)

    # Collect the list of QML files already included in modules
    get_property(_included_qml GLOBAL PROPERTY APP_AOT_INCLUDED_QML_FILES)

    # =========================================================================
    # Orphan QML/JS files: directories without a qmldir (private/, states/, etc.)
    # These are bundled as plain resources (no AOT) to ensure they're available.
    # =========================================================================
    file(GLOB_RECURSE _all_app_qml RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "../app/*.qml")
    file(GLOB_RECURSE _all_app_js RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "../app/*.js")
    file(GLOB_RECURSE _all_imports_qml RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "../imports/*.qml")
    file(GLOB_RECURSE _all_imports_js RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "../imports/*.js")
    set(_all_qml ${_all_app_qml} ${_all_imports_qml})
    set(_all_js ${_all_app_js} ${_all_imports_js})
    if(NOT APP_RESOURCES_MOBILE)
        list(FILTER _all_qml EXCLUDE REGEX "\\+mobile/")
        list(FILTER _all_js EXCLUDE REGEX "\\+mobile/")
    endif()

    # Remove files already included in AOT modules
    if(_included_qml)
        list(REMOVE_ITEM _all_qml ${_included_qml})
    endif()
    # Remove JS files already included (approximate — js files from module dirs)
    # For simplicity, just keep all orphan JS files

    # Set aliases: strip "../" prefix to match resource paths
    set(_orphan_files ${_all_qml} ${_all_js})
    foreach(_file IN LISTS _orphan_files)
        string(REGEX REPLACE "^\\.\\.\/" "" _alias "${_file}")
        set_source_files_properties("${_file}" PROPERTIES QT_RESOURCE_ALIAS "${_alias}")
    endforeach()

    list(LENGTH _all_qml _orphan_count)
    if(_orphan_count GREATER 0)
        message(STATUS "Orphan QML files (no qmldir, bundled as resources): ${_orphan_count}")
    endif()

    # =========================================================================
    # Non-QML assets + root-level files (main.qml, etc.)
    # These go through qt_add_resources (rcc embedding, no qmlcachegen)
    # =========================================================================

    # Root-level QML files (main.qml, etc.)
    file(GLOB ROOT_QML_FILES
        RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
        "../*.qml"
    )

    # Asset files — single glob, split by category for resource grouping
    file(GLOB_RECURSE ALL_ASSET_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
        "../app/*.svg" "../app/*.png" "../app/*.ico" "../app/*.icns"
        "../app/*.mp3" "../app/*.wav" "../app/*.otf" "../app/*.ttf"
        "../app/*.webm" "../app/*.txt" "../app/*.gif" "../app/*.json"
        "../app/*.html" "../app/*.mdwn"
        "../imports/*.svg" "../imports/*.png" "../imports/*.ico" "../imports/*.icns"
        "../imports/*.mp3" "../imports/*.wav" "../imports/*.otf" "../imports/*.ttf"
        "../imports/*.webm" "../imports/*.txt" "../imports/*.gif" "../imports/*.json"
        "../imports/*.html" "../imports/*.mdwn"
    )

    if(NOT APP_RESOURCES_MOBILE)
        list(FILTER ALL_ASSET_FILES EXCLUDE REGEX "\\+mobile/")
    endif()

    # Split into resource groups by extension
    set(ASSET_IMAGES ${ALL_ASSET_FILES})
    list(FILTER ASSET_IMAGES INCLUDE REGEX "\\.(svg|png|ico|icns|gif)$")
    set(ASSET_MEDIA ${ALL_ASSET_FILES})
    list(FILTER ASSET_MEDIA INCLUDE REGEX "\\.(mp3|wav|webm)$")
    set(ASSET_FONTS ${ALL_ASSET_FILES})
    list(FILTER ASSET_FONTS INCLUDE REGEX "\\.(otf|ttf)$")
    set(ASSET_DATA ${ALL_ASSET_FILES})
    list(FILTER ASSET_DATA INCLUDE REGEX "\\.(txt|json|html|mdwn)$")

    # Set aliases: strip "../" prefix
    foreach(_file IN LISTS ROOT_QML_FILES ALL_ASSET_FILES)
        string(REGEX REPLACE "^\\.\\.\/" "" _alias "${_file}")
        set_source_files_properties("${_file}" PROPERTIES QT_RESOURCE_ALIAS "${_alias}")
    endforeach()

    add_library(AppAssets STATIC)
    target_link_libraries(AppAssets PRIVATE Qt6::Core)

    # Helper: add resources and track their names for Q_INIT_RESOURCE generation
    macro(app_add_resources TARGET NAME)
        qt_add_resources(${TARGET} "${NAME}" ${ARGN})
        list(APPEND APP_AOT_RESOURCE_NAMES "${NAME}")
    endmacro()

    if(ROOT_QML_FILES)
        app_add_resources(AppAssets "app_root_qml" PREFIX "/" FILES ${ROOT_QML_FILES})
    endif()
    if(ASSET_IMAGES)
        app_add_resources(AppAssets "app_assets_images" PREFIX "/" FILES ${ASSET_IMAGES})
    endif()
    if(ASSET_MEDIA)
        app_add_resources(AppAssets "app_assets_media" PREFIX "/" FILES ${ASSET_MEDIA})
    endif()
    if(ASSET_FONTS)
        app_add_resources(AppAssets "app_assets_fonts" PREFIX "/" FILES ${ASSET_FONTS})
    endif()
    if(ASSET_DATA)
        app_add_resources(AppAssets "app_assets_data" PREFIX "/" FILES ${ASSET_DATA})
    endif()

    # Add orphan QML/JS files (directories without qmldir)
    if(_orphan_files)
        app_add_resources(AppAssets "app_orphan_qml" PREFIX "/" FILES ${_orphan_files})
    endif()

    list(APPEND APP_AOT_TARGETS AppAssets)

    # =========================================================================
    # Create AppResources as a proper QML module via qt_add_qml_module.
    # Qt auto-generates the plugin class, qmldir, and metadata.
    #
    # We add a Q_CONSTRUCTOR_FUNCTION source to the backing target that
    # calls Q_INIT_RESOURCE for every sub-module. Because these are explicit
    # symbol references, the linker pulls them from the sub-module static
    # libs — no --whole-archive needed.
    # =========================================================================

    # --- Discover Qt QML dependencies via qmlimportscanner ---
    get_filename_component(_qt_prefix "${Qt6_DIR}/../../.." ABSOLUTE)
    find_program(QMLIMPORTSCANNER_BIN qmlimportscanner HINTS "${_qt_prefix}/libexec" "${_qt_prefix}/bin")

    set(_qml_deps "")
    if(QMLIMPORTSCANNER_BIN)
        # Extract all external module dependencies (Qt + StatusQ + others).
        # Filter out internal modules that are part of AppResources itself.
        execute_process(
            COMMAND sh -c "\"${QMLIMPORTSCANNER_BIN}\" \
                -rootPath \"${CMAKE_CURRENT_SOURCE_DIR}/../app\" \
                -rootPath \"${CMAKE_CURRENT_SOURCE_DIR}/../imports\" \
                -importPath \"${_qt_prefix}/qml\" \
                -importPath \"${CMAKE_CURRENT_SOURCE_DIR}/../StatusQ/src\" \
                -importPath \"${CMAKE_CURRENT_SOURCE_DIR}/../imports\" \
                -importPath \"${CMAKE_CURRENT_SOURCE_DIR}/../app\" \
                2>/dev/null | grep '\"name\"' | \
                sed 's/.*\"name\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/' | \
                grep -v '^$' | sort -u"
            OUTPUT_VARIABLE _all_deps_raw
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        if(_all_deps_raw)
            string(REPLACE "\n" ";" _all_deps "${_all_deps_raw}")
            # Modules unavailable on mobile platforms
            set(_mobile_excluded_deps "QtWebEngine" "QtWebEngine.Controls")
            foreach(_dep IN LISTS _all_deps)
                # Keep Qt modules, StatusQ, and other external modules.
                # Skip QML (built-in), internal app/imports modules, and empty entries.
                if("${_dep}" MATCHES "^Qt" OR "${_dep}" STREQUAL "StatusQ")
                    # On mobile, skip modules that are not available (e.g. QtWebEngine)
                    if(APP_RESOURCES_MOBILE AND "${_dep}" IN_LIST _mobile_excluded_deps)
                        message(STATUS "  Skipping mobile-excluded dependency: ${_dep}")
                        continue()
                    endif()
                    list(APPEND _qml_deps "${_dep}")
                endif()
            endforeach()
            list(LENGTH _qml_deps _dep_count)
            message(STATUS "AppResources: ${_dep_count} QML dependencies discovered")
        endif()
    endif()

    # --- Generate Q_INIT_RESOURCE source for all sub-module resources ---
    set(_init_lines "")
    foreach(_res IN LISTS APP_AOT_RESOURCE_NAMES)
        string(APPEND _init_lines "    Q_INIT_RESOURCE(${_res})@SEMICOLON@\n")
    endforeach()
    string(REPLACE "@SEMICOLON@" ";" _init_lines "${_init_lines}")

    set(_init_content
"#include <QtGlobal>\nstatic void initAppResources() {\n${_init_lines}}\nQ_CONSTRUCTOR_FUNCTION(initAppResources)\n\
// Stub type registration — AppResources has no C++ types, only QML resources.\n\
void qml_register_types_AppResources() {}\n")
    string(REPLACE "@SEMICOLON@" ";" _init_content "${_init_content}")
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/app_resources_init.cpp" "${_init_content}")

    # --- Create QML module: generates plugin class + qmldir ---
    if(APP_RESOURCES_STATIC_LIB)
        set(_lib_type STATIC)
    else()
        set(_lib_type SHARED)
    endif()

    add_library(AppResourcesPlugin ${_lib_type}
        "${CMAKE_CURRENT_BINARY_DIR}/app_resources_init.cpp"
    )
    target_link_libraries(AppResourcesPlugin PRIVATE Qt6::Core Qt6::Qml Qt6::Quick)

    qt_add_qml_module(AppResourcesPlugin
        URI "AppResources"
        VERSION 1.0
        RESOURCE_PREFIX "/"
        PLUGIN_TARGET AppResourcesPluginPlugin
        DEPENDENCIES ${_qml_deps}
        OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/AppResources"
        NO_GENERATE_EXTRA_QMLDIRS
    )
    # When consumed as a subdirectory (unified CMake build), CMake resolves
    # transitive static lib deps automatically via target_link_libraries.
    # Link sub-modules so the linker can resolve symbols.
    target_link_libraries(AppResourcesPlugin PRIVATE ${APP_AOT_TARGETS} Qt6::QmlPrivate Qt6::QuickPrivate)

    add_custom_target(AppResources ALL
        DEPENDS AppResourcesPlugin AppResourcesPluginPlugin ${APP_AOT_TARGETS})

    # Install targets for standalone builds (backward compat)
    if(APP_RESOURCES_STATIC_LIB)
        install(TARGETS AppResourcesPlugin AppResourcesPluginPlugin ${APP_AOT_TARGETS}
            ARCHIVE DESTINATION qml/AppResources)
    else()
        install(TARGETS AppResourcesPlugin AppResourcesPluginPlugin
            RUNTIME DESTINATION qml/AppResources
            LIBRARY DESTINATION qml/AppResources)
    endif()

    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/AppResources/qmldir" DESTINATION qml/AppResources)

    # Print summary
    list(LENGTH APP_AOT_TARGETS _total_targets)
    list(LENGTH APP_AOT_RESOURCE_NAMES _total_resources)
    message(STATUS "Total QML AOT targets: ${_total_targets}, resource sets: ${_total_resources}")
    message(STATUS "Plugin: AppResourcesPlugin (links ${_total_targets} module targets)")

    # Unity build: merge AOT-generated .cpp files (16 per batch) to reduce
    # compilation units from ~4000 to ~250.
    foreach(_aot_target IN LISTS APP_AOT_TARGETS)
        set_target_properties(${_aot_target} PROPERTIES
            UNITY_BUILD ON
            UNITY_BUILD_BATCH_SIZE 16
        )
    endforeach()

else()
    # AOT disabled: build a stub plugin with no resources.
    # The app loads resources at runtime via QResource::registerResource().
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/app_resources_plugin_stub.cpp"
"#include <QQmlEngineExtensionPlugin>\n\
class AppResourcesPlugin : public QQmlEngineExtensionPlugin {\n\
    Q_OBJECT\n\
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)\n\
};\n\
#include \"app_resources_plugin_stub.moc\"\n")

    if(APP_RESOURCES_STATIC_LIB)
        set(_stub_lib_type STATIC)
    else()
        set(_stub_lib_type SHARED)
    endif()
    add_library(AppResourcesPlugin ${_stub_lib_type} "${CMAKE_CURRENT_BINARY_DIR}/app_resources_plugin_stub.cpp")
    target_link_libraries(AppResourcesPlugin PRIVATE Qt6::Core Qt6::Qml)
endif()
