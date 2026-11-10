pragma ComponentBehavior: Bound

import QtQuick

import utils
import shared.popups
import shared.stores

import mainui.sectionLoaders
import AppLayouts.stores as AppStores
import AppLayouts.Profile.stores as ProfileStores

import StatusQ
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Backpressure


// The UI of one session: the login / onboarding flow, then the app. The window (main.qml)
// unloads it when the session ends and loads a new one for the next session.
Item {
    id: root

    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property ProfileStores.LanguageStore languageStore
    required property UtilsStore utilsStore
    required property bool systemTrayIconAvailable
    required property bool portraitLayout
    // Whether the login screen may log in silently with the stored credential of a profile:
    // (keyUid) => bool
    required property var allowsAutoLogin

    readonly property bool userLoggedIn: appMainLoader.item !== null

    signal contentLoaded()
    signal storeAppStateRequested()

    // Provided by Nim before the session's UI loads (see AppController.initializeQmlContext())
    readonly property bool skipOnboarding: typeof skipOnboardingContextProperty !== "undefined"
                                           ? skipOnboardingContextProperty
                                           : false

    function tryGoBack() : bool {
        return !!appMainLoader.item && !!appMainLoader.item.tryGoBack && appMainLoader.item.tryGoBack()
    }

    QtObject {
        id: d

        property bool appMainTriggered: false
        property bool appIsReady: false
        property bool biometricFlowPending: false
        property bool showSkippedBiometricFlow: false

        readonly property KeycardStateStore keycardStateStore: KeycardStateStore {}

        function moveToAppMain() : void {
            d.appMainTriggered = true
        }

        function setAppReady() : void {
            Global.appIsReady = true
            d.appIsReady = true
            root.storeAppStateRequested()
        }
    }

    Component.onCompleted: {
        if (root.skipOnboarding)
            d.moveToAppMain()
    }

    Component.onDestruction: Global.appIsReady = false

    OpacityAnimator {
        id: appMainFadeIn
        target: appMainLoader
        from: 0
        to: 1
        duration: 120
        running: false
    }

    AppMainLoader {
        id: appMainLoader

        anchors.fill: parent
        anchors.topMargin: SQUtils.Utils.isMacOS && !root.portraitLayout ? 0
                                                                         : root.SafeArea.margins.top
        anchors.bottomMargin: root.SafeArea.margins.bottom
        anchors.leftMargin: root.portraitLayout ? root.SafeArea.margins.left
                                                : 0 // the PrimaryNavSidebar is visible in landscape and already has it
        anchors.rightMargin: root.SafeArea.margins.right

        opacity: 0
        visible: !startupOnboardingLoader.active

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        active: d.appMainTriggered && (typeof mainModule !== "undefined")
        mainReady: typeof mainModule !== "undefined" && (mainModule?.mainLoaded ?? false)

        featureFlagsStore: root.featureFlagsStore
        languageStore: root.languageStore
        keychain: appKeychain
        secureStorage: appSecureStorage
        systemTrayIconAvailable: root.systemTrayIconAvailable
        utilsStore: root.utilsStore

        onLoaded: {
            // Remember the logged-in profile as the last selected one. The login
            // screen's profileSelected only covers profiles picked THERE — a freshly
            // onboarded profile never passes through it, yet startup auto-login
            // ("Stay logged in") targets exactly this key UID on the next launch.
            if (typeof userProfile !== "undefined" && userProfile.keyUid)
                localAppSettings.selectedProfileKeyUid = userProfile.keyUid

            appMainFadeIn.running = true
            startupOnboardingLoader.active = false
            root.contentLoaded()
            if (typeof onboardingModule !== "undefined"
                    && !!onboardingModule) {
                Qt.callLater(() => onboardingModule.cleanupAfterMainTransition())
            }
            if (mainReady)
                d.setAppReady()
            if (mainReady && d.showSkippedBiometricFlow) {
                d.showSkippedBiometricFlow = false
                appMainLoader.item.showEnableBiometricsFlow()
            }
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("Failed to load AppMain.qml")
                Qt.exit(-1)
            }
        }
    }

    Connections {
        target: typeof mainModule !== "undefined" ? mainModule : null

        function onMainLoadedChanged() {
            if (!mainModule.mainLoaded || startupOnboardingLoader.active)
                return
            d.setAppReady()
            if (d.showSkippedBiometricFlow && appMainLoader.item) {
                d.showSkippedBiometricFlow = false
                appMainLoader.item.showEnableBiometricsFlow()
            }
        }
    }

    Loader {
        id: startupOnboardingLoader

        anchors.fill: parent
        anchors.topMargin: Qt.platform.os === SQUtils.Utils.mac ? 0 : root.SafeArea.margins.top
        anchors.leftMargin: root.SafeArea.margins.left
        anchors.rightMargin: root.SafeArea.margins.right
        anchors.bottomMargin: root.SafeArea.margins.bottom
        active: !root.skipOnboarding

        source: active ? "../AppLayouts/Onboarding/StartupOnboardingWrapper.qml" : ""

        onLoaded: {
            item.featureFlagsStore = root.featureFlagsStore
            item.languageStore = root.languageStore
            item.keychain = appKeychain
            item.secureStorage = appSecureStorage
            item.lastSelectedProfileKeyUid = Qt.binding(() => localAppSettings.selectedProfileKeyUid)
            item.biometricFlowPending = Qt.binding(() => d.biometricFlowPending)
            // MUST be assigned LAST: enabling triggers the one-shot auto-login
            // attempt, which needs the key UID (and storage) already in place.
            // Decided (and logged) on the Nim side: e2e runs never auto-login, and
            // neither does the login screen after a sign-out or a logout.
            item.autoLoginEnabled = root.allowsAutoLogin(localAppSettings.selectedProfileKeyUid)
            root.contentLoaded()
            Backpressure.debounce(root, 750, () => {
                Qt.callLater(() => QmlCompiler.precompileAll()) // precompile all components after onboarding is loaded to speed up the login flow
            })()
        }
    }

    Connections {
        target: startupOnboardingLoader.item
        ignoreUnknownSignals: true

        function onAppReady() : void {
            d.appIsReady = true
        }
        function onStoreAppStateRequested() : void {
            root.storeAppStateRequested()
        }
        function onRequestMoveToAppMain() : void {
            d.moveToAppMain()
        }
        function onBiometricFlowStarted() : void {
            d.biometricFlowPending = true
        }
        function onSkippedBiometricFlow(available: bool) : void {
            d.showSkippedBiometricFlow = available
        }
        function onProfileSelected(keyUid: string) : void {
            localAppSettings.selectedProfileKeyUid = keyUid
        }
    }

    Keychain {
        id: appKeychain

        service: "StatusDesktop"

        // These signal handlers keep the compatibility with the old keychain approach,
        // which is used by `keycard_popup` (any auth inside the app) and the old onboarding.
        // NOTE: this hack won't work if changes are made with another Keychain instance.
        onCredentialSaved: function (account) {
            d.biometricFlowPending = false
            // load appMain if not already after biometric flow is complete
            if (!appMainLoader.item && d.appIsReady) {
                d.moveToAppMain()
            }
            localAccountSettings.storeToKeychainValue = Constants.keychain.storedValue.store
        }
        onCredentialDeleted: (account) => localAccountSettings.storeToKeychainValue = Constants.keychain.storedValue.never
        onGetCredentialRequestCompleted: function(status, secret) {
            // Handle Failure to safely move on to appMain
            if (status !== Keychain.StatusSuccess &&
                    !appMainLoader.item &&
                    d.appIsReady) {
                d.moveToAppMain()
            }
        }
    }

    SecureStorage {
        id: appSecureStorage

        service: "StatusDesktop.AutoLogin"
    }

    Loader {
        active: SQUtils.Utils.isAndroid
        sourceComponent: KeycardChannelDrawer {
            currentState: d.keycardStateStore.state
            onDismissed: {
                d.keycardStateStore.keycardDismissed()
            }
        }
    }
}
