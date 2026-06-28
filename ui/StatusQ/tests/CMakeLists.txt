project(TestStatusQ LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)

find_package(Qt${QT_VERSION_MAJOR} COMPONENTS
        QuickTest Qml Quick WebEngineQuick REQUIRED)

##############
# Test Library
##############

add_library(StatusQTestLib
    src/TestHelpers/MonitorQtOutput.cpp
    src/TestHelpers/MonitorQtOutput.h
    src/TestHelpers/modelaccessobserverproxy.cpp
    src/TestHelpers/modelaccessobserverproxy.h
)

target_link_libraries(StatusQTestLib PUBLIC Qt::Core Qt::Quick Qt::QuickTest Qt::Test StatusQ)
target_include_directories(StatusQTestLib PUBLIC src)

enable_testing()

###########
# QML Tests
###########

file(GLOB_RECURSE TEST_QML_FILES "*.qml")
add_executable(StatusQQmlTests main.cpp "${TEST_QML_FILES}")

target_compile_definitions(StatusQQmlTests PRIVATE
    STATUSQ_MODULE_IMPORT_PATH="${STATUSQ_MODULE_IMPORT_PATH}"
    # no need to copy around qml test files for shadow builds - just set the respective define
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)
target_link_libraries(StatusQQmlTests PRIVATE Qt::QuickTest Qt::Qml Qt::Quick
    Qt::WebEngineQuick StatusQ StatusQTestLib
)
add_test(NAME StatusQQmlTests WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMAND StatusQQmlTests -input "${CMAKE_CURRENT_SOURCE_DIR}"
)

###########
# C++ Tests
###########

add_executable(MarkdownParserTest src/tst_markdownparser.cpp)
target_link_libraries(MarkdownParserTest PRIVATE Qt::Test StatusQ)
add_test(NAME MarkdownParserTest COMMAND MarkdownParserTest)

add_executable(MarkdownHtmlTest src/tst_markdownhtml.cpp)
target_link_libraries(MarkdownHtmlTest PRIVATE Qt::Test StatusQ)
add_test(NAME MarkdownHtmlTest COMMAND MarkdownHtmlTest)
