import QtCore
import QtQuick

import QtQuick.Controls

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.enums

import StatusQ.Core.Utils as SQUtils

import utils

Page {
    id: root

    required property OnboardingStore onboardingStore
    required property Keychain keychain

    // Prompt-free secure storage backing the "Stay logged in" opt-in. Optional:
    // instantiation sites without it (tests, storybook) simply don't offer the opt-in.
    property SecureStorage secureStorage: null

    // Enables the silent auto-login attempt at startup. Kill-switched off in test
    // environments: the OS secure store is not per-data-dir, so a leftover developer
    // credential must never hijack an e2e run.
    property bool autoLoginEnabled: false

    // One-shot marker: a failed auto-login must fall back to the normal login screen,
    // never retry (the wrapper also uses it to drop the stale credential on error).
    readonly property alias autoLoginAttempted: d.autoLoginAttempted

    // Consumed by the wrapper on the FIRST login error after an auto-login attempt:
    // returns the key UID whose stored credential is stale, then clears itself — so a
    // later manual-login error (possibly for a DIFFERENT profile) can never delete that
    // profile's valid credential.
    function consumeAutoLoginFailure() : string {
        const keyUid = d.autoLoginPendingKeyUid
        d.autoLoginPendingKeyUid = ""
        return keyUid
    }

    onAutoLoginEnabledChanged: d.tryAutoLogin()
    required property bool privacyModeFeatureEnabled

    // list of language/locale codes, e.g. ["cs_CZ","ko","fr"]
    required property var availableLanguages
    // language currently selected for translations, e.g. "cs"
    required property string currentLanguage

    property bool isKeycardEnabled: true
    property string lastSelectedProfileKeyUid

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

    signal skippedBiometricFlow()

    // flow: Onboarding.OnboardingFlow
    signal finished(int flow, var data)

    // -> "keyUid:string": User ID to login; "method:int": password or keycard (cf Onboarding.LoginMethod.*) enum;
    //    "data:var": contains "password" or "pin"
    signal loginRequested(string keyUid, int method, var data)
    signal profileSelected(string keyUid)

    function restartFlow() : void {
        unload()
        onboardingFlow.restart()
    }

    function unload() : void {
        onboardingFlow.clear()
        d.resetState()
    }

    // clear the stack and load the LoginScreen
    // the purpose is to return from main/splash screen in case of a late stage error
    // and use the below error handler (onAccountLoginError)
    function unwindToLoginScreen() : void {
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
        property bool stayLoggedIn
        property string seedphrase
        property string keyUid // Used in LoginWithLostKeycardSeedphrase
        property url backupImportFileUrl

        property var keycardPayload: null

        // silent auto-login (one-shot per app run — deliberately NOT reset in resetState)
        property bool autoLoginAttempted
        property string autoLoginPendingKeyUid // set with the attempt, consumed on its failure

        // login screen state
        property string selectedProfileKeyId

        property bool thirdpartyServicesEnabled: true

        function resetState() : void {
            d.password = ""
            d.keycardPin = ""
            d.enableBiometrics = false
            d.stayLoggedIn = false
            d.seedphrase = ""
            d.keyUid = ""
            d.backupImportFileUrl = ""
            d.selectedProfileKeyId = ""
            d.thirdpartyServicesEnabled = true
            d.keycardPayload = null
        }

        readonly property var settings: Settings { /* https://bugreports.qt.io/browse/QTBUG-135039 */
            property bool keycardPromoShown // whether we've seen the keycard promo banner on KeycardIntroPage

            function reset() : void {
                keycardPromoShown = false
            }
        }

        function finishFlow(flow: int) : void {
            const keyUid = onboardingFlow.loginScreen ? onboardingFlow.loginScreen.selectedProfileKeyId : ""
            const data = {
                selectedProfileKeyUid: keyUid, // used to determine whether import seed phrase was done for the login or onboarding purpose
                password: d.password,
                keycardPin: d.keycardPin,
                seedphrase: d.seedphrase,
                keyUid: d.keyUid,
                backupImportFileUrl: d.backupImportFileUrl,
                enableBiometrics: d.enableBiometrics,
                stayLoggedIn: d.stayLoggedIn,
                thirdpartyServicesEnabled: d.thirdpartyServicesEnabled,
                keycardPayload: d.keycardPayload
            }

            root.finished(flow, data)
        }

        // Startup auto-login: the trigger is the PRESENCE of a silently readable
        // credential for the last-used profile (the per-account preference isn't
        // readable pre-login; logout already deleted the credential when auto-login
        // shouldn't fire). Rides the exact same rails as a biometric DEK login — the
        // wrapper's onLoginRequested pushes the splash screen, so the login screen
        // never flashes.
        // The bail reasons are logged (key UIDs are public identifiers, the credential
        // itself is never logged) — auto-login failures are otherwise invisible: the
        // app just shows the ordinary login screen.
        function tryAutoLogin() : void {
            // No log for the disabled case: the attempt always runs once before
            // main.qml enables auto-login; main.qml logs the real "disabled" reasons.
            if (d.autoLoginAttempted || !root.autoLoginEnabled)
                return
            if (!root.secureStorage || !root.secureStorage.available) {
                console.info("auto-login: secure storage unavailable")
                return
            }

            const keyUid = root.lastSelectedProfileKeyUid
            if (keyUid === "") {
                console.info("auto-login: no last selected profile recorded")
                return
            }

            const profile = SQUtils.ModelUtils.getByKey(root.onboardingStore.loginAccountsModel,
                                                        "keyUid", keyUid)
            if (!profile || profile.keycardCreatedAccount) {
                // unknown profile, or keycard (out of scope for auto-login)
                console.info("auto-login: profile", keyUid,
                             !profile ? "not in the accounts model" : "is a keycard profile")
                return
            }

            const result = root.secureStorage.getCredential(keyUid)
            if (result.status !== SecureStorage.StatusSuccess) {
                // nothing stored (or a storage hiccup) -> normal login screen
                console.info("auto-login: no stored credential for", keyUid, "(status:", result.status + ")")
                return
            }

            if (!result.credential.startsWith(Constants.keychain.dekPrefix)) {
                // The silent store must only ever hold a tagged DEK — drop anything else
                console.warn("auto-login: dropping a non-DEK credential for", keyUid)
                root.secureStorage.deleteCredential(keyUid)
                return
            }

            console.info("auto-login: attempting silent login for", keyUid)
            d.autoLoginAttempted = true
            d.autoLoginPendingKeyUid = keyUid
            root.loginRequested(keyUid, Onboarding.LoginMethod.Password,
                                { dek: result.credential.slice(Constants.keychain.dekPrefix.length) })
        }

        Component.onCompleted: d.tryAutoLogin()
    }

    background: Rectangle {
        color: Theme.palette.background
    }

    OnboardingFlow {
        id: onboardingFlow
        objectName: "onboardingFlow"

        anchors.fill: parent

        loginAccountsModel: root.onboardingStore.loginAccountsModel
        availableLanguages: root.availableLanguages
        currentLanguage: root.currentLanguage

        keycardState: root.onboardingStore.keycardState
        keycardUID: root.onboardingStore.keycardUID
        keycardKeyUID: root.onboardingStore.keycardKeyUID
        keycardInitialized: root.onboardingStore.keycardInitialized
        syncState: root.onboardingStore.syncState

        displayKeycardPromoBanner: !d.settings.keycardPromoShown

        biometricsAvailable: root.keychain.available
        stayLoggedInAvailable: root.secureStorage ? root.secureStorage.available : false
        isKeycardEnabled: root.isKeycardEnabled
        lastSelectedProfileKeyUid: root.lastSelectedProfileKeyUid
        networkChecksEnabled: root.networkChecksEnabled

        isBiometricsLogin: (account) => root.keychain.hasCredential(account) === Keychain.StatusSuccess
        passwordStrengthScoreFunction: root.onboardingStore.getPasswordStrengthScore
        isProfileMigratedToDEKEncryption: root.onboardingStore.isProfileMigratedToDEKEncryption
        isSeedPhraseValid: root.onboardingStore.validMnemonic
        isSeedPhraseDuplicate: root.onboardingStore.isMnemonicDuplicate
        validateConnectionString: root.onboardingStore.validateLocalPairingConnectionString
        // tryToSetPukFunction: root.onboardingStore.setPuk
        remainingPinAttempts: root.onboardingStore.keycardRemainingPinAttempts
        remainingPukAttempts: root.onboardingStore.keycardRemainingPukAttempts
        keycardStatusAvailable: root.onboardingStore.keycardStatusAvailable
        keycardAvailableSlots: root.onboardingStore.keycardAvailableSlots
        keycardPairingSupported: root.onboardingStore.keycardPairingSupported
        keycardCertificateTrusted: root.onboardingStore.keycardCertificateTrusted
        keycardCardMetadataName: root.onboardingStore.keycardCardMetadataName
        keycardCardMetadataWalletAccountsJson: root.onboardingStore.keycardCardMetadataWalletAccountsJson

        onChangeLanguageRequested: (newLanguageCode) => root.changeLanguageRequested(newLanguageCode)

        onLoginRequested: (keyUid, method, data) => root.loginRequested(keyUid, method, data)
        onProfileSelected: (keyUid) => root.profileSelected(keyUid)

        onSyncProceedWithConnectionString: (connectionString) =>
            root.onboardingStore.inputConnectionStringForBootstrapping(connectionString)
        onSeedphraseSubmitted: (seedphrase) => d.seedphrase = seedphrase
        onKeyUidSubmitted: (keyUid) => d.keyUid = keyUid
        onSetPasswordRequested: (password) => d.password = password
        onEnableBiometricsRequested: (enabled) => d.enableBiometrics = enabled
        onStayLoggedInRequested: (enabled) => d.stayLoggedIn = enabled
        onLinkActivated: (link) => Qt.openUrlExternally(link)
        onImportLocalBackupRequested: (importFilePath) => d.backupImportFileUrl = importFilePath
        onOnboardingKeycardFlowCompletedWithData: (flow, dataJson) => {
                                                      try {
                                                          const payload = JSON.parse(dataJson)
                                                          d.keycardPayload = payload
                                                          if (flow === Constants.keycard.flow.startUsingProfileWithoutKeycard) {
                                                              d.keyUid = payload.keyUid ?? ""
                                                              d.seedphrase = payload.seedPhrase ?? ""
                                                              d.password = payload.password ?? ""
                                                          }
                                                      } catch (e) {
                                                          console.warn("OnboardingLayout: failed to parse keycard popup payload:", e.message)
                                                          d.keycardPayload = null
                                                      }
                                                  }
        onFinished: (flow) => d.finishFlow(flow)

        onBiometricsRequested: (profileId) => {
            const isKeycardProfile = SQUtils.ModelUtils.getByKey(
                                       onboardingStore.loginAccountsModel, "keyUid",
                                       profileId, "keycardCreatedAccount")

            const reason = isKeycardProfile ? qsTr("fetch pin") : qsTr("fetch password")

            root.keychain.requestGetCredential(reason, profileId)
        }

        onDismissBiometricsRequested: {
            if (root.keychain && root.keychain.loading)
                root.keychain.cancelActiveRequest()
        }

        privacyModeFeatureEnabled: root.privacyModeFeatureEnabled
        thirdpartyServicesEnabled: d.thirdpartyServicesEnabled
        onToggleThirdpartyServicesEnabledRequested: {
            d.thirdpartyServicesEnabled = !d.thirdpartyServicesEnabled
        }

        onSkippedBiometricFlow: root.skippedBiometricFlow()
        onDeleteMultiaccountRequested: keyUid => root.onboardingStore.deleteMultiaccountRequested(keyUid)
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

        function onRequestOpenLink(link: string) : void {
            Qt.openUrlExternally(link)
        }
    }

    StatusMessageDialog {
        id: accountsLoadErrorDialog
        objectName: "accountsLoadErrorDialog"
        title: qsTr("Error loading accounts")
        text: qsTr("Failed to load accounts. Please restart the app and try again.")
        icon: StatusMessageDialog.StandardIcon.Critical
    }

    Connections {
        target: root.onboardingStore

        function onAccountLoginError(error: string, wrongPassword: bool) : void {
            const loginScreen = onboardingFlow.loginScreen
            if (loginScreen) {
                loginScreen.setAccountLoginError(error, wrongPassword)
                return
            }
            accountsLoadErrorDialog.open()
        }
    }

    Connections {
        target: root.keychain

        function onGetCredentialRequestCompleted(status, secret) {
            if (status === Keychain.StatusSuccess)
                onboardingFlow.setBiometricResponse(secret, "")
            else if (status === Keychain.StatusNotFound)
                onboardingFlow.setBiometricResponse("", qsTr("Credentials not found."))
            else if (status === Keychain.StatusFallbackSelected)
                onboardingFlow.setBiometricResponse("", "")
            else if (status !== Keychain.StatusCancelled)
                onboardingFlow.setBiometricResponse("", qsTr("Fetching credentials failed."))
        }
    }
}
