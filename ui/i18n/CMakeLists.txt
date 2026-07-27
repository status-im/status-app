cmake_minimum_required(VERSION 3.19)

project(status-app-i18n) # dummy project to silence warnings, TBD at the toplevel

find_package(QT 6.11 NAMES Qt6 REQUIRED COMPONENTS Core)
find_package(Qt6 6.11 REQUIRED COMPONENTS LinguistTools)

#qt6_standard_project_setup(I18N_TRANSLATED_LANGUAGES cs ko)

set(QT_NO_MISSING_CATALOG_LANGUAGE_WARNING ON)

file(GLOB_RECURSE
    COLLECTED_SOURCE_FILES
    ${CMAKE_SOURCE_DIR}/../*.qml
    ${CMAKE_SOURCE_DIR}/../*.cpp
    ${CMAKE_SOURCE_DIR}/../*.mm
)
list(FILTER COLLECTED_SOURCE_FILES EXCLUDE REGEX "${CMAKE_SOURCE_DIR}/../StatusQ/build/.*" )

qt6_add_lupdate(
    LUPDATE_TARGET update_application_translations # name of the cmake target
    OPTIONS -locations none -no-obsolete -source-language en # options passed to 'lupdate'
    TS_FILES
        ${CMAKE_SOURCE_DIR}/qml_base_en.ts #empty base file, for manual translations
        ${CMAKE_SOURCE_DIR}/qml_cs.ts
        ${CMAKE_SOURCE_DIR}/qml_ko.ts
        ${CMAKE_SOURCE_DIR}/qml_es.ts
    PLURALS_TS_FILE
        ${CMAKE_SOURCE_DIR}/qml_en.ts
    SOURCES ${COLLECTED_SOURCE_FILES}
)

qt6_add_lrelease(
    LRELEASE_TARGET compile_application_translations # name of the cmake target
    OPTIONS -removeidentical -compress -nounfinished # options passed to 'lrelease'
    TS_FILES
        ${CMAKE_SOURCE_DIR}/qml_en.ts
        ${CMAKE_SOURCE_DIR}/qml_cs.ts
        ${CMAKE_SOURCE_DIR}/qml_ko.ts
        ${CMAKE_SOURCE_DIR}/qml_es.ts
    QM_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}
    MERGE_QT_TRANSLATIONS
    QT_TRANSLATION_CATALOGS qtbase qtmultimedia qtwebengine qtdeclarative
)

# Ideally at the toplevel it could be done sth like this in one pass/target:
#qt6_add_translations(
#  TS_FILE_BASE qml_
#  SOURCES ${COLLECTED_SOURCE_FILES}
#  LUPDATE_TARGET update_application_translations
#  LUPDATE_OPTIONS "-locations none -no-obsolete"
#  LRELEASE_TARGET compile_application_translations
#  LRELEASE_OPTIONS "-removeidentical -compress -nounfinished"
#  QM_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/../../bin/i18n
#  MERGE_QT_TRANSLATIONS
#)
