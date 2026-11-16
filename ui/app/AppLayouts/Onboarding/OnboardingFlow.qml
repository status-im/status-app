pragma ComponentBehavior: Bound

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
    required property bool keycardInitialized
    required property string keycardKeyUID
    required property int syncState
    required property int remainingPinAttempts
    required property int remainingPukAttempts
    required property bool keycardStatusAvailable
    required property int keycardAvailableSlots
    required property bool keycardPairingSupported
    required property bool keycardCertificateTrusted
    required property string keycardCardMetadataName
    required property string keycardCardMetadataWalletAccountsJson

    required property bool biometricsAvailable
    property bool stayLoggedInAvailable: false
    required property bool displayKeycardPromoBanner
    required property bool networkChecksEnabled

    property bool isKeycardEnabled: true
    property int keycardPinInfoPageDelay: 2000
    property string lastSelectedProfileKeyUid

    // functions
    required property var isBiometricsLogin // (string account) => bool
    required property var passwordStrengthScoreFunction
    property var isProfileMigratedToDEKEncryption: (keyUid) => false // (string keyUid) => bool
    required property var isSeedPhraseValid
    required property var isSeedPhraseDuplicate
    required property var validateConnectionString

    readonly property LoginScreen loginScreen: d.loginScreen

    signal changeLanguageRequested(string newLanguageCode)
    signal biometricsRequested(string profileId)
    signal dismissBiometricsRequested
    signal loginRequested(string keyUid, int method, var data)
    signal enableBiometricsRequested(bool enable)
    signal stayLoggedInRequested(bool enabled)
    signal syncProceedWithConnectionString(string connectionString)
    signal seedphraseSubmitted(string seedphrase)
    signal keyUidSubmitted(string keyUid)
    signal setPasswordRequested(string password)
    signal importLocalBackupRequested(url importFilePath)
    signal deleteMultiaccountRequested(string keyUid)

    signal profileSelected(string keyUid)
    signal linkActivated(string link)

    signal finished(int flow)

    signal onboardingKeycardFlowCompletedWithData(string flow, string dataJson)

    // Thirdparty services
    required property bool privacyModeFeatureEnabled
    required property bool thirdpartyServicesEnabled
    signal toggleThirdpartyServicesEnabledRequested()

    signal skippedBiometricFlow()

    function restart() : void {
        if (loginAccountsModel.ModelCount.empty)
            d.replaceDeferred(welcomePage)
        else
            replace(null, loginScreenComponent)
    }

    function setBiometricResponse(secret: string, error: string) : void {
        if (!loginScreen)
            return

        loginScreen.setBiometricResponse(secret, error)
    }

    initialItem: loginAccountsModel.ModelCount.empty ? null : loginScreenComponent

    Component.onCompleted: {
        if (loginAccountsModel.ModelCount.empty)
            d.replaceDeferred(welcomePage, StackView.Immediate)
    }

    Connections {
        target: root.loginAccountsModel?.ModelCount ?? null

        function onCountChanged() : void {
            d.showWelcomePageIfNoProfiles()
        }
    }

    QtObject {
        id: d

        readonly property int delegateHeight: 64

        function pushDeferred(deferred, params = {}) {
            const item = root.push(deferred.component(), Object.assign({}, deferred.properties, params))
            deferred.adopt(item)
            return item
        }

        function replaceDeferred(deferred, operation = StackView.Transition) {
            const item = root.replace(null, deferred.component(), deferred.properties, operation)
            deferred.adopt(item)
            return item
        }

        property int flow
        property LoginScreen loginScreen: null
        property var manageProfilesDialog: null


        function finishCurrentFlow() : void {
            if (d.flow === Onboarding.OnboardingFlow.LoginWithSyncing
                    || d.flow === Onboarding.OnboardingFlow.LoginWithKeycard) {
                root.skippedBiometricFlow()
            }
            root.finished(d.flow)
        }

        function openPrivacyPolicyPopup() : void {
            privacyPolicyPopup.createObject(root).open()
        }

        function openTermsOfUsePopup() : void {
            termsOfUsePopup.createObject(root).open()
        }

        function openThirdpartyServicesPopup() : void {
            thirdpartyServicesPopup.createObject(root).open()
        }

        function openManageProfilesPopup() : void {
            d.manageProfilesDialog = manageProfilesPopup.createObject(root)
            d.manageProfilesDialog.open()
        }

        function showWelcomePageIfNoProfiles() : void {
            if (!root.loginAccountsModel?.ModelCount.empty)
                return

            if (d.manageProfilesDialog)
                d.manageProfilesDialog.close()

            d.replaceDeferred(welcomePage)
        }

        function openDeleteMultiaccountConfirmationDialog(keyUid: string, username: string) : void {
            deleteMultiaccountConfirmationDialog.createObject(root, { keyUid, username }).open()
        }
    }

    SQUtils.DeferredComponent {
        id: welcomePage

        module: "AppLayouts.Onboarding.pages"
        typeName: "WelcomePage"
        properties: ({
            availableLanguages: Qt.binding(() => root.availableLanguages),
            currentLanguage: Qt.binding(() => root.currentLanguage),
            privacyModeFeatureEnabled: Qt.binding(() => root.privacyModeFeatureEnabled),
            thirdpartyServicesEnabled: Qt.binding(() => root.thirdpartyServicesEnabled)
        })
        onCreated: page => {
            page.changeLanguageRequested.connect(newLanguageCode => root.changeLanguageRequested(newLanguageCode))
            page.createProfileRequested.connect(() => d.pushDeferred(createProfilePage))
            page.loginRequested.connect(() => d.pushDeferred(loginPage))
            page.privacyPolicyRequested.connect(() => d.openPrivacyPolicyPopup())
            page.termsOfUseRequested.connect(() => d.openTermsOfUsePopup())
            page.openThirdpartyServicesInfoPopupRequested.connect(() => d.openThirdpartyServicesPopup())
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
            onOnboardingCreateProfileFlowRequested: d.pushDeferred(createProfilePage)
            onOnboardingLoginFlowRequested: d.pushDeferred(loginPage)
            onLostKeycardFlowRequested: {
                root.keyUidSubmitted(loginScreen.selectedProfileKeyId)
                d.pushDeferred(keycardLostPage)
            }
            onOnboardingManageProfilesFlowRequested: d.openManageProfilesPopup()

            onUnblockKeycardRequested: {
                const stateStr = root.keycardState === Onboarding.KeycardState.BlockedPIN
                                 ? Constants.keycard.state.blockedPIN
                                 : Constants.keycard.state.blockedPUK
                root.push(keycardDetailsComponent, {
                    keycardState: stateStr,
                    keycardUid: root.keycardUID,
                    keycardInitialized: root.keycardInitialized,
                    keyUid: root.keycardKeyUID,
                    keycardStatusAvailable: root.keycardStatusAvailable,
                    remainingPinAttempts: root.remainingPinAttempts,
                    remainingPukAttempts: root.remainingPukAttempts,
                    availableSlots: root.keycardAvailableSlots,
                    pairingSupported: root.keycardPairingSupported,
                    certificateTrusted: root.keycardCertificateTrusted,
                    cardMetadataName: root.keycardCardMetadataName,
                    cardMetadataWalletAccountsJson: root.keycardCardMetadataWalletAccountsJson
                })
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

    SQUtils.DeferredComponent {
        id: keycardLostPage

        module: "AppLayouts.Onboarding.pages"
        typeName: "KeycardLostPage"

        onCreated: page => {
            const keyUid = () => root.loginScreen ? root.loginScreen.selectedProfileKeyId : ""
            page.readSpareKeycardRequested.connect(() => {
                root.openKeycardPopup(Constants.keycard.flow.readKeycard, keyUid(), "", "", "[]", false)
            })
            page.stopUsingKeycardForProfileRequested.connect(() => {
                root.openKeycardPopup(Constants.keycard.flow.startUsingProfileWithoutKeycard, keyUid(), "", "", "[]", false)
            })
        }
    }

    SQUtils.DeferredComponent {
        id: createProfilePage

        module: "AppLayouts.Onboarding.pages"
        typeName: "CreateProfilePage"
        properties: ({ isKeycardEnabled: Qt.binding(() => root.isKeycardEnabled) })

        onCreated: page => {
            page.createProfileWithPasswordRequested.connect(() => d.pushDeferred(createNewProfileFlow))
            page.createProfileWithSeedphraseRequested.connect(() => {
                d.flow = Onboarding.OnboardingFlow.CreateProfileWithSeedphrase
                d.pushDeferred(useRecoveryPhraseFlow,
                               { type: RecoveryPhraseFlowType.Type.NewProfile })
            })
            page.createProfileWithEmptyKeycardRequested.connect(() => {
                root.openKeycardPopup(Constants.keycard.flow.readKeycard, "", "", "", "[]", false)
            })
        }
    }

    SQUtils.DeferredComponent {
        id: loginPage

        module: "AppLayouts.Onboarding.pages"
        typeName: "NewAccountLoginPage"
        properties: ({
            networkChecksEnabled: Qt.binding(() => root.networkChecksEnabled),
            isKeycardEnabled: Qt.binding(() => root.isKeycardEnabled),
            thirdpartyServicesEnabled: Qt.binding(() => root.thirdpartyServicesEnabled)
        })

        onCreated: page => {
            page.loginWithSyncingRequested.connect(() => d.pushDeferred(logInBySyncingFlow))
            page.loginWithKeycardRequested.connect(() => {
                root.openKeycardPopup(Constants.keycard.flow.readKeycard, "", "", "", "[]", false)
            })
            page.loginWithSeedphraseRequested.connect(() => {
                d.flow = Onboarding.OnboardingFlow.LoginWithSeedphrase
                d.pushDeferred(useRecoveryPhraseFlow,
                               { type: RecoveryPhraseFlowType.Type.Login })
            })
        }
    }

    Component {
        id: keycardDetailsComponent

        KeycardDetailsPage {
            id: keycardDetailsPage
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
                root.openKeycardPopup(Constants.keycard.flow.onboardingLoginWithKeycard, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson,
                                      keycardDetailsPage.keycardInitialized) // not root.keycardInitialized
            }
            onImportNewKeyPairAndCreateProfileRequested: {
                root.openKeycardPopup(Constants.keycard.flow.onboardingImportNewKeyPair, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson,
                                      keycardDetailsPage.keycardInitialized) // not root.keycardInitialized
            }
            onImportFromRecoveryPhraseRequested: {
                root.openKeycardPopup(Constants.keycard.flow.onboardingImportSeedPhrase, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson,
                                      keycardDetailsPage.keycardInitialized) // not root.keycardInitialized
            }
            onUnblockWithRecoveryPhraseRequested: {
                root.openKeycardPopup(Constants.keycard.flow.unblockWithRecoveryPhrase, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson,
                                      keycardDetailsPage.keycardInitialized) // not root.keycardInitialized
            }
            onUnblockWithPukRequested: {
                root.openKeycardPopup(Constants.keycard.flow.unblockWithPuk, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson,
                                      keycardDetailsPage.keycardInitialized) // not root.keycardInitialized
            }
            onFactoryResetRequested: {
                root.openKeycardPopup(Constants.keycard.flow.factoryReset, keyUid, keycardUid, cardMetadataName, cardMetadataWalletAccountsJson,
                                      keycardDetailsPage.keycardInitialized) // not root.keycardInitialized
            }
            onGoBackToLoginRequested: root.pop(null)
        }
    }

    SQUtils.DeferredComponent {
        id: createNewProfileFlow

        source: Qt.resolvedUrl("CreateNewProfileFlow.qml")
        properties: ({
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction,
            stayLoggedInAvailable: Qt.binding(() => root.stayLoggedInAvailable),
            biometricsAvailable: Qt.binding(() => root.biometricsAvailable)
        })

        onCreated: flow => {
            flow.stayLoggedInRequested.connect(enabled => root.stayLoggedInRequested(enabled))
            flow.enableBiometricsRequested.connect(enable => root.enableBiometricsRequested(enable))
            flow.finished.connect(password => {
                root.setPasswordRequested(password)
                d.flow = Onboarding.OnboardingFlow.CreateProfileWithPassword
                d.finishCurrentFlow()
            })
        }
    }

    SQUtils.DeferredComponent {
        id: useRecoveryPhraseFlow

        source: Qt.resolvedUrl("UseRecoveryPhraseFlow.qml")
        properties: ({
            isSeedPhraseValid: root.isSeedPhraseValid,
            isSeedPhraseDuplicate: root.isSeedPhraseDuplicate,
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction,
            stayLoggedInAvailable: Qt.binding(() => root.stayLoggedInAvailable),
            biometricsAvailable: Qt.binding(() => root.biometricsAvailable),
            isProfileMigratedToDEKEncryption: Qt.binding(() => {
                const keyUid = root.loginScreen ? root.loginScreen.selectedProfileKeyId : ""
                return keyUid ? root.isProfileMigratedToDEKEncryption(keyUid) : false
            })
        })

        onCreated: flow => {
            flow.seedphraseSubmitted.connect(seedphrase => root.seedphraseSubmitted(seedphrase))
            flow.setPasswordRequested.connect(password => root.setPasswordRequested(password))
            flow.stayLoggedInRequested.connect(enabled => root.stayLoggedInRequested(enabled))
            flow.enableBiometricsRequested.connect(enable => root.enableBiometricsRequested(enable))
            flow.importLocalBackupRequested.connect(importFilePath => root.importLocalBackupRequested(importFilePath))
            flow.finished.connect(() => d.finishCurrentFlow())
        }
    }

    SQUtils.DeferredComponent {
        id: logInBySyncingFlow

        source: Qt.resolvedUrl("LoginBySyncingFlow.qml")
        properties: ({
            validateConnectionString: root.validateConnectionString,
            syncState: Qt.binding(() => root.syncState)
        })

        onCreated: flow => {
            flow.syncProceedWithConnectionString.connect(
                connectionString => root.syncProceedWithConnectionString(connectionString))
            flow.loginWithSeedphraseRequested.connect(() => {
                d.flow = Onboarding.OnboardingFlow.LoginWithSeedphrase

                d.pushDeferred(useRecoveryPhraseFlow,
                               { type: RecoveryPhraseFlowType.Type.Login })
            })
            flow.finished.connect(() => {
                d.flow = Onboarding.OnboardingFlow.LoginWithSyncing
                d.finishCurrentFlow()
            })
        }
    }

    OnboardingKeycardStore {
        id: onboardingKeycardStore
    }

    function openKeycardPopup(flow: string, keyUid: string, keycardUid: string, cardMetadataName: string, cardMetadataWalletAccountsJson: string,
                              keycardInitialized: bool) : void {
        console.info("onboarding - openning keycard popup for flow: ", flow, " keyUid: ", keyUid, " keycardUid: ", keycardUid, " cardMetadataName: ", cardMetadataName, " cardMetadataWalletAccountsJson: ", cardMetadataWalletAccountsJson)
        keycardManagementPopupComponent.createObject(root, {
            flow: flow,
            keyUid: keyUid || "",
            keycardUid: keycardUid || "",
            keycardInitialized: keycardInitialized,
            cardMetadataName: cardMetadataName || "",
            cardMetadataWalletAccountsJson: cardMetadataWalletAccountsJson || "[]"
        }).open()
    }

    SQUtils.DeferredComponent {
        id: keycardManagementPopupComponent

        module: "shared.popups.keycard_new"
        typeName: "KeycardManagementPopup"
        properties: ({
            store: onboardingKeycardStore,
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction,
            destroyOnClose: true
        })

        onCreated: popup => {
            popup.metadataResult.connect(keycardInfo => {
                const top = root.currentItem
                if (top && top.objectName === "keycardDetailsPage") {
                    for (const k in keycardInfo)
                        top[k] = keycardInfo[k]
                } else {
                    root.push(keycardDetailsComponent, keycardInfo)
                }
            })

            popup.keycardFlowCompletedWithData.connect((flow, dataJson) => {
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
            })

            popup.keycardFlowCompleted.connect((flow, kUid, kcUid, success) => {
                console.info("onboarding - keycard flow completed, flow: ", flow, " keyUid: ", popup.keyUid, " keycardUid: ", popup.keycardUid," done successfully: ", success)
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
            })
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

    SQUtils.DeferredComponent {
        id: thirdpartyServicesPopup

        source: Qt.resolvedUrl("../../../imports/shared/popups/ThirdpartyServicesPopup.qml")
        properties: ({
            isOnboardingFlow: true,
            thirdPartyServicesEnabled: Qt.binding(() => root.thirdpartyServicesEnabled)
        })
        onCreated: popup => {
            popup.toggleThirdpartyServicesEnabledRequested.connect(() => root.toggleThirdpartyServicesEnabledRequested())
            popup.openDiscussPageRequested.connect(() => Qt.openUrlExternally(Constants.statusDiscussPageUrl))
            popup.openThirdpartyServicesArticleRequested.connect(() => Qt.openUrlExternally(Constants.statusThirdpartyServicesArticle))
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
                        id: profileDelegate

                        required property var model

                        objectName: "manageProfilesDelegate-" + profileDelegate.model.keyUid
                        keyUid: profileDelegate.model.keyUid
                        width: ListView.view.width
                        height: d.delegateHeight
                        label: profileDelegate.model.username
                        image: profileDelegate.model.thumbnailImage
                        colorId: profileDelegate.model.colorId
                        keycardCreatedAccount: profileDelegate.model.keycardCreatedAccount
                        keycardEnabled: true // We just care to show the icon here
                        managementMode: true
                        onDeleteProfileRequested: d.openDeleteMultiaccountConfirmationDialog(profileDelegate.model.keyUid, profileDelegate.model.username)
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
