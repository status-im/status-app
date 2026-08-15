# Storybook-only mock backend: generated models and the mock image provider.
# Dev-only, never linked into the shipping app.
add_library(StorybookMocks STATIC
    generatedlistmodel.h generatedlistmodel.cpp
    mockimageprovider.h mockimageprovider.cpp
    walletmockprofile.h walletmockprofile.cpp
    registration.h registration.cpp
)

set_target_properties(StorybookMocks PROPERTIES AUTOMOC ON)

target_include_directories(StorybookMocks PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(StorybookMocks PUBLIC Qt::Core Qt::Gui Qt::Qml Qt::Quick)
