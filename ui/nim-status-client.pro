QT += quick
QT += webchannel

# The following define makes your compiler emit warnings if you use
# any Qt feature that has been marked deprecated (the exact warnings
# depend on your compiler). Refer to the documentation for the
# deprecated API to know how to port your code away from it.
DEFINES += QT_DEPRECATED_WARNINGS

# You can also make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
# You can also select to disable deprecated APIs only up to a certain version of Qt.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

OTHER_FILES += $$files("$$PWD/*qmldir", true)
OTHER_FILES += $$files("$$PWD/*.qml", true)
OTHER_FILES += $$files("$$PWD/*.js", true)
OTHER_FILES += $$files("$$PWD/../src/*.nim", true)
OTHER_FILES += $$files("$$PWD/../monitoring/*.qml", true)

OTHER_FILES += $$files("$$PWD/../vendor/SortFilterProxyModel/*.cpp", true)
OTHER_FILES += $$files("$$PWD/../vendor/SortFilterProxyModel/*.h", true)

OTHER_FILES += $$files("$$PWD/../vendor/nimqml/src/*.nim", true)

OTHER_FILES += $$files("$$PWD/../Makefile")

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH = $$PWD/imports \
                  $$PWD/StatusQ \
                  $$PWD/StatusQ/src \
                  $$PWD/StatusQ/tests/qml \
                  $$PWD/app

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH = $$PWD/imports

RESOURCES += resources.qrc \
            StatusQ/src/assets/fonts/fonts.qrc \
            StatusQ/src/assets/img/img.qrc \
            StatusQ/src/assets/png/png.qrc \
            StatusQ/src/assets/png/png-desktop.qrc \
            StatusQ/src/assets/png/png-mobile.qrc \
            StatusQ/src/assets/twemoji/twemoji.qrc \
            StatusQ/src/assets/twemoji/twemoji-big.qrc \
            StatusQ/src/assets/twemoji/twemoji-svg.qrc \
            StatusQ/src/statusq.qrc
