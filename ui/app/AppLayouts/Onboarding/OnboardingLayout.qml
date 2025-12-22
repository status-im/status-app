import QtCore
import QtQuick

import QtQuick.Controls

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.enums

import StatusQ.Core.Utils as SQUtils

import utils

Page {
    id: root

    required property OnboardingStore onboardingStore
    required property Keychain keychain
    required property bool privacyModeFeatureEnabled

    // list of language/locale codes, e.g. ["cs_CZ","ko","fr"]
    required property var availableLanguages
    // language currently selected for translations, e.g. "cs"
    required property string currentLanguage

    property bool isKeycardEnabled: true

    property bool networkChecksEnabled: true

    property alias keycardPinInfoPageDelay: onboardingFlow.keycardPinInfoPageDelay

    readonly property alias stack: onboardingFlow // TODO remove external stack access
    readonly property string currentPageName: {
        if (!stack.topLevelItem)
            return ""

        const item = stack.topLevelItem instanceof Loader ? stack.topLevelItem.item
                                                          : stack.topLevelItem
        return Utils.objectTypeName(item)
    }

    signal changeLanguageRequested(string newLanguageCode)

    signal shareUsageDataRequested(bool enabled)
    signal skippedBiometricFlow()

    // flow: Onboarding.OnboardingFlow
    signal finished(int flow, var data)

    // -> "keyUid:string": User ID to login; "method:int": password or keycard (cf Onboarding.LoginMethod.*) enum;
    //    "data:var": contains "password" or "pin"
    signal loginRequested(string keyUid, int method, var data)

    signal keycardRequested()

    function restartFlow() {
        unload()
        onboardingFlow.restart()
    }

    function unload() {
        onboardingFlow.clear()
        d.resetState()
    }

    // clear the stack and load the LoginScreen
    // the purpose is to return from main/splash screen in case of a late stage error
    // and use the below error handler (onAccountLoginError)
    function unwindToLoginScreen() {
        restartFlow()
    }

    QtObject {
        id: d

        // constants
        readonly property int numWordsToVerify: 4

        // state collected
        property string password
        property string keycardPin
        property bool enableBiometrics
        property string seedphrase
        property string keyUid // Used in LoginWithLostKeycardSeedphrase
        property url backupImportFileUrl

        // login screen state
        property string selectedProfileKeyId

        property bool thirdpartyServicesEnabled: true

        function resetState() {
            d.password = ""
            d.keycardPin = ""
            d.enableBiometrics = false
            d.seedphrase = ""
            d.keyUid = ""
            d.backupImportFileUrl = ""
            d.selectedProfileKeyId = ""
            d.thirdpartyServicesEnabled = true
        }

        readonly property var settings: Settings { /* https://bugreports.qt.io/browse/QTBUG-135039 */
            property bool keycardPromoShown // whether we've seen the keycard promo banner on KeycardIntroPage

            function reset() {
                keycardPromoShown = false
            }
        }

        function finishFlow(flow) {
            const data = {
                password: d.password,
                keycardPin: d.keycardPin,
                seedphrase: d.seedphrase,
                keyUid: d.keyUid,
                backupImportFileUrl: d.backupImportFileUrl,
                enableBiometrics: d.enableBiometrics,
                thirdpartyServicesEnabled: d.thirdpartyServicesEnabled
            }

            root.finished(flow, data)
        }

        function loadMnemonic() {
            root.onboardingStore.loadMnemonic(d.seedphrase)
        }

        function authorize(pin) {
            if (!pin && !d.keycardPin) {
                console.warn("OnboardingLayout: authorize pin not provided")
                return
            }
            if (!pin) {
                pin = d.keycardPin
            }
            root.onboardingStore.authorize(pin)
        }
    }

    background: Rectangle {
        color: Theme.palette.background
    }

    OnboardingFlow {
        id: onboardingFlow

        anchors.fill: parent

        loginAccountsModel: root.onboardingStore.loginAccountsModel
        availableLanguages: root.availableLanguages
        currentLanguage: root.currentLanguage

        keycardState: root.onboardingStore.keycardState
        keycardUID: root.onboardingStore.keycardUID
        pinSettingState: root.onboardingStore.pinSettingState
        authorizationState: root.onboardingStore.authorizationState
        restoreKeysExportState: root.onboardingStore.restoreKeysExportState
        syncState: root.onboardingStore.syncState
        addKeyPairState: root.onboardingStore.addKeyPairState

        displayKeycardPromoBanner: !d.settings.keycardPromoShown

        biometricsAvailable: root.keychain.available
        isKeycardEnabled: root.isKeycardEnabled
        networkChecksEnabled: root.networkChecksEnabled

        generateMnemonic: root.onboardingStore.generateMnemonic
        isBiometricsLogin: (account) => root.keychain.hasCredential(account) === Keychain.StatusSuccess
        passwordStrengthScoreFunction: root.onboardingStore.getPasswordStrengthScore
        isSeedPhraseValid: root.onboardingStore.validMnemonic
        isSeedPhraseDuplicate: root.onboardingStore.isMnemonicDuplicate
        validateConnectionString: root.onboardingStore.validateLocalPairingConnectionString
        tryToSetPukFunction: root.onboardingStore.setPuk
        remainingPinAttempts: root.onboardingStore.keycardRemainingPinAttempts
        remainingPukAttempts: root.onboardingStore.keycardRemainingPukAttempts

        onChangeLanguageRequested: (newLanguageCode) => root.changeLanguageRequested(newLanguageCode)

        onLoginRequested: (keyUid, method, data) => root.loginRequested(keyUid, method, data)

        onSetPinRequested: (pin) => {
            d.keycardPin = pin
            root.onboardingStore.setPin(pin)
        }

        onLoadMnemonicRequested: d.loadMnemonic()
        onAuthorizationRequested: (pin) => d.authorize(pin)
        onShareUsageDataRequested: (enabled) => root.shareUsageDataRequested(enabled)
        onPerformKeycardFactoryResetRequested: root.onboardingStore.startKeycardFactoryReset()
        onSyncProceedWithConnectionString: (connectionString) =>
            root.onboardingStore.inputConnectionStringForBootstrapping(connectionString)
        onSeedphraseSubmitted: (seedphrase) => d.seedphrase = seedphrase
        onKeyUidSubmitted: (keyUid) => d.keyUid = keyUid
        onSetPasswordRequested: (password) => d.password = password
        onEnableBiometricsRequested: (enabled) => d.enableBiometrics = enabled
        onLinkActivated: (link) => Qt.openUrlExternally(link)
        onExportKeysRequested: root.onboardingStore.exportRecoverKeys()
        onImportLocalBackupRequested: (importFilePath) => d.backupImportFileUrl = importFilePath
        onFinished: (flow) => d.finishFlow(flow)
        onKeycardRequested: {
            root.keycardRequested()
            root.onboardingStore.startKeycardDetection()
        }

        onBiometricsRequested: (profileId) => {
            const isKeycardProfile = SQUtils.ModelUtils.getByKey(
                                       onboardingStore.loginAccountsModel, "keyUid",
                                       profileId, "keycardCreatedAccount")

            const reason = isKeycardProfile ? qsTr("fetch pin") : qsTr("fetch password")

            root.keychain.requestGetCredential(reason, profileId)
        }

        onDismissBiometricsRequested: {
            if (root.keychain.loading)
                root.keychain.cancelActiveRequest()
        }

        privacyModeFeatureEnabled: root.privacyModeFeatureEnabled
        thirdpartyServicesEnabled: d.thirdpartyServicesEnabled
        onToggleThirdpartyServicesEnabledRequested: {
            d.thirdpartyServicesEnabled = !d.thirdpartyServicesEnabled
        }

        onSkippedBiometricFlow: root.skippedBiometricFlow()
    }

    // needs to be on top of the stack
    // we're here only to provide the Back button feature
    StatusMouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        cursorShape: undefined // don't override the cursor coming from the stack
        enabled: backButton.visible
        onClicked: onboardingFlow.popTopLevelItem()
    }

    StatusBackButton {
        id: backButton

        width: 44
        height: 44
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.padding

        opacity: onboardingFlow.depth > 1 && !onboardingFlow.topLevelStack.busy &&
                 onboardingFlow.backAvailable ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 100 }
        }

        onClicked: onboardingFlow.popTopLevelItem()
    }

    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_Back && backButton.visible) {
            e.accepted = true
            onboardingFlow.popTopLevelItem()
        }
    }

    Connections {
        target: onboardingFlow.topLevelItem
        ignoreUnknownSignals: true

        function onRequestOpenLink(link: string) {
            Qt.openUrlExternally(link)
        }
    }

    // error handler for the LoginScreen
    Connections {
        target: root.onboardingStore

        function onAccountLoginError(error: string, wrongPassword: bool) {
            const loginScreen = onboardingFlow.loginScreen

            if (!loginScreen)
                return

            loginScreen.setAccountLoginError(error, wrongPassword)
        }
    }

    Connections {
        target: root.keychain

        function onGetCredentialRequestCompleted(status, secret) {
            if (status === Keychain.StatusSuccess)
                onboardingFlow.setBiometricResponse(secret)
            else if (status === Keychain.StatusNotFound)
                onboardingFlow.setBiometricResponse("", qsTr("Credentials not found."))
            else if (status === Keychain.StatusFallbackSelected)
                onboardingFlow.setBiometricResponse("", "")
            else if (status !== Keychain.StatusCancelled)
                onboardingFlow.setBiometricResponse("", qsTr("Fetching credentials failed."))
        }
    }

    Component.onCompleted: restartFlow()
}
