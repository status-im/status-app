import QtQuick
import QtQuick.Controls

import utils
import shared.panels
import shared.popups
import shared.stores

import mainui
import AppLayouts.stores as AppStores
import AppLayouts.Profile.stores

import AppLayouts.Onboarding
import AppLayouts.Onboarding.enums
import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.pages

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Platform

import MobileUI

Window {
    id: applicationWindow

    property bool appIsReady: false
    property double _lastShakeShareMs: 0

    readonly property AppStores.FeatureFlagsStore featureFlagsStore: AppStores.FeatureFlagsStore {
        readonly property var featureFlags: typeof featureFlagsRootContextProperty !== undefined ? featureFlagsRootContextProperty : null

        connectorEnabled: featureFlags ? featureFlags.connectorEnabled : false
        dappsEnabled: featureFlags ? featureFlags.dappsEnabled : false
        browserEnabled: featureFlags ? featureFlags.browserEnabled : false
        swapEnabled: featureFlags ? featureFlags.swapEnabled : false
        sendViaPersonalChatEnabled: featureFlags ? featureFlags.sendViaPersonalChatEnabled : false
        paymentRequestEnabled: featureFlags ? featureFlags.paymentRequestEnabled : false
        simpleSendEnabled: featureFlags ? featureFlags.simpleSendEnabled : false
        keycardEnabled: featureFlags ? featureFlags.keycardEnabled : false
        marketEnabled: featureFlags ? featureFlags.marketEnabled : false
        homePageEnabled: featureFlags ? featureFlags.homePageEnabled : false
        localBackupEnabled: featureFlags ? featureFlags.localBackupEnabled : false
        privacyModeFeatureEnabled: featureFlags ? featureFlags.privacyModeFeatureEnabled : false
        buyEnabled: featureFlags ? featureFlags.buyEnabled : false
    }

    readonly property MetricsStore metricsStore: MetricsStore {}
    readonly property UtilsStore utilsStore: UtilsStore {}
    readonly property LanguageStore languageStore: LanguageStore {}
    readonly property bool appThemeDark: Theme.isDarkTheme
    readonly property bool portraitLayout: height > width
    property bool biometricFlowPending: false
    
    // Store the native SafeArea bottom margin (e.g., iOS home indicator)
    // Must be set in Component.onCompleted before any additionalMargins are applied
    property real nativeSafeAreaBottom: 0
    
    // Use native Android keyboard tracking via WindowInsets API
    // This bypasses Qt's unreliable inputMethod and works with any windowSoftInputMode
    // Both Android and iOS keyboard heights are in physical pixels and need devicePixelRatio conversion
    // iOS: Native code converts (nativePoints × nativeScale) to pixels for Qt to convert to its logical points
    // Android: WindowInsets provides pixels directly
    property real keyboardHeight: SQUtils.Utils.isAndroid ? SystemUtils.androidKeyboardHeight / Screen.devicePixelRatio :
                                    SQUtils.Utils.isIOS ? SystemUtils.iosKeyboardHeight / Screen.devicePixelRatio :
                                    Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0
    
    // Calculate additional margin so that total = max(nativeSafeAreaBottom, keyboardHeight)
    // When keyboard shows, we want the keyboard height to replace the native safe area, not add to it
    // The Behavior animation ensures smooth transitions even during rapid keyboard show/hide sequences
    property real additionalBottomMargin: Math.max(0, keyboardHeight - nativeSafeAreaBottom)

    SafeArea.additionalMargins.bottom: additionalBottomMargin

    Behavior on additionalBottomMargin {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    objectName: "mainWindow"
    color: Theme.palette.background
    title: {
        // Set application settings
        Qt.application.name = "Status Desktop"
        Qt.application.displayName = d.macOSWindowed ? "" : qsTr("Status Desktop")
        Qt.application.organization = "Status"
        Qt.application.domain = "status.im"
        Qt.application.version = aboutModule.getCurrentVersion()
        return Qt.application.displayName
    }
    visible: false

    flags: Qt.platform.os === SQUtils.Utils.windows ? Qt.Window // extending the content in title is buggy on Windows
              : Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint

    onAppThemeDarkChanged: {
        // Set Android status bar icons to dark (black) if on Android and background is light
        if (SQUtils.Utils.isAndroid) {
            SystemUtils.setAndroidStatusBarIconColor(applicationWindow.appThemeDark)
        }
    }

    function contentLoaded() {
        if (SQUtils.Utils.isAndroid) {
            SystemUtils.setAndroidSplashScreenReady()
        }
        applicationWindow.visible = true
    }

    function restoreAppState() {
        let geometry = localAppSettings.geometry;
        let visibility = localAppSettings.visibility;

        if (visibility !== Window.Windowed &&
            visibility !== Window.Maximized &&
            visibility !== Window.FullScreen) {
            visibility = Window.Windowed;
        }

        if (geometry === undefined ||
            // If the monitor setup of the user changed, it's possible that the old geometry now falls out of the monitor range
            // In this case, we reset to the basic geometry
            geometry.x > Screen.desktopAvailableWidth ||
            geometry.y > Screen.desktopAvailableHeight ||
            geometry.width > Screen.desktopAvailableWidth ||
            geometry.height > Screen.desktopAvailableHeight ||
            geometry.x < 0 || geometry.y < 0)
        {
            let screen = Qt.application.screens[0];

            geometry = Qt.rect(0,
                               0,
                               Math.min(Screen.desktopAvailableWidth - 125, 1400),
                               Math.min(Screen.desktopAvailableHeight - 125, 840));
            geometry.x = (screen.width - geometry.width) / 2;
            geometry.y = (screen.height - geometry.height) / 2;
        }

        applicationWindow.visibility = visibility;
        if (visibility === Window.Windowed) {
            applicationWindow.x = geometry.x;
            applicationWindow.y = geometry.y;
            applicationWindow.width = Math.max(geometry.width, Theme.portraitBreakpoint.width)
            applicationWindow.height = Math.max(geometry.height, Theme.portraitBreakpoint.height)
        }
    }

    function storeAppState() {
        if (!applicationWindow.appIsReady)
            return;

        localAppSettings.visibility = applicationWindow.visibility;
        if (applicationWindow.visibility === Window.Windowed) {
            localAppSettings.geometry = Qt.rect(applicationWindow.x, applicationWindow.y,
                                                applicationWindow.width, applicationWindow.height);
        }
    }

    onXChanged: Qt.callLater(storeAppState)
    onYChanged: Qt.callLater(storeAppState)
    onPortraitLayoutChanged: {
        // Android looses status bar icon color when switching orientation
        if (SQUtils.Utils.isAndroid) {
            SystemUtils.setAndroidStatusBarIconColor(applicationWindow.appThemeDark)
        }
    }

    onWidthChanged: {
        Qt.callLater(storeAppState)
    }
    onHeightChanged: Qt.callLater(storeAppState)

    QtObject {
        id: d

        property var mockedKeycardControllerWindow
        function runMockedKeycardControllerWindow() {
            if (localAppSettings.displayMockedKeycardWindow()) {
                if (!!d.mockedKeycardControllerWindow) {
                    d.mockedKeycardControllerWindow.close()
                }

                console.info("running mocked keycard lib controller window")
                var c = Qt.createComponent("qrc:/imports/shared/panels/MockedKeycardLibControllerWindow.qml");
                if (c.status === Component.Ready) {
                    d.mockedKeycardControllerWindow = c.createObject(applicationWindow, {
                                                                         "relatedModule": mainModule
                                                                     })
                    if (d.mockedKeycardControllerWindow) {
                        d.mockedKeycardControllerWindow.show()
                        d.mockedKeycardControllerWindow.requestActivate()
                    }
                }
            }
        }

        readonly property bool macOSWindowed: Qt.platform.os === SQUtils.Utils.mac &&
                                              applicationWindow.visibility !== Window.FullScreen

        function restoreWindowState() {
            switch(lastNonMinVisibility) {
            case Window.Windowed:
                applicationWindow.showNormal()
                break
            case Window.Maximized:
                applicationWindow.showMaximized()
                break
            case Window.FullScreen:
                applicationWindow.showFullScreen()
                break
            }
        }

        property int lastNonMinVisibility

        property bool showSkippedBiometricFlow: false
    }

    Binding {
        target: Qt.application
        property: "displayName"
        value: d.macOSWindowed
               ? ""
               : qsTr("Status Desktop")
    }

    // Only set minimum width/height for desktop apps
    Binding {
        target: applicationWindow
        property: "minimumWidth"
        when: !SQUtils.Utils.isMobile
        value: Theme.portraitBreakpoint.width
    }
    Binding {
        target: applicationWindow
        property: "minimumHeight"
        when: !SQUtils.Utils.isMobile
        value: Theme.portraitBreakpoint.height
    }

    Action {
        shortcut: StandardKey.FullScreen
        onTriggered: {
            if (applicationWindow.visibility === Window.FullScreen) {
                applicationWindow.showNormal();
            } else {
                applicationWindow.showFullScreen();
            }
        }
    }

    Action {
        shortcut: "Ctrl+M"
        onTriggered: applicationWindow.showMinimized()
    }

    Action {
        shortcut: StandardKey.Quit
        onTriggered: {
            Qt.exit(0)
        }
    }

    //TODO remove direct backend access
    Connections {
        id: windowsOsNotificationsConnection
        enabled: Qt.platform.os === SQUtils.Utils.windows
        target: Qt.platform.os === SQUtils.Utils.windows && typeof mainModule !== "undefined" ? mainModule : null
        function onDisplayWindowsOsNotification(title, message) {
            systemTray.showMessage(title, message)
        }
    }

    function moveToAppMain() {
        Global.appIsReady = true

        loader.sourceComponent = app

        d.runMockedKeycardControllerWindow()
    }

    /* When the app is closed via CMD+Q or via tray icon, it should be closed (not minimized)
       no matter if minimize on close setting is enabled. In pure qml it's not possible to
       distinguish those close variants. Moreover CMD+Q is not handled via Shortcut nor Action.
       However on QEvent level close events generated by CMD+Q or via try icon are marked as spontaneous
       (clicking close icon on menu bar is not marked as spontaneous). It allows to distinguish those
       situations and handle as desired.
    */
    Connections {
        target: SystemUtils
        enabled: SQUtils.Utils.mac

        function onQuit(spontaneous) {
            if (spontaneous)
                Qt.exit(0)
        }

        function onShakeDetected() {
            try {
                SystemUtils.debugLog("[iOS Shake] QML onShakeDetected fired")

                if (Qt.platform.os !== "ios") {
                    SystemUtils.debugLog("[iOS Shake] not ios, ignoring: " + Qt.platform.os)
                    return
                }

                const nowMs = Date.now()
                if (nowMs - applicationWindow._lastShakeShareMs < 3000) {
                    SystemUtils.debugLog("[iOS Shake] cooldown active")
                    return
                }
                applicationWindow._lastShakeShareMs = nowMs

                if (typeof globalUtils === "undefined" || !globalUtils) {
                    SystemUtils.debugLog("[iOS Shake] globalUtils not available")
                    return
                }

                const json = globalUtils.collectLogFilesJson()
                SystemUtils.debugLog("[iOS Shake] collectLogFilesJson len: " + (json ? json.length : 0))

                let paths = []
                try {
                    paths = JSON.parse(json)
                } catch (e) {
                    SystemUtils.debugLog("[iOS Shake] JSON.parse failed: " + e)
                    return
                }
                if (!paths || paths.length === 0) {
                    SystemUtils.debugLog("[iOS Shake] no log paths found")
                    return
                }

                SystemUtils.debugLog("[iOS Share] requesting share for " + paths.length + " files. First: " + paths[0])

                // Prefer the QStringList overload to avoid QVariantList conversion quirks on iOS.
                // Also keep this inside a try/catch (callLater would hide TypeErrors).
                SystemUtils.iosSharePaths(paths)
            } catch (e) {
                SystemUtils.debugLog("[iOS Shake] handler threw: " + e)
            }
        }
    }

    Connections {
        target: applicationWindow
        function onVisibilityChanged(visibility) {
            if (applicationWindow.visibility !== Window.Minimized
                        && applicationWindow.visibility !== Window.Hidden) {
                d.lastNonMinVisibility = applicationWindow.visibility
            }
        }
        function onClosing(close) {
            // In case of android, we need to handle moveTaskToBackground explicitly
            if (SQUtils.Utils.isAndroid) {
                close.accepted = false
                SystemUtils.androidMinimizeToBackground()
            // In case not logged in or loading, quit app
            } else if (loader.sourceComponent != app) {
                close.accepted = true
            }
            // In case user has set to close should quit app
            else if (localAccountSensitiveSettings.quitOnClose) {
                close.accepted = true
            }
            else {
                // The app is already minimized. The user really wants to quit the app
                // The user really wants to quit the app
                if (applicationWindow.visibility === Window.Minimized) {
                    close.accepted = true
                    return
                }

                close.accepted = false
                /* In case of mac in fullscreen mode, hiding the window leads to black screen.
                Hence we exit Fullscreen on system close and then the user can perform an actual
                hide of the app */
                if(applicationWindow.visibility === Window.FullScreen &&
                        Qt.platform.os === SQUtils.Utils.mac) {
                    applicationWindow.showNormal()
                    return
                }
                applicationWindow.showMinimized()
            }
        }
    }

    //TODO remove direct backend access
    Connections {
        target: singleInstance

        function onSecondInstanceDetected() {
            console.log("User attempted to run the second instance of the application")
            // activating this instance to give user visual feedback
            makeStatusAppActive()
        }
    }

    // Clear additional SafeArea's margins when regular margins are intialized. Doing cleanup
    // this way prevents binding loop between margins and additional margins.
    Connections {
        id: safeMarginsCleanupConnections

        enabled: false
        target: applicationWindow.contentItem.SafeArea

        function onMarginsChanged() {
            const safeArea = applicationWindow.contentItem.SafeArea

            safeArea.additionalMargins.top = 0
            safeArea.additionalMargins.bottom = Qt.binding(() => applicationWindow.additionalBottomMargin)
            safeArea.additionalMargins.left = 0
            safeArea.additionalMargins.right = 0

            safeMarginsCleanupConnections.enabled = false
        }
    }

    Component.onCompleted: {
        
        console.info(">>> %1 %2 started, using Qt version %3".arg(Qt.application.name).arg(Qt.application.version).arg(SystemUtils.qtRuntimeVersion()))

        if (languageStore.currentLanguage === "") { // if we haven't configured the language yet...
            // ...and we have a translation for it
            if (languageStore.availableLanguages.includes(Qt.uiLanguage)) {
                // set the language to the user's OS default
                languageStore.changeLanguage(Qt.uiLanguage, true /*shouldRetranslate*/)
            }
        } else {
            // set the configured language
            languageStore.changeLanguage(languageStore.currentLanguage, true /*shouldRetranslate*/)
        }

        // Set Android status bar icons to dark (black) if on Android and background is light
        if (SQUtils.Utils.isAndroid) {
            SystemUtils.setAndroidStatusBarIconColor(Theme.isDarkTheme)
        }

        restoreAppState()

        Global.openMetricsEnablePopupRequested.connect(openMetricsEnablePopup)
        Global.addCentralizedMetricIfEnabled.connect(metricsStore.addCentralizedMetricIfEnabled)

        nativeSafeAreaBottom = mobileUI.safeAreaBottom + mobileUI.navbarHeight

        // SafeArea margins works well out of the box when app uses regular qml Window as a top level
        // window. When custom window derived from QQuickWindow is used, SafeArea's margins are all 0
        // till first screen rotation or virtual keyboard usage (Android 15, 16, not and issue on Android 14).
        // This workaround initializes margins by adding addtionalMargins using values read directly from
        // via native API. When the margins are initialized, binding is cleared.
        const safeArea = applicationWindow.contentItem.SafeArea

        if (safeArea.margins.bottom === 0 && mobileUI.safeAreaBottom + mobileUI.navbarHeight > 0)
            safeArea.additionalMargins.bottom = Qt.binding(() => mobileUI.safeAreaBottom + mobileUI.navbarHeight + applicationWindow.additionalBottomMargin)

        if (safeArea.margins.top === 0 && mobileUI.safeAreaTop > 0)
            safeArea.additionalMargins.top = Qt.binding(() => mobileUI.safeAreaTop)

        if (safeArea.margins.right === 0 && mobileUI.safeAreaRight > 0)
            safeArea.additionalMargins.right = Qt.binding(() => mobileUI.safeAreaRight)

        if (safeArea.margins.left === 0 && mobileUI.safeAreaLeft > 0)
            safeArea.additionalMargins.left = Qt.binding(() => mobileUI.safeAreaLeft)

        safeMarginsCleanupConnections.enabled = true
    }

    signal navigateTo(string path)

    function makeStatusAppActive() {
        d.restoreWindowState()
        applicationWindow.raise()
        applicationWindow.requestActivate()
    }

    function openMetricsEnablePopup(placement, cb = null) {
        metricsPopupLoader.active = true
        metricsPopupLoader.item.visible = true
        metricsPopupLoader.item.placement = placement
        if (cb)
            cb(metricsPopupLoader.item)
        if(!localAppSettings.metricsPopupSeen) {
            localAppSettings.metricsPopupSeen = true
        }
    }

    StatusTrayIcon {
        id: systemTray
        objectName: "systemTray"
        showRedDot: typeof mainModule !== "undefined" ? mainModule.notificationAvailable : false
        onActivateApp: {
            applicationWindow.makeStatusAppActive()
        }
    }

    Loader {
        id: loader

        anchors.fill: parent
        anchors.topMargin: Qt.platform.os === SQUtils.Utils.mac ? 0 : parent.SafeArea.margins.top 
        anchors.bottomMargin: parent.SafeArea.margins.bottom
        anchors.leftMargin: parent.SafeArea.margins.left
        anchors.rightMargin: parent.SafeArea.margins.right
        opacity: active ? 1.0 : 0.0
        visible: (opacity > 0.0001)
        Behavior on opacity { NumberAnimation { duration: 120 }}
        /* only unload splash screen once appmain is loaded else we see
        an empty screen for a sec until it is loaded */
        onLoaded: {
            startupOnboardingLoader.active = false
            if (item && item.objectName === "appMain" && d.showSkippedBiometricFlow) {
                // IN case of Login via syncing, request to show Biometrics Page after onboarding
                item.showEnableBiometricsFlow()
            }
        }
    }

    Component {
        id: app
        AppMain {
            objectName: "appMain"

            utilsStore: applicationWindow.utilsStore
            featureFlagsStore: applicationWindow.featureFlagsStore
            languageStore: applicationWindow.languageStore

            visible: !startupOnboardingLoader.active
            isCentralizedMetricsEnabled: metricsStore.isCentralizedMetricsEnabled

            keychain: appKeychain
            Component.onCompleted: {
                applicationWindow.contentLoaded()
            }
        }
    }

    Component {
        id: splashScreenV2
        DidYouKnowSplashScreen {
            objectName: "splashScreenV2"
            readonly property bool backAvailableHint: false
            property bool runningProgressAnimation
            messagesEnabled: true
            infiniteLoading: runningProgressAnimation
        }
    }

    Loader {
        id: startupOnboardingLoader

        anchors.fill: parent
        anchors.topMargin: Qt.platform.os === SQUtils.Utils.mac ? 0 : parent.SafeArea.margins.top
        anchors.leftMargin: parent.SafeArea.margins.left
        anchors.rightMargin: parent.SafeArea.margins.right
        anchors.bottomMargin: parent.SafeArea.margins.bottom

        sourceComponent: onboardingV2
    }

    Keychain {
        service: "StatusDesktop"

        id: appKeychain

        // These signal handlers keep the compatibility with the old keychain approach,
        // which is used by `keycard_popup` (any auth inside the app) and the old onboarding.
        // NOTE: this hack won't work if changes are made with another Keychain instance.
        onCredentialSaved: function (account) {
            applicationWindow.biometricFlowPending = false
            // load appMain if not already after biometric flow is complete
            if(loader.sourceComponent !== app && applicationWindow.appIsReady) {
                moveToAppMain()
            }
            localAccountSettings.storeToKeychainValue = Constants.keychain.storedValue.store
        }
        onCredentialDeleted: (account) => localAccountSettings.storeToKeychainValue = Constants.keychain.storedValue.never
        onGetCredentialRequestCompleted: function(status, secret) {
            // Handle Failure to safely move on to appMain
            if (status !== Keychain.StatusSuccess &&
                    loader.sourceComponent !== app &&
                    applicationWindow.appIsReady) {
                moveToAppMain()
            }
        }
    }

    Component {
        id: onboardingV2

        OnboardingLayout {
            id: onboardingLayout
            objectName: "startupOnboardingLayout"

            isKeycardEnabled: featureFlagsStore.keycardEnabled
            networkChecksEnabled: true

            onboardingStore: OnboardingStore {
                id: onboardingStore

                onAppLoaded: {
                    applicationWindow.appIsReady = true
                    applicationWindow.storeAppState()

                    // only load appMain if biometrics flow is complete
                    if(!applicationWindow.biometricFlowPending) {
                        moveToAppMain()
                    }
                }
                onAccountLoginError: function (error, wrongPassword) {
                    onboardingLayout.unwindToLoginScreen() // error handled internally
                }
                onSaveBiometricsRequested: (account, credential) => {
                    applicationWindow.biometricFlowPending = true
                    appKeychain.saveCredential(account, credential)
                }
                onDeleteBiometricsRequested: (account) => {
                    appKeychain.deleteCredential(account)
                }
            }

            currentLanguage: languageStore.currentLanguage
            availableLanguages: languageStore.availableLanguages
            onChangeLanguageRequested: (newLanguageCode) => languageStore.changeLanguage(newLanguageCode, true /*shouldRetranslate*/)

            keychain: appKeychain

            privacyModeFeatureEnabled: applicationWindow.featureFlagsStore.privacyModeFeatureEnabled

            onFinished: function(flow, data) {
                const error = onboardingStore.finishOnboardingFlow(flow, data)

                if (error !== "") {
                    // We should never be here since everything should be validated already
                    console.error("!!! ONBOARDING FINISHED WITH ERROR:", error)
                    return
                }

                // We use a custom handler for LoginWithLostKeycardSeedphrase flow.
                // At the moment of implementation, this was the simplest move to make it work in the given code.
                // Ideally, ConvertKeycardAccountPage should be created inside the OnboardingLayout and not here,
                // but this would require more changes and eventually give more inconsistencies.
                if (flow === Onboarding.OnboardingFlow.LoginWithLostKeycardSeedphrase) {
                    stack.push(convertingKeycardAccountPage)
                } else {
                    stack.push(splashScreenV2, {runningProgressAnimation: true})
                }
            }

            onLoginRequested: function (keyUid, method, data) {
                stack.push(splashScreenV2, { runningProgressAnimation: true }, StackView.Immediate) // we unwind on error
                onboardingStore.loginRequested(keyUid, method, data)
            }

            onShareUsageDataRequested: function(enabled) {
                applicationWindow.metricsStore.toggleCentralizedMetrics(enabled)
                if (enabled) {
                    Global.addCentralizedMetricIfEnabled("usage_data_shared", {placement: Constants.metricsEnablePlacement.onboarding})
                }
            }
            onCurrentPageNameChanged: {
                if (currentPageName !== "") {
                    Global.addCentralizedMetricIfEnabled("navigation", {viewId: currentPageName})
                }
            }

            onSkippedBiometricFlow: () => {
                                        d.showSkippedBiometricFlow = true
                                    }

            Component.onCompleted: {
                applicationWindow.contentLoaded()
            }

            Component {
                id: convertingKeycardAccountPage

                ConvertKeycardAccountPage {
                    convertKeycardAccountState: onboardingStore.convertKeycardAccountState
                    onRestartRequested: {
                        SystemUtils.restartApplication()
                    }
                    onBackToLoginRequested: {
                        onboardingLayout.unwindToLoginScreen()
                    }
                }
            }
        }
    }

    Loader {
        id: metricsPopupLoader
        active: false
        sourceComponent: MetricsEnablePopup {
            visible: true
            onClosed: metricsPopupLoader.active = false
            onSetMetricsEnabledRequested: {
                applicationWindow.metricsStore.toggleCentralizedMetrics(enabled)
                if (enabled) {
                    Global.addCentralizedMetricIfEnabled("usage_data_shared", {placement: metricsPopupLoader.item.placement})
                }
            }
        }
    }

    Loader {
        id: macOSSafeAreaLoader
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        height: active ? parent.SafeArea.margins.top : 0
        active: Qt.platform.os === SQUtils.Utils.mac && applicationWindow.visibility !== Window.FullScreen
        sourceComponent: macHeaderComponent
    }

    Component {
        id: macHeaderComponent
        MouseArea {
            id: headerMouseArea
            enabled: d.macOSWindowed
            propagateComposedEvents: true
            onPressed: {
                applicationWindow.startSystemMove()
                mouse.accepted = false
            }
        }
    }

    MobileUI {
        id: mobileUI
    }
}
