TEMPLATE = app

QT += quick gui qml webview svg widgets multimedia

BUILD_VARIANT = $$(BUILD_VARIANT)
TARGET = Status
equals(BUILD_VARIANT, "pr"): TARGET = StatusPR
message("Building $$BUILD_VARIANT variant: TARGET = $$TARGET")

# Conditionally add NFC module only if keycard is enabled
contains(DEFINES, FLAG_KEYCARD_ENABLED) {
    message("Building with Keycard/NFC support enabled")
    QT += nfc
} else {
    message("Building WITHOUT Keycard/NFC support (default for development)")
}

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

    QMAKE_LFLAGS += -Wl,-z,max-page-size=16384
    QMAKE_LFLAGS_SHLIB += -Wl,-z,max-page-size=16384

    ANDROID_VERSION_NAME = $$VERSION

    ANDROID_PACKAGE_SOURCE_DIR = $$PWD/../android/qt$$QT_MAJOR_VERSION

    LIBS += -L$$PWD/../lib/$$LIB_PREFIX -lnim_status_client
    ANDROID_EXTRA_LIBS += \
                        $$PWD/../lib/$$LIB_PREFIX/libssl_3.so \
                        $$PWD/../lib/$$LIB_PREFIX/libcrypto_3.so \
                        $$PWD/../lib/$$LIB_PREFIX/libnim_status_client.so \
                        $$PWD/../lib/$$LIB_PREFIX/libDOtherSide$$(LIB_SUFFIX)$$(LIB_EXT) \
                        $$PWD/../lib/$$LIB_PREFIX/libstatus_stub.so \
                        $$PWD/../lib/$$LIB_PREFIX/libStatusQ$$(LIB_SUFFIX)$$(LIB_EXT) \
                        $$PWD/../lib/$$LIB_PREFIX/libMobileWebView$$(LIB_SUFFIX)$$(LIB_EXT)
    contains(DEFINES, FLAG_KEYCARD_ENABLED) {
        ANDROID_EXTRA_LIBS += $$PWD/../lib/$$LIB_PREFIX/libstatus-keycard-qt.so
    }

    OTHER_FILES += \
        $$ANDROID_PACKAGE_SOURCE_DIR/src/app/status/mobile/SecureAndroidAuthentication.java
}

ios {
    CONFIG += add_ios_ffmpeg_libraries

    QMAKE_CXXFLAGS += -Wno-implicit-function-declaration
    QMAKE_CFLAGS += -Wno-implicit-function-declaration

    QMAKE_INFO_PLIST = $$OUT_PWD/Info.plist
    QMAKE_IOS_DEPLOYMENT_TARGET=26.0

    QMAKE_ASSET_CATALOGS += $$PWD/../ios/Images.xcassets
    QMAKE_IOS_LAUNCH_SCREEN = $$PWD/../ios/launch-image-universal.storyboard

    # Bundle identifier: pr -> app.status.mobile.pr, release -> app.status.mobile
    QMAKE_TARGET_BUNDLE_PREFIX = app.status
    QMAKE_BUNDLE = mobile
    equals(BUILD_VARIANT, "pr") {
        QMAKE_TARGET_BUNDLE_PREFIX = app.status.mobile
        QMAKE_BUNDLE = pr
    }

    # --- Code signing configuration ---
    !contains(CONFIG, fastlane) {
        QMAKE_DEVELOPMENT_TEAM = 8B5X2M6H2Y

        MY_CODE_SIGN_IDENTITY.name = CODE_SIGN_IDENTITY
        MY_CODE_SIGN_IDENTITY.value = "Apple Development"
        QMAKE_MAC_XCODE_SETTINGS += MY_CODE_SIGN_IDENTITY

        MY_CODE_SIGN_STYLE.name = CODE_SIGN_STYLE
        MY_CODE_SIGN_STYLE.value = Automatic
        QMAKE_MAC_XCODE_SETTINGS += MY_CODE_SIGN_STYLE
    }

    # --- iOS frameworks required by keychain_apple.mm ---
    LIBS += -framework LocalAuthentication \
            -framework Security \
            -framework CoreMotion \
            -framework UIKit \
            -framework PhotosUI \
            -framework Foundation \
            -framework UserNotifications

    # Base libraries (always included)
    LIBS += -L$$PWD/../lib/$$LIB_PREFIX -lnim_status_client -lDOtherSideStatic -lstatusq -lMobileWebView -lstatus -lsds -lssl_3 -lcrypto_3 -lSCodes -lZXing -lresolv -lqrcodegen

    contains(DEFINES, FLAG_KEYCARD_ENABLED) {
        # Use entitlements with NFC support (requires paid Apple Developer account)
        MY_ENTITLEMENTS.name = CODE_SIGN_ENTITLEMENTS
        MY_ENTITLEMENTS.value = $$PWD/../ios/Status.entitlements
        QMAKE_MAC_XCODE_SETTINGS += MY_ENTITLEMENTS

        LIBS += -lstatus-keycard-qt -framework CoreNFC

    } else {
        # Use entitlements without NFC (allows building with free Apple account)
        MY_ENTITLEMENTS.name = CODE_SIGN_ENTITLEMENTS
        MY_ENTITLEMENTS.value = $$PWD/../ios/Status-NoKeycard.entitlements
        QMAKE_MAC_XCODE_SETTINGS += MY_ENTITLEMENTS
    }
}
