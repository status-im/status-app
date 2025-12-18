TEMPLATE = app

QT += quick gui qml webview svg widgets multimedia

BUILD_VARIANT = $$(BUILD_VARIANT)
TARGET = Status
equals(BUILD_VARIANT, "pr"): TARGET = StatusPR
message("Building $$BUILD_VARIANT variant: TARGET = $$TARGET")

equals(QT_MAJOR_VERSION, 6) {
    message("qt 6 config!!")
    QT += core5compat core
}

SOURCES += \
        sources/main.cpp

# Add all status-desktop qrc files
RESOURCES += \
    $$PWD/../../ui/resources.qrc

QML_IMPORT_PATH += $$PWD/../../ui/imports \
                   $$PWD/../../ui/app \
                   $$PWD/../../ui/StatusQ/src

QMLPATHS += $$QML_IMPORT_PATH
LIB_PREFIX = $$(APP_VARIANT)

android {
    message("Configuring for android $${QT_ARCH}, $$(ANDROID_ABI)")

    ANDROID_VERSION_NAME = $$VERSION

    ANDROID_PACKAGE_SOURCE_DIR = $$PWD/../android/qt$$QT_MAJOR_VERSION

    LIBS += -L$$PWD/../lib/$$LIB_PREFIX -lnim_status_client
    ANDROID_EXTRA_LIBS += \
                        $$PWD/../lib/$$LIB_PREFIX/libssl_3.so \
                        $$PWD/../lib/$$LIB_PREFIX/libcrypto_3.so \
                        $$PWD/../lib/$$LIB_PREFIX/libnim_status_client.so \
                        $$PWD/../lib/$$LIB_PREFIX/libDOtherSide$$(LIB_SUFFIX)$$(LIB_EXT) \
                        $$PWD/../lib/$$LIB_PREFIX/libstatus.so \
                        $$PWD/../lib/$$LIB_PREFIX/libsds.so \
                        $$PWD/../lib/$$LIB_PREFIX/libStatusQ$$(LIB_SUFFIX)$$(LIB_EXT) \

    OTHER_FILES += \
        $$ANDROID_PACKAGE_SOURCE_DIR/src/app/status/mobile/SecureAndroidAuthentication.java
}

ios {
    CONFIG += add_ios_ffmpeg_libraries

    QMAKE_INFO_PLIST = $$PWD/../ios/Info.plist
    QMAKE_IOS_DEPLOYMENT_TARGET=16.0
    QMAKE_ASSET_CATALOGS += $$PWD/../ios/Images.xcassets
    QMAKE_IOS_LAUNCH_SCREEN = $$PWD/../ios/launch-image-universal.storyboard

    # Bundle identifier: pr -> app.status.mobile.pr, release -> app.status.mobile
    QMAKE_TARGET_BUNDLE_PREFIX = app.status
    QMAKE_BUNDLE = mobile
    equals(BUILD_VARIANT, "pr") {
        QMAKE_TARGET_BUNDLE_PREFIX = app.status.mobile
        QMAKE_BUNDLE = pr
    }

    LIBS += -L$$PWD/../lib/$$LIB_PREFIX -lnim_status_client -lDOtherSideStatic -lstatusq -lstatus -lsds -lssl_3 -lcrypto_3 -lqzxing -lresolv -lqrcodegen

    # --- iOS frameworks required by keychain_apple.mm ---
    LIBS += -framework LocalAuthentication \
            -framework Security \
            -framework UIKit \
            -framework Foundation
}
