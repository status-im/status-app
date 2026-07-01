import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.panels
import shared.popups
import shared.stores

import mainui
import mainui.sectionLoaders
import AppLayouts.stores as AppStores
import AppLayouts.Profile.stores

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Backpressure
import StatusQ.Platform
import StatusQ.Popups.Dialog

import MobileUI

Window {
    id: applicationWindow

    Theme.style: Application.styleHints.colorScheme === Qt.ColorScheme.Dark
                 ? Theme.Style.Dark : Theme.Style.Light

    // Provided by Nim before `main.qml` starts (see AppController.initializeQmlContext()).
    readonly property bool skipOnboarding: typeof skipOnboardingContextProperty !== "undefined"
                                       ? skipOnboardingContextProperty
                                       : false

    property bool appIsReady: false

    readonly property AppStores.FeatureFlagsStore featureFlagsStore: AppStores.FeatureFlagsStore {
        readonly property var featureFlags: typeof featureFlagsRootContextProperty !== undefined ? featureFlagsRootContextProperty : null

        connectorEnabled: featureFlags ? featureFlags.connectorEnabled : false
        dappsEnabled: featureFlags ? featureFlags.dappsEnabled : false
        browserEnabled: featureFlags ? featureFlags.browserEnabled : false
        swapEnabled: featureFlags ? featureFlags.swapEnabled : false
        sendViaPersonalChatEnabled: featureFlags ? featureFlags.sendViaPersonalChatEnabled : false
        paymentRequestEnabled: featureFlags ? featureFlags.paymentRequestEnabled : false
        keycardEnabled: featureFlags ? featureFlags.keycardEnabled : false
        marketEnabled: featureFlags ? featureFlags.marketEnabled : false
        homePageEnabled: featureFlags ? featureFlags.homePageEnabled : false
        localBackupEnabled: featureFlags ? featureFlags.localBackupEnabled : false
        privacyModeFeatureEnabled: featureFlags ? featureFlags.privacyModeFeatureEnabled : false
        buyEnabled: featureFlags ? featureFlags.buyEnabled : false
    }

    readonly property UtilsStore utilsStore: UtilsStore {}
    readonly property LanguageStore languageStore: LanguageStore {}
    readonly property bool appThemeDark: Theme.style === Theme.Style.Dark
    readonly property KeycardStateStore keycardStateStore: KeycardStateStore {}
    readonly property bool portraitLayout: height > width
    readonly property bool userLoggedIn: loader.item !== null
    property bool biometricFlowPending: false

    // Use native Android keyboard tracking via WindowInsets API
    // This bypasses Qt's unreliable inputMethod and works with any windowSoftInputMode
    // Both Android and iOS keyboard heights are in physical pixels and need devicePixelRatio conversion
    // iOS: Native code converts (nativePoints × nativeScale) to pixels for Qt to convert to its logical points
    // Android: WindowInsets provides pixels directly
    readonly property real keyboardHeight: SQUtils.Utils.isAndroid ? SystemUtils.androidKeyboardHeight / Screen.devicePixelRatio :
                                                                     SQUtils.Utils.isIOS ? SystemUtils.iosKeyboardHeight / Screen.devicePixelRatio :
                                                                                           Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height : 0

    // Calculate additional margin so that total = max(SafeArea.margins.bottom, keyboardHeight)
    // When keyboard shows, we want the keyboard height to replace the native safe area, not add to it
    // The Behavior animation ensures smooth transitions even during rapid keyboard show/hide sequences
    property real additionalBottomMargin: Math.max(0, keyboardHeight - SafeArea.margins.bottom)

    Overlay.overlay.SafeArea.additionalMargins.bottom: additionalBottomMargin

    // On Android 15 taking a screenshot and invoking sharing popup triggers full-screen mode. It's not restored back
    // when exiting sharing popup. The change is not reflected in visibility property, so there is no direct way to detect it.
    // The workaround here tracks safe area margins to detect full screen mode to restore to maximized mode immediately.
    readonly property int saBottom: SafeArea.margins.bottom
    readonly property int saLeft: SafeArea.margins.left
    readonly property int saRight: SafeArea.margins.right

    onSaBottomChanged: if (SQUtils.Utils.isAndroid && saBottom === 0) applicationWindow.showMaximized()
    onSaLeftChanged: if (SQUtils.Utils.isAndroid && saLeft === 0) applicationWindow.showMaximized()
    onSaRightChanged: if (SQUtils.Utils.isAndroid && saRight === 0) applicationWindow.showMaximized()
    // end of screenshot full-screen bug workaround

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

    flags: Qt.platform.os === SQUtils.Utils.windows ? Qt.Window // extending the content in title is buggy on Windows
              : Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint

    onAppThemeDarkChanged: {
        // Set Android status bar icons to dark (black) if on Android and background is light
        if (SQUtils.Utils.isAndroid) {
            SystemUtils.setAndroidStatusBarIconColor(applicationWindow.appThemeDark)
        }
    }

    function contentLoaded() {
        if (SQUtils.Utils.isAndroid && !d.splashDismissed) {
            d.splashDismissed = true
            SystemUtils.setMainWindowReady()
        }
    }

    function restoreAppState() {
        if (SQUtils.Utils.isMobile && applicationWindow.visibility !== Window.Windowed) {
            // just correct visibility on mobile
            applicationWindow.visibility = Window.Maximized
            return
        }

        let geometry = localAppSettings.geometry;
        let visibility = localAppSettings.visibility;

        // correct the visibility; we don't want to start e.g. Hidden or Minimized
        if (visibility !== Window.Windowed &&
            visibility !== Window.Maximized &&
            visibility !== Window.FullScreen) {
            visibility = Window.Windowed
        }

        // first set the (normal) geometry, might get overridden later with the visibility
        if (geometry === undefined ||
            // If the monitor setup of the user changed, it's possible that the old geometry now falls out of the monitor range
            // In this case, we reset to the basic geometry
            geometry.x > Screen.desktopAvailableWidth ||
            geometry.y > Screen.desktopAvailableHeight ||
            geometry.width > Screen.desktopAvailableWidth ||
            geometry.height > Screen.desktopAvailableHeight ||
            geometry.x < 0 || geometry.y < 0 ||
            visibility !== Window.Windowed
            )
        {
            let screen = Qt.application.screens[0];

            geometry = Qt.rect(0,
                               0,
                               Math.min(Screen.desktopAvailableWidth - 125, ThemeUtils.defaultDesktopSize.width),
                               Math.min(Screen.desktopAvailableHeight - 125, ThemeUtils.defaultDesktopSize.height));
            geometry.x = (screen.width - geometry.width) / 2;
            geometry.y = (screen.height - geometry.height) / 2;
        }

        // apply (the corrected) geometry to the window
        applicationWindow.x = geometry.x
        applicationWindow.y = geometry.y
        applicationWindow.width = geometry.width
        applicationWindow.height = geometry.height

        // finally set the visibility; might be e.g. Maximized but we still want to restore back to normal (windowed) geometry when unmaximizing
        applicationWindow.visibility = visibility
    }

    function storeAppState() {
        if (SQUtils.Utils.isMobile) // no point in storing geometry or visibility
            return

        localAppSettings.visibility = applicationWindow.visibility
        let newRect = Qt.rect(applicationWindow.x, applicationWindow.y,
                              applicationWindow.width, applicationWindow.height)
        localAppSettings.geometry = newRect
    }

    onPortraitLayoutChanged: {
        // Android looses status bar icon color when switching orientation
        if (SQUtils.Utils.isAndroid) {
            SystemUtils.setAndroidStatusBarIconColor(applicationWindow.appThemeDark)
        }
    }

    QtObject {
        id: d
        property bool appMainTriggered: false
        property bool splashDismissed: false
        property double lastShakeShareMs: 0

        readonly property bool macOSWindowed: SQUtils.Utils.isMacOS && applicationWindow.visibility !== Window.FullScreen

        function restoreWindowState() {
            if (SQUtils.Utils.isMobile) // no point in restoring window state
                return
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

        property var keycardSimulatorWindow
        function createKeycardSimulatorController() {
            if (d.keycardSimulatorWindow)
                return
            if (!localAppSettings || !localAppSettings.useSimulatedKeycard)
                return
            if (typeof keycardTestController === "undefined" || !keycardTestController)
                return
            const c = Qt.createComponent("qrc:/imports/shared/panels/KeycardSimulatorController.qml")
            if (c.status === Component.Ready) {
                d.keycardSimulatorWindow = c.createObject(applicationWindow, { "controller": keycardTestController, "mainWindow": applicationWindow })
                if (d.keycardSimulatorWindow)
                    d.keycardSimulatorWindow.show()
            } else {
                console.warn("KeycardSimulatorController failed to load:", c.errorString())
            }
        }
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
        value: ThemeUtils.minimumDesktopSize.width
    }
    Binding {
        target: applicationWindow
        property: "minimumHeight"
        when: !SQUtils.Utils.isMobile
        value: ThemeUtils.minimumDesktopSize.height
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

    OpacityAnimator {
        id: appMainFadeIn
        target: loader
        from: 0
        to: 1
        duration: 120
        running: false
    }

    function moveToAppMain() {
        d.appMainTriggered = true
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
        enabled: SQUtils.Utils.isMacOS

        function onQuit(spontaneous) {
            if (spontaneous)
                Qt.exit(0)
        }
    }

    Connections {
        target: SystemUtils
        enabled: SQUtils.Utils.isMobile
        function onShakeDetected() {
            const nowMs = Date.now()
            if (nowMs - d.lastShakeShareMs < 3000) {
                openShakeToSharePopup()
                return
            }
            d.lastShakeShareMs = nowMs
        }

        Component.onCompleted: {
            if (SQUtils.Utils.isMobile) {
                SystemUtils.startShakeDetection()
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
            // save the geometry just before closing
            applicationWindow.storeAppState() // noop on mobile
            // on mobile, we minimize to background (no tray icon or quitOnClose setting)
            if (SQUtils.Utils.isMobile) {
                close.accepted = false
                if (SQUtils.Utils.isAndroid)
                    MobileUI.backToHomeScreen()
                else
                    applicationWindow.showMinimized()
            // In case not logged in or loading, quit app
            } else if (!loader.item) {
                close.accepted = true
            }
            // In case user has set to close should quit app
            else if (localAccountSensitiveSettings.quitOnClose) {
                close.accepted = true
            }
            else {
                // The window is already hidden or minimized.
                // The user really wants to quit the app
                if (applicationWindow.visibility === Window.Minimized || applicationWindow.visibility === Window.Hidden) {
                    close.accepted = true
                    return
                }

                // special handling for macOS
                if(Qt.platform.os === SQUtils.Utils.mac) {
                    /* In case of mac in fullscreen mode, hiding the window leads to black screen.
                    Hence we exit Fullscreen on system close and then the user can perform an actual
                    hide of the app */
                    close.accepted = false
                    if (applicationWindow.visibility === Window.FullScreen)
                        applicationWindow.showNormal()
                    else
                        applicationWindow.showMinimized()
                    return
                }

                // hide the window into the tray, if available; quit otherwise
                if (systemTray.available) {
                    close.accepted = false
                    // WRN 2025-11-26 <snip> file=qrc:/main.qml:26 text="QML QQuickWindowQmlImpl*: Conflicting properties 'visible' and 'visibility'"
                    applicationWindow.visibility = Window.Hidden
                } else {
                    close.accepted = true
                }
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

    Connections {
        target: Application
        function onAboutToQuit() {
            applicationWindow.storeAppState()
        }
    }

    Component.onCompleted: {

        console.info(">>> %1 %2 started, using Qt version %3, QPA: %4".arg(Application.name).arg(Application.version).arg(SystemUtils.qtRuntimeVersion()).arg(Qt.platform.pluginName))

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
            SystemUtils.setAndroidStatusBarIconColor(applicationWindow.appThemeDark)
        }

        // iOS: stop Qt text controls from reactively re-reading the clipboard on
        // every change, which triggers the system "paste from..." prompt when the
        // app returns to the foreground. See ClipboardUtils::suppressChangeNotifications().
        if (SQUtils.Utils.isIOS) {
            ClipboardUtils.suppressChangeNotifications()
        }

        restoreAppState()

        d.createKeycardSimulatorController()

        Global.openShakeToSharePopupRequested.connect(openShakeToSharePopup)

        if (applicationWindow.skipOnboarding) {
            moveToAppMain()
        }
    }

    function makeStatusAppActive() {
        d.restoreWindowState()
        applicationWindow.raise()
        applicationWindow.requestActivate()
    }

    function openShakeToSharePopup() {
        shakeToShareLoader.active = true
    }

    StatusTrayIcon {
        id: systemTray
        objectName: "systemTray"
        showRedDot: typeof mainModule !== "undefined" ? mainModule.notificationAvailable : false
        onActivateApp: {
            applicationWindow.makeStatusAppActive()
        }
    }

    Item {
        anchors.fill: parent
        SafeArea.additionalMargins.bottom: applicationWindow.additionalBottomMargin

        AppMainLoader {
            id: loader

            anchors.fill: parent
            anchors.topMargin: SQUtils.Utils.isMacOS && !applicationWindow.portraitLayout ? 0
                                                                                          : parent.SafeArea.margins.top
            anchors.bottomMargin: parent.SafeArea.margins.bottom
            anchors.leftMargin: applicationWindow.portraitLayout ? parent.SafeArea.margins.left
                                                      : 0 // the PrimaryNavSidebar is visible in landscape and already has it
            anchors.rightMargin: parent.SafeArea.margins.right

            opacity: 0
            visible: !startupOnboardingLoader.active

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            active: d.appMainTriggered && (typeof mainModule !== "undefined") && (mainModule?.mainLoaded ?? false)

            featureFlagsStore: applicationWindow.featureFlagsStore
            languageStore: applicationWindow.languageStore
            keychain: appKeychain
            systemTrayIconAvailable: systemTray.available
            utilsStore: applicationWindow.utilsStore

            onLoaded: {
                Global.appIsReady = true
                appMainFadeIn.running = true
                startupOnboardingLoader.active = false
                splashScreenLoader.active = false
                applicationWindow.contentLoaded()
                if (typeof onboardingModule !== "undefined"
                        && !!onboardingModule) {
                    Qt.callLater(() => onboardingModule.cleanupAfterMainTransition())
                }
                if (d.showSkippedBiometricFlow)
                    loader.item.showEnableBiometricsFlow()
            }

            onStatusChanged: {
                if (status === Loader.Error) {
                    console.error("Failed to load AppMain.qml")
                    Qt.exit(-1)
                }
            }
        }

        Loader {
            id: shakeToShareLoader
            active: false
            sourceComponent: StatusDialog {
                id: shakeLogFilesPopup
                title: qsTr("Share logs or report a bug?")
                visible: true
                contentItem: ColumnLayout {
                    spacing: Theme.padding
                    StatusButton {
                        id: exportLogFilesButton
                        Layout.fillWidth: true
                        text: qsTr("Export log files")
                        onClicked: {
                            try {
                                const json = globalUtils.collectLogFilesJson()
                                const paths = JSON.parse(json)
                                if (!paths || paths.length === 1) {
                                    exportLogFilesButton.enabled = false
                                    exportLogFilesButton.text = qsTr("No log files found")
                                    return
                                }

                                SystemUtils.sharePaths(paths)
                            } catch (e) {
                                console.error("[Shake] handler threw: " + e)
                            }
                            shakeLogFilesPopup.close()
                        }
                    }
                    StatusButton {
                        Layout.fillWidth: true
                        text: qsTr("Report a bug on GitHub")
                        onClicked: {
                            Qt.openUrlExternally(Constants.bugReportUrl)
                            shakeLogFilesPopup.close()
                        }
                    }
                }

                footer: null

                onClosed: shakeToShareLoader.active = false
            }
        }

        Loader {
            id: splashScreenLoader
            anchors.fill: parent
            sourceComponent: DidYouKnowSplashScreen {
                messagesEnabled: true
                infiniteLoading: true
            }
            onLoaded: {
                applicationWindow.contentLoaded()
            }
        }

        Loader {
            id: startupOnboardingLoader

            anchors.fill: parent
            anchors.topMargin: Qt.platform.os === SQUtils.Utils.mac ? 0 : parent.SafeArea.margins.top
            anchors.leftMargin: parent.SafeArea.margins.left
            anchors.rightMargin: parent.SafeArea.margins.right
            anchors.bottomMargin: parent.SafeArea.margins.bottom
            active: !applicationWindow.skipOnboarding

            source: active ? "app/AppLayouts/Onboarding/StartupOnboardingWrapper.qml" : ""

            onLoaded: {
                item.featureFlagsStore = applicationWindow.featureFlagsStore
                item.languageStore = applicationWindow.languageStore
                item.keychain = appKeychain
                item.lastSelectedProfileKeyUid = Qt.binding(() => localAppSettings.selectedProfileKeyUid)
                item.biometricFlowPending = Qt.binding(() => applicationWindow.biometricFlowPending)
                splashScreenLoader.active = false
                applicationWindow.contentLoaded()
                Backpressure.debounce(applicationWindow, 750, () => {
                    Qt.callLater(() => QmlCompiler.precompileAll()) // precompile all components after onboarding is loaded to speed up the login flow
                })()
            }
        }

        Connections {
            target: startupOnboardingLoader.item
            ignoreUnknownSignals: true

            function onAppReady() {
                applicationWindow.appIsReady = true
            }
            function onStoreAppStateRequested() {
                applicationWindow.storeAppState()
            }
            function onRequestMoveToAppMain() {
                applicationWindow.moveToAppMain()
            }
            function onBiometricFlowStarted() {
                applicationWindow.biometricFlowPending = true
            }
            function onSkippedBiometricFlow(available) {
                d.showSkippedBiometricFlow = available
            }
            function onProfileSelected(keyUid) {
                localAppSettings.selectedProfileKeyUid = keyUid
            }
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
                if(!loader.item && applicationWindow.appIsReady) {
                    moveToAppMain()
                }
                localAccountSettings.storeToKeychainValue = Constants.keychain.storedValue.store
            }
            onCredentialDeleted: (account) => localAccountSettings.storeToKeychainValue = Constants.keychain.storedValue.never
            onGetCredentialRequestCompleted: function(status, secret) {
                // Handle Failure to safely move on to appMain
                if (status !== Keychain.StatusSuccess &&
                        !loader.item &&
                        applicationWindow.appIsReady) {
                    moveToAppMain()
                }
            }
        }

        Loader {
            active: SQUtils.Utils.isAndroid
            sourceComponent: KeycardChannelDrawer {
                id: keycardChannelDrawer
                currentState: applicationWindow.keycardStateStore.state
                onDismissed: {
                    applicationWindow.keycardStateStore.keycardDismissed()
                }
            }
        }

        Loader {
            id: macOSSafeAreaLoader
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.right: parent.right
            height: active ? parent.SafeArea.margins.top : 0
            active: d.macOSWindowed
            sourceComponent: macHeaderComponent
        }
    }

    Component {
        id: macHeaderComponent
        MouseArea {
            id: headerMouseArea
            enabled: d.macOSWindowed
            propagateComposedEvents: true
            onPressed: (mouse) => {
                applicationWindow.startSystemMove()
                mouse.accepted = false
            }
        }
    }
}
