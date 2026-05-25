import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Onboarding.pages
import AppLayouts.Onboarding.enums
import AppLayouts.Onboarding.controls
import AppLayouts.Onboarding.stores

import QtModelsToolkit

import shared.popups
import shared.popups.keycard_new
import utils
import SortFilterProxyModel

OnboardingStackView {
    id: root

    required property var loginAccountsModel

    // list of language/locale codes, e.g. ["cs_CZ","ko","fr"]
    required property var availableLanguages
    // language currently selected for translations, e.g. "cs"
    required property string currentLanguage

    required property int keycardState
    required property string keycardUID
    required property string keycardKeyUID
    required property int pinSettingState
    required property int authorizationState
    required property int restoreKeysExportState
    required property int addKeyPairState
    required property int syncState
    required property int remainingPinAttempts
    required property int remainingPukAttempts
    required property bool keycardStatusAvailable
    required property int keycardAvailableSlots
    required property string keycardCardMetadataName
    required property string keycardCardMetadataWalletAccountsJson

    required property bool biometricsAvailable
    required property bool displayKeycardPromoBanner
    required property bool networkChecksEnabled

    property bool isKeycardEnabled: true
    property int keycardPinInfoPageDelay: 2000
    property string lastSelectedProfileKeyUid

    // functions
    required property var generateMnemonic
    required property var isBiometricsLogin // (string account) => bool
    required property var passwordStrengthScoreFunction
    required property var isSeedPhraseValid
    required property var isSeedPhraseDuplicate
    required property var validateConnectionString

    readonly property LoginScreen loginScreen: d.loginScreen

    signal changeLanguageRequested(string newLanguageCode)
    signal biometricsRequested(string profileId)
    signal dismissBiometricsRequested
    signal loginRequested(string keyUid, int method, var data)
    signal recoverKeycardRequested(string pin, string seedphrase)
    signal setPinRequested(string pin)
    signal enableBiometricsRequested(bool enable)
    signal syncProceedWithConnectionString(string connectionString)
    signal seedphraseSubmitted(string seedphrase)
    signal keyUidSubmitted(string keyUid)
    signal setPasswordRequested(string password)
    signal exportKeysRequested
    signal loadMnemonicRequested
    signal authorizationRequested(string pin)
    signal performKeycardFactoryResetRequested
    signal importLocalBackupRequested(url importFilePath)
    signal deleteMultiaccountRequested(string keyUid)

    signal profileSelected(string keyUid)
    signal linkActivated(string link)

    signal finished(int flow)
    signal keycardRequested()

    signal onboardingKeycardFlowCompletedWithData(string flow, string dataJson)

    // Thirdparty services
    required property bool privacyModeFeatureEnabled
    required property bool thirdpartyServicesEnabled
    signal toggleThirdpartyServicesEnabledRequested()

    signal skippedBiometricFlow()

    function restart() {
        replace(null, loginAccountsModel.ModelCount.empty ? welcomePage : loginScreenComponent)
    }

    function setBiometricResponse(secret: string, error = "") {
        if (!loginScreen)
            return

        loginScreen.setBiometricResponse(secret, error)
    }

    QtObject {
        id: d

        property int flow
        property LoginScreen loginScreen: null


        function pushOrSkipBiometricsPage() {
            if (d.flow === Onboarding.OnboardingFlow.LoginWithSyncing
                    || d.flow === Onboarding.OnboardingFlow.LoginWithKeycard) {
                root.skippedBiometricFlow()
                root.finished(d.flow)
                return
            }

            if (root.biometricsAvailable) {
                root.replace(null, enableBiometricsPage)
            } else {
                root.finished(d.flow)
            }
        }

        function openPrivacyPolicyPopup() {
            privacyPolicyPopup.createObject(root).open()
        }

        function openTermsOfUsePopup() {
            termsOfUsePopup.createObject(root).open()
        }

        function handleKeycardProgressFailedState(state) {
            if (state === Onboarding.ProgressState.Failed)
                handleKeycardFailedState()
        }

        function handleKeycardAuthorizationErrorState(state) {
            if (state === Onboarding.AuthorizationState.Error)
                handleKeycardFailedState()
        }

        function handleKeycardFailedState() {
            root.replace(root.get(1), errorPage)
        }

        function openThirdpartyServicesPopup() {
            thirdpartyServicesPopup.createObject(root).open()
        }

        function openManageProfilesPopup() {
            manageProfilesPopup.createObject(root).open()
        }

        function openDeleteMultiaccountConfirmationDialog(keyUid, username) {
            deleteMultiaccountConfirmationDialog.createObject(root, { keyUid, username }).open()
        }
    }

    Connections {
        enabled: root.depth > 1 && !(root.currentItem instanceof KeycardErrorPage)

        function onPinSettingStateChanged() {
            d.handleKeycardProgressFailedState(pinSettingState)
        }

        function onAuthorizationStateChanged() {
            d.handleKeycardAuthorizationErrorState(authorizationState)
        }

        function onRestoreKeysExportStateChanged() {
            d.handleKeycardProgressFailedState(restoreKeysExportState)
        }

        function onAddKeyPairStateChanged() {
            d.handleKeycardProgressFailedState(addKeyPairState)
        }
    }

    Component {
        id: errorPage

        KeycardErrorPage {
            readonly property bool backAvailableHint: false

            onTryAgainRequested: root.pop()
            onFactoryResetRequested: root.push(keycardFactoryResetFlow)
        }
    }



    Component {
        id: welcomePage

        WelcomePage {
            availableLanguages: root.availableLanguages
            currentLanguage: root.currentLanguage
            onChangeLanguageRequested: (newLanguageCode) => root.changeLanguageRequested(newLanguageCode)

            privacyModeFeatureEnabled: root.privacyModeFeatureEnabled
            thirdpartyServicesEnabled: root.thirdpartyServicesEnabled

            onCreateProfileRequested: root.push(createProfilePage)
            onLoginRequested: root.push(loginPage)

            onPrivacyPolicyRequested: d.openPrivacyPolicyPopup()
            onTermsOfUseRequested: d.openTermsOfUsePopup()
            onOpenThirdpartyServicesInfoPopupRequested: d.openThirdpartyServicesPopup()
        }
    }

    Component {
        id: loginScreenComponent

        LoginScreen {
            id: loginScreen

            keycardState: root.keycardState
            keycardUID: root.keycardUID
            keycardKeyUID: root.keycardKeyUID
            keycardRemainingPinAttempts: root.remainingPinAttempts
            keycardRemainingPukAttempts: root.remainingPukAttempts

            availableLanguages: root.availableLanguages
            currentLanguage: root.currentLanguage
            onChangeLanguageRequested: (newLanguageCode) => root.changeLanguageRequested(newLanguageCode)

            loginAccountsModel: root.loginAccountsModel
            isKeycardEnabled: root.isKeycardEnabled
            lastSelectedProfileKeyUid: root.lastSelectedProfileKeyUid
            isBiometricsLogin: root.biometricsAvailable &&
                               root.isBiometricsLogin(loginScreen.selectedProfileKeyId)

            onProfileSelected: (keyUid) => root.profileSelected(keyUid)
            onBiometricsRequested: (profileId) => {
                if (visible)
                    root.biometricsRequested(profileId)
            }
            onDismissBiometricsRequested: root.dismissBiometricsRequested()
            onLoginRequested: (keyUid, method, data) => root.loginRequested(keyUid, method, data)
            onOnboardingCreateProfileFlowRequested: root.push(createProfilePage)
            onOnboardingLoginFlowRequested: root.push(loginPage)
            onLostKeycardFlowRequested: {
                root.keyUidSubmitted(loginScreen.selectedProfileKeyId)
                root.push(keycardLostPage)
            }
            onOnboardingManageProfilesFlowRequested: d.openManageProfilesPopup()

            onUnblockWithSeedphraseRequested: root.push(unblockWithSeedphraseFlowComponent)
            onUnblockWithPukRequested: root.push(unblockWithPukFlowComponent)
            onUnblockKeycardRequested: {
                const stateStr = root.keycardState === Onboarding.KeycardState.BlockedPIN
                                 ? Constants.keycard.state.blockedPIN
                                 : Constants.keycard.state.blockedPUK
                root.push(keycardDetailsComponent, {
                    keycardState: stateStr,
                    keycardUid: root.keycardUID,
                    keyUid: root.keycardKeyUID,
                    keycardStatusAvailable: root.keycardStatusAvailable,
                    remainingPinAttempts: root.remainingPinAttempts,
                    remainingPukAttempts: root.remainingPukAttempts,
                    availableSlots: root.keycardAvailableSlots,
                    cardMetadataName: root.keycardCardMetadataName,
                    cardMetadataWalletAccountsJson: root.keycardCardMetadataWalletAccountsJson
                })
            }
            onKeycardRequested: {
                root.keycardRequested()
            }

            onVisibleChanged: {
                if (!visible)
                    root.dismissBiometricsRequested()
            }

            Component.onDestruction: root.dismissBiometricsRequested()

            Binding {
                target: d
                restoreMode: Binding.RestoreValue
                property: "loginScreen"
                value: loginScreen
            }
        }
    }

    Component {
        id: createProfilePage

        CreateProfilePage {
            isKeycardEnabled: root.isKeycardEnabled

            onCreateProfileWithPasswordRequested: root.push(createNewProfileFlow)
            onCreateProfileWithSeedphraseRequested: {
                d.flow = Onboarding.OnboardingFlow.CreateProfileWithSeedphrase
                root.push(useRecoveryPhraseFlow,
                          { type: UseRecoveryPhraseFlow.Type.NewProfile })
            }
            onCreateProfileWithEmptyKeycardRequested: {
                root.keycardRequested()
                root.push(keycardCreateProfileFlow)
            }
        }
    }

    Component {
        id: loginPage

        NewAccountLoginPage {
            networkChecksEnabled: root.networkChecksEnabled
            isKeycardEnabled: root.isKeycardEnabled
            thirdpartyServicesEnabled: root.thirdpartyServicesEnabled

            onLoginWithSyncingRequested: root.push(logInBySyncingFlow)
            onLoginWithKeycardRequested: {
                root.keycardRequested()
                root.push(loginWithKeycardFlow)
            }

            onLoginWithSeedphraseRequested: {
                d.flow = Onboarding.OnboardingFlow.LoginWithSeedphrase
                root.push(useRecoveryPhraseFlow,
                          { type: UseRecoveryPhraseFlow.Type.Login })
            }
        }
    }

    Component {
        id: keycardLostPage

        KeycardLostPage {
            onCreateReplacementKeycardRequested: {
                d.flow = Onboarding.OnboardingFlow.LoginWithRestoredKeycard
                root.push(keycardCreateReplacementFlow)
            }

            onUseProfileWithoutKeycardRequested: {
                d.flow = Onboarding.OnboardingFlow.LoginWithLostKeycardSeedphrase
                root.push(useRecoveryPhraseFlow,
                          { type: UseRecoveryPhraseFlow.Type.KeycardRecovery })
            }
        }
    }

    /* TODO: uncomment when integrating new onboarding
    Component {
        id: keycardLostPage

        KeycardLostPageNew {

            onReadSpareKeycardRequested: {
                const keyUid = root.loginScreen ? root.loginScreen.selectedProfileKeyId : ""
                root.openKeycardPopup(Constants.keycard.flow.readKeycard, keyUid, "", "", "[]")
            }

            onStopUsingKeycardForProfileRequested: {
                const keyUid = root.loginScreen ? root.loginScreen.selectedProfileKeyId : ""
                root.openKeycardPopup(Constants.keycard.flow.startUsingProfileWithoutKeycard, keyUid, "", "", "[]")
            }
        }
    }
    */

    Component {
        id: createNewProfileFlow

        CreateNewProfileFlow {
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction

            onFinished: (password) => {
                root.setPasswordRequested(password)
                d.flow = Onboarding.OnboardingFlow.CreateProfileWithPassword
                d.pushOrSkipBiometricsPage()
            }
        }
    }

    Component {
        id: useRecoveryPhraseFlow

        UseRecoveryPhraseFlow {
            isSeedPhraseValid: root.isSeedPhraseValid
            isSeedPhraseDuplicate: root.isSeedPhraseDuplicate
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction

            onSeedphraseSubmitted: (seedphrase) => root.seedphraseSubmitted(seedphrase)
            onSetPasswordRequested: (password) => root.setPasswordRequested(password)

            onImportLocalBackupRequested: (importFilePath) => root.importLocalBackupRequested(importFilePath)

            onFinished: d.pushOrSkipBiometricsPage()
        }
    }

    Component {
        id: keycardCreateProfileFlow

        KeycardCreateProfileFlow {
            keycardState: root.keycardState
            pinSettingState: root.pinSettingState
            authorizationState: root.authorizationState
            addKeyPairState: root.addKeyPairState
            generateMnemonic: root.generateMnemonic
            displayKeycardPromoBanner: root.displayKeycardPromoBanner
            isSeedPhraseValid: root.isSeedPhraseValid

            keycardPinInfoPageDelay: root.keycardPinInfoPageDelay

            onKeycardFactoryResetRequested: root.push(keycardFactoryResetFlow)
            onLoadMnemonicRequested: root.loadMnemonicRequested()
            onSetPinRequested: (pin) => root.setPinRequested(pin)
            onLoginWithKeycardRequested: root.push(loginWithKeycardFlow)
            onAuthorizationRequested: root.authorizationRequested("") // Pin was saved locally already
            onSeedphraseSubmitted: (seedphrase) => root.seedphraseSubmitted(seedphrase)

            onFinished: (withNewSeedphrase) => {
                d.flow = withNewSeedphrase
                            ? Onboarding.OnboardingFlow.CreateProfileWithKeycardNewSeedphrase
                            : Onboarding.OnboardingFlow.CreateProfileWithKeycardExistingSeedphrase

                d.pushOrSkipBiometricsPage()
            }
        }
    }

    Component {
        id: logInBySyncingFlow

        LoginBySyncingFlow {
            validateConnectionString: root.validateConnectionString
            syncState: root.syncState

            onSyncProceedWithConnectionString:
                (connectionString) => root.syncProceedWithConnectionString(connectionString)

            onLoginWithSeedphraseRequested: {
                d.flow = Onboarding.OnboardingFlow.LoginWithSeedphrase

                root.push(useRecoveryPhraseFlow,
                          { type: UseRecoveryPhraseFlow.Type.Login })
            }

            onFinished: {
                d.flow = Onboarding.OnboardingFlow.LoginWithSyncing
                d.pushOrSkipBiometricsPage()
            }
        }
    }

    Component {
        id: loginWithKeycardFlow

        LoginWithKeycardFlow {
            keycardState: root.keycardState
            authorizationState: root.authorizationState
            restoreKeysExportState: root.restoreKeysExportState
            remainingPinAttempts: root.remainingPinAttempts
            remainingPukAttempts: root.remainingPukAttempts
            displayKeycardPromoBanner: root.displayKeycardPromoBanner
            onAuthorizationRequested: (pin) => root.authorizationRequested(pin)

            keycardPinInfoPageDelay: root.keycardPinInfoPageDelay

            onCreateProfileWithEmptyKeycardRequested: root.push(keycardCreateProfileFlow)
            onExportKeysRequested: root.exportKeysRequested()
            onKeycardFactoryResetRequested: root.push(keycardFactoryResetFlow)
            onUnblockWithSeedphraseRequested: root.push(unblockWithSeedphraseFlowComponent)
            onUnblockWithPukRequested: root.push(unblockWithPukFlowComponent)

            onImportLocalBackupRequested: (importFilePath) => root.importLocalBackupRequested(importFilePath)

            onFinished: {
                d.flow = Onboarding.OnboardingFlow.LoginWithKeycard
                d.pushOrSkipBiometricsPage()
            }
        }
    }

    Component {
        id: unblockWithSeedphraseFlowComponent

        UnblockWithSeedphraseFlow {
            id: unblockWithSeedphraseFlow

            property string seedphrase

            isSeedPhraseValid: root.isSeedPhraseValid
            pinSettingState: root.pinSettingState
            keycardPinInfoPageDelay: root.keycardPinInfoPageDelay

            onSeedphraseSubmitted: (seedphrase) => {
                                       unblockWithSeedphraseFlow.seedphrase = seedphrase
                                   }

            onSetPinRequested: (newPin) => {
                                   if (root.loginScreen) {
                                       root.recoverKeycardRequested(newPin, unblockWithSeedphraseFlow.seedphrase)
                                   }
                               }

            onFinished: {
                if (root.loginScreen) {
                } else {
                    d.flow = Onboarding.OnboardingFlow.LoginWithKeycard
                    d.pushOrSkipBiometricsPage()
                }
            }
        }
    }

    Component {
        id: unblockWithPukFlowComponent

        UnblockWithPukFlow {
            id: unblockWithPukFlow

            property string puk
            property string pin

            keycardState: root.keycardState
            pinSettingState: root.pinSettingState
            tryToSetPukFunction: {
                unblockWithPukFlow.puk = puk
            }
            remainingAttempts: root.remainingPukAttempts
            keycardPinInfoPageDelay: root.keycardPinInfoPageDelay

            onSetPinRequested: (newPin) => {
                pin = newPin
                root.setPinRequested(newPin)
            }
            onKeycardFactoryResetRequested: root.push(keycardFactoryResetFlow)

            onFinished: (success) => {
                if (!success)
                   return
                if (root.loginScreen) {
                    root.loginRequested(root.loginScreen.selectedProfileKeyId,
                                        Onboarding.LoginMethod.Keycard, { pin })
                } else {
                    d.flow = Onboarding.OnboardingFlow.LoginWithKeycard
                    d.pushOrSkipBiometricsPage()
                }
            }
        }
    }

    Component {
        id: keycardCreateReplacementFlow

        KeycardCreateReplacementFlow {
            keycardState: root.keycardState
            pinSettingState: root.pinSettingState
            authorizationState: root.authorizationState
            addKeyPairState: root.addKeyPairState

            displayKeycardPromoBanner: root.displayKeycardPromoBanner
            isSeedPhraseValid: root.isSeedPhraseValid

            keycardPinInfoPageDelay: root.keycardPinInfoPageDelay

            onKeycardFactoryResetRequested: root.push(keycardFactoryResetFlow,
                                                      { fromLoginScreen: true })
            onSetPinRequested: (pin) => root.setPinRequested(pin)
            onLoginWithKeycardRequested: root.push(loginWithKeycardFlow)
            onAuthorizationRequested: root.authorizationRequested("") // Pin was saved locally already
            onLoadMnemonicRequested: root.loadMnemonicRequested()

            onCreateProfileWithoutKeycardRequested: {
                root.push(createProfilePage)
            }

            onSeedphraseSubmitted: (seedphrase) => root.seedphraseSubmitted(seedphrase)

            onFinished: d.pushOrSkipBiometricsPage()
        }
    }

    Component {
        id: keycardFactoryResetFlow

        KeycardFactoryResetFlow {
            keycardState: root.keycardState

            onPerformKeycardFactoryResetRequested: root.performKeycardFactoryResetRequested()
            onFinished: root.pop(null)
        }
    }

    OnboardingKeycardStore {
        id: onboardingKeycardStore
    }

    function openKeycardPopup(flow, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson) {
        console.info("onboarding - openning keycard popup for flow: ", flow, " keyUid: ", keyUid, " keycardUid: ", keycardUid, " cardMetadataName: ", cardMetadataName, " cardMetadataWalletAccountsJson: ", cardMetadataWalletAccountsJson)
        keycardManagementPopupComponent.createObject(root, {
            flow: flow,
            keyUid: keyUid || "",
            keycardUid: keycardUid || "",
            cardMetadataName: cardMetadataName || "",
            cardMetadataWalletAccountsJson: cardMetadataWalletAccountsJson || "[]"
        }).open()
    }

    Component {
        id: keycardManagementPopupComponent

        KeycardManagementPopup {
            store: onboardingKeycardStore
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction

            destroyOnClose: true

            onMetadataResult: function(state, kcUid, kUid, statusAvailable, pinAttempts, pukAttempts, slots, name, accountsJson) {
                const args = {
                    keycardState: state,
                    keycardUid: kcUid,
                    keyUid: kUid,
                    keycardStatusAvailable: statusAvailable,
                    remainingPinAttempts: pinAttempts,
                    remainingPukAttempts: pukAttempts,
                    availableSlots: slots,
                    cardMetadataName: name,
                    cardMetadataWalletAccountsJson: accountsJson
                }

                const top = root.currentItem
                if (top && top.objectName === "keycardDetailsPage") {
                    for (const k in args)
                        top[k] = args[k]
                } else {
                    root.push(keycardDetailsComponent, args)
                }
            }

            onKeycardFlowCompletedWithData: function(flow, dataJson) {
                let onboardingFlow = Onboarding.OnboardingFlow.Unknown
                switch (flow) {
                case Constants.keycard.flow.onboardingLoginWithKeycard:
                    onboardingFlow = Onboarding.OnboardingFlow.OnboardingLoginWithKeycard
                    break
                case Constants.keycard.flow.onboardingImportNewKeyPair:
                    onboardingFlow = Onboarding.OnboardingFlow.OnboardingImportNewKeyPair
                    break
                case Constants.keycard.flow.onboardingImportSeedPhrase:
                    onboardingFlow = Onboarding.OnboardingFlow.OnboardingImportSeedPhrase
                    break
                case Constants.keycard.flow.startUsingProfileWithoutKeycard:
                    onboardingFlow = Onboarding.OnboardingFlow.LoginWithLostKeycardSeedphrase
                    break
                default:
                    console.warn("onboarding - unexpected keycard flow:", flow)
                    return
                }
                console.info("onboarding - onbordingFlow: ", onboardingFlow, " keycard-flow: ", flow)
                d.flow = onboardingFlow
                root.skippedBiometricFlow()
                root.onboardingKeycardFlowCompletedWithData(flow, dataJson)
                root.finished(onboardingFlow)                
            }

            onKeycardFlowCompleted: function(flow, kUid, kcUid, success) {
                console.info("onboarding - keycard flow completed, flow: ", flow, " keyUid: ", keyUid, " keycardUid: ", keycardUid," done successfully: ", success)
                if (flow === Constants.keycard.flow.readKeycard) {
                    return
                }
                if (flow === Constants.keycard.flow.onboardingLoginWithKeycard
                        || flow === Constants.keycard.flow.onboardingImportNewKeyPair
                        || flow === Constants.keycard.flow.onboardingImportSeedPhrase) {
                    // successful keycard flow continues in onKeycardFlowCompletedWithData (continue-onboarding flow), unsuccessful returns to previous screen
                    if (!success) {
                        root.pop()
                    }
                    return
                }
                // the user returns to the screen the popup was opened from
                if (root.currentItem && root.currentItem.objectName === "keycardDetailsPage") {
                    root.pop()
                }
            }
        }
    }

    Component {
        id: keycardDetailsComponent

        KeycardDetailsPage {
            objectName: "keycardDetailsPage"

            loginAccountsModel: root.loginAccountsModel

            onLoginWithThisKeycardRequested: {
                const matched = SQUtils.ModelUtils.getByKey(
                    root.loginAccountsModel, "keyUid", keyUid)
                if (matched) {
                    root.profileSelected(matched.keyUid)
                    root.pop(null)
                    return
                }
                root.openKeycardPopup(Constants.keycard.flow.onboardingLoginWithKeycard, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson)
            }
            onImportNewKeyPairAndCreateProfileRequested: {
                root.openKeycardPopup(Constants.keycard.flow.onboardingImportNewKeyPair, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson)
            }
            onImportFromRecoveryPhraseRequested: {
                root.openKeycardPopup(Constants.keycard.flow.onboardingImportSeedPhrase, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson)
            }
            onUnblockWithRecoveryPhraseRequested: {
                root.openKeycardPopup(Constants.keycard.flow.unblockWithRecoveryPhrase, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson)
            }
            onUnblockWithPukRequested: {
                root.openKeycardPopup(Constants.keycard.flow.unblockWithPuk, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson)
            }
            onFactoryResetRequested: {
                root.openKeycardPopup(Constants.keycard.flow.factoryReset, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson)
            }
            onGoBackToLoginRequested: root.pop(null)
        }
    }

    Component {
        id: enableBiometricsPage

        EnableBiometricsPage {
            onEnableBiometricsRequested: (enable) => {
                root.enableBiometricsRequested(enable)
                root.finished(d.flow)
            }
        }
    }

    // popups
    Component {
        id: privacyPolicyPopup

        StatusSimpleTextPopup {
            title: qsTr("Status Software Privacy Policy")
            content {
                textFormat: Text.MarkdownText
            }
            okButtonText: qsTr("Done")
            destroyOnClose: true
            onOpened: content.text = SQUtils.StringUtils.readTextFile(Qt.resolvedUrl("../../../imports/assets/docs/privacy.mdwn"))
            onLinkActivated: (link) => root.linkActivated(link)
        }
    }

    Component {
        id: termsOfUsePopup

        StatusSimpleTextPopup {
            title: qsTr("Status Software Terms of Use")
            content {
                textFormat: Text.MarkdownText
            }
            okButtonText: qsTr("Done")
            destroyOnClose: true
            onOpened: content.text = SQUtils.StringUtils.readTextFile(Qt.resolvedUrl("../../../imports/assets/docs/terms-of-use.mdwn"))
            onLinkActivated: (link) => root.linkActivated(link)
        }
    }

    Component {
        id: thirdpartyServicesPopup

        ThirdpartyServicesPopup {
            isOnboardingFlow: true
            thirdPartyServicesEnabled: root.thirdpartyServicesEnabled

            onToggleThirdpartyServicesEnabledRequested: root.toggleThirdpartyServicesEnabledRequested()
            onOpenDiscussPageRequested: Qt.openUrlExternally(Constants.statusDiscussPageUrl)
            onOpenThirdpartyServicesArticleRequested: Qt.openUrlExternally(Constants.statusThirdpartyServicesArticle)
        }
    }

    Component {
        id: deleteMultiaccountConfirmationDialog

        ConfirmationDialog {
            property string keyUid
            property string username

            objectName: "deleteMultiaccountConfirmationDialog"
            confirmButtonObjectName: "confirmDeleteMultiaccountBtn"
            destroyOnClose: true
            headerSettings.title: qsTr("Remove %1 profile").arg(username)
            confirmationText: qsTr("If you remove %1, all data for this profile will be deleted from this device. To use this profile again, you'll need to reimport it to this device.").arg(username)
            confirmButtonLabel: qsTr("Remove profile")
            showCancelButton: true

            onConfirmButtonClicked: {
                root.deleteMultiaccountRequested(keyUid)
                close()
            }
            onCancelButtonClicked: close()
        }
    }

    Component {
        id: manageProfilesPopup

        StatusDialog {
            implicitWidth: 480
            title: qsTr("Manage profiles")
            objectName: "manageProfilesDialog"
            destroyOnClose: true
            leftPadding: 0
            rightPadding: 0

            ColumnLayout {
                anchors.fill: parent


                StatusListView {
                    objectName: "manageProfilesListView"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: SortFilterProxyModel {
                        sourceModel: root.loginAccountsModel
                        sorters: RoleSorter {
                            roleName: "order"
                        }
                    }
                    implicitHeight: contentHeight
                    spacing: Theme.halfPadding

                    delegate: LoginUserSelectorDelegate {
                        objectName: "manageProfilesDelegate-" + model.keyUid
                        width: ListView.view.width
                        height: d.delegateHeight
                        label: model.username
                        image: model.thumbnailImage
                        colorId: model.colorId
                        keycardCreatedAccount: model.keycardCreatedAccount
                        keycardEnabled: true // We just care to show the icon here
                        managementMode: true
                        onDeleteProfileRequested: d.openDeleteMultiaccountConfirmationDialog(model.keyUid, model.username)
                    }
                }
            }

            footer: StatusDialogFooter {
                dropShadowEnabled: true
                rightButtons: ObjectModel {
                    StatusButton {
                        objectName: "doneBtnManageProfiles"
                        text: qsTr("Done")
                        onClicked: close()
                    }
                }
            }
        }
    }
}
