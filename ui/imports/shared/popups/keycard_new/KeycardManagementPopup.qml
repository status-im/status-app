import QtQuick
import QtQuick.Controls
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Backpressure
import StatusQ.Controls
import StatusQ.Popups.Dialog

import utils

import shared.popups.auth_sign_base 1.0

import "states"
import "stores"

StatusDialog {
    id: root

    required property string flow
    required property string keycardUid
    required property string keyUid

    required property string cardMetadataName
    required property string cardMetadataWalletAccountsJson

    required property QtObject store // shared between onboarding and the main app parts

    property var emojiPopup: null

    property var passwordStrengthScoreFunction: (password) => { console.error("passwordStrengthScoreFunction: IMPLEMENT ME") }

    signal metadataResult(string keycardState, string keycardUid, string keyUid, bool keycardStatusAvailable, int remainingPinAttempts,
                          int remainingPukAttempts, int availableSlots, string cardMetadataName, string cardMetadataWalletAccountsJson)
    signal keycardFlowCompleted(string flow, string keyUid, string keycardUid, bool success)

    signal keycardFlowCompletedWithData(string flow, string dataJson)

    width: Constants.keycard.general.popupWidth
    padding: Theme.halfPadding
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    title: {
        switch(root.flow) {
        case Constants.keycard.flow.readKeycard:
            return qsTr("Read Keycard")
        case Constants.keycard.flow.factoryReset:
            return qsTr("Factory reset")
        case Constants.keycard.flow.importSeedPhrase:
            return qsTr("Import key pair from recovery phrase")
        case Constants.keycard.flow.importNewKeyPair:
            return qsTr("Import a new key pair to Keycard")
        case Constants.keycard.flow.moveKeyPair:
            return qsTr("Move key pair to Keycard")
        case Constants.keycard.flow.moveProfileKeyPair:
            return qsTr("Move profile key pair to Keycard")
        case Constants.keycard.flow.addKeyPairToStatus:
            return qsTr("Add key pair to Status")
        case Constants.keycard.flow.stopUsingKeycard:
            return qsTr("Stop using Keycard for key pair")
        case Constants.keycard.flow.stopUsingKeycardForProfile:
            return qsTr("Stop using Keycard for profile key pair")
        case Constants.keycard.flow.startUsingProfileWithoutKeycard:
            return qsTr("Start using profile without Keycard")
        case Constants.keycard.flow.changePin:
            return qsTr("Change Keycard PIN")
        case Constants.keycard.flow.setOrChangePuk:
            return qsTr("Set or change PUK")
        case Constants.keycard.flow.rename:
            return qsTr("Rename Keycard")
        case Constants.keycard.flow.unblockWithPuk:
            return qsTr("Unblock with PUK")
        case Constants.keycard.flow.unblockWithRecoveryPhrase:
            return qsTr("Unblock with recovery phrase")
        case Constants.keycard.flow.onboardingLoginWithKeycard:
            return qsTr("Log in with this Keycard")
        case Constants.keycard.flow.onboardingImportNewKeyPair:
            return qsTr("Import a new key pair to Keycard")
        case Constants.keycard.flow.onboardingImportSeedPhrase:
            return qsTr("Import a key pair from recovery phrase")
        default:
            return qsTr("Keycard Flow")
        }
    }

    enum FlowStep {
        EnterPin,
        EnterNewPin,
        RepeatPin,
        EnterSeedPhrase,
        EnterKeyPairName,
        ManageAccounts,
        Importing,
        Migrating,
        AddingKeyPair,
        DisplaySeedPhrase,
        ConfirmSeedPhraseWords,
        SelectKeyPair,
        InsertEmptyKeycard,
        ConfirmKeyPair,
        CreatePassword,
        ConfirmPassword,
        Stopping,
        ChangingPin,
        CreatePuk,
        RepeatPuk,
        ChangingPuk,
        RenameInput,
        RenamingKeycard,
        EnterPuk,
        UnblockingKeycard,
        OnboardingMixedFlowSuccess // added to easier deal with keycard-related flows while Onboarding (keycard part is just one step of the entire flow, clicking "Continue" button emits keycardFlowCompletedWithData)
    }

    QtObject {
        id: d

        readonly property bool keycardHasOnlyPinSet: !!root.keycardUid && !root.keyUid

        property bool keycardInteractionCompleted: false
        property bool processing: false
        property bool success: false
        property bool mixedFlowSuccess: false
        property string error: ""

        property bool factoryResetConfirmationChecked: false

        property int currentStep: {
            switch(root.flow) {
            case Constants.keycard.flow.moveKeyPair:
                return KeycardManagementPopup.FlowStep.SelectKeyPair
            case Constants.keycard.flow.moveProfileKeyPair:
                return KeycardManagementPopup.FlowStep.SelectKeyPair
            case Constants.keycard.flow.stopUsingKeycard:
                return KeycardManagementPopup.FlowStep.ConfirmKeyPair
            case Constants.keycard.flow.stopUsingKeycardForProfile:
                return KeycardManagementPopup.FlowStep.ConfirmKeyPair
            case Constants.keycard.flow.startUsingProfileWithoutKeycard:
                return KeycardManagementPopup.FlowStep.EnterSeedPhrase
            case Constants.keycard.flow.addKeyPairToStatus:
                return KeycardManagementPopup.FlowStep.EnterPin
            case Constants.keycard.flow.changePin:
                return KeycardManagementPopup.FlowStep.EnterPin
            case Constants.keycard.flow.setOrChangePuk:
                return KeycardManagementPopup.FlowStep.EnterPin
            case Constants.keycard.flow.rename:
                return KeycardManagementPopup.FlowStep.EnterPin
            case Constants.keycard.flow.unblockWithPuk:
                return KeycardManagementPopup.FlowStep.EnterNewPin
            case Constants.keycard.flow.unblockWithRecoveryPhrase:
                return KeycardManagementPopup.FlowStep.EnterNewPin
            case Constants.keycard.flow.onboardingLoginWithKeycard:
                return KeycardManagementPopup.FlowStep.EnterPin
            default:
                return d.keycardHasOnlyPinSet
                    ? KeycardManagementPopup.FlowStep.EnterPin
                    : KeycardManagementPopup.FlowStep.EnterNewPin
            }
        }

        property string currentPin: ""
        property string newPin: ""
        property string newPuk: ""
        property string puk: ""
        property string newName: ""
        property bool pinMismatch: false
        property string seedPhrase: ""
        property bool seedPhraseRevealed: false
        property string seedPhraseKeyUid: ""
        property bool keyPairKnown: false
        property string keyPairName: ""
        property string accountPathsJson: "[]"

        property string moveKeyPairSelectedKeyUid: ""
        property string moveKeyPairSelectedKeyPairName: ""
        property bool moveKeyPairUnderstandChecked: false

        property string authenticationPassword: ""

        property bool stopUsingUnderstandChecked: false
        property string newStatusPassword: ""

        property string onboardingResultDataJson: ""

        function componentForStep(step) {
            switch (step) {
            case KeycardManagementPopup.FlowStep.EnterPin:
                return enterPinComponent
            case KeycardManagementPopup.FlowStep.EnterNewPin:
                return createPinComponent
            case KeycardManagementPopup.FlowStep.RepeatPin:
                return repeatPinComponent
            case KeycardManagementPopup.FlowStep.EnterSeedPhrase:
                if (root.flow === Constants.keycard.flow.moveKeyPair)
                    return moveKeyPairEnterSeedPhraseComponent
                if (root.flow === Constants.keycard.flow.moveProfileKeyPair)
                    return moveProfileKeyPairEnterSeedPhraseComponent
                if (root.flow === Constants.keycard.flow.stopUsingKeycard)
                    return stopUsingEnterSeedPhraseComponent
                if (root.flow === Constants.keycard.flow.stopUsingKeycardForProfile)
                    return stopUsingForProfileEnterSeedPhraseComponent
                if (root.flow === Constants.keycard.flow.startUsingProfileWithoutKeycard)
                    return startUsingProfileWithoutKeycardEnterSeedPhraseComponent
                if (root.flow === Constants.keycard.flow.unblockWithRecoveryPhrase)
                    return unblockWithRecoveryPhraseEnterSeedPhraseComponent
                if (root.flow === Constants.keycard.flow.onboardingImportSeedPhrase)
                    return onboardingEnterSeedPhraseComponent
                return enterSeedPhraseComponent
            case KeycardManagementPopup.FlowStep.EnterKeyPairName:
                return enterKeyPairNameComponent
            case KeycardManagementPopup.FlowStep.ManageAccounts:
                return manageKeyPairAccountsComponent
            case KeycardManagementPopup.FlowStep.DisplaySeedPhrase:
                return seedPhraseDisplayComponent
            case KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords:
                return confirmSeedPhraseWordsComponent
            case KeycardManagementPopup.FlowStep.SelectKeyPair:
                return root.flow === Constants.keycard.flow.moveProfileKeyPair
                    ? selectProfileKeyPairComponent
                    : selectKeyPairComponent
            case KeycardManagementPopup.FlowStep.InsertEmptyKeycard:
                return insertEmptyKeycardComponent
            case KeycardManagementPopup.FlowStep.ConfirmKeyPair:
                return confirmKeyPairForStopUsingComponent
            case KeycardManagementPopup.FlowStep.CreatePassword:
                return createPasswordComponent
            case KeycardManagementPopup.FlowStep.ConfirmPassword:
                return confirmPasswordComponent
            case KeycardManagementPopup.FlowStep.CreatePuk:
                return createPukComponent
            case KeycardManagementPopup.FlowStep.RepeatPuk:
                return repeatPukComponent
            case KeycardManagementPopup.FlowStep.RenameInput:
                return renameKeycardComponent
            case KeycardManagementPopup.FlowStep.EnterPuk:
                return enterPukComponent
            default: return null
            }
        }

        function startKeycardReading(pin) {
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startGetMetadata(pin)
                                    })
        }

        function startFactoryReset() {
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startFactoryReset(root.keycardUid)
                                    })
        }

        function startImportingKeyPair() {
            d.currentStep = KeycardManagementPopup.FlowStep.Importing
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startImportingKeyPair(d.newPin,
                                                                         d.seedPhrase,
                                                                         d.keyPairName,
                                                                         d.accountPathsJson)
                                    })
        }

        function startMigratingNonProfileKeypairToKeycard() {
            d.currentStep = KeycardManagementPopup.FlowStep.Migrating
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startMigratingNonProfileKeypairToKeycard(d.authenticationPassword,
                                                                                            d.newPin,
                                                                                            d.seedPhrase)
                                    })
        }

        function startMigratingProfileKeypairToKeycard() {
            d.currentStep = KeycardManagementPopup.FlowStep.Migrating
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startMigratingProfileKeypairToKeycard(d.authenticationPassword,
                                                                                         d.newPin,
                                                                                         d.seedPhrase)
                                    })
        }

        function startAddingKeyPairToStatus() {
            d.currentStep = KeycardManagementPopup.FlowStep.AddingKeyPair
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startAddingKeyPairToStatusFromKeycard(d.newPin,
                                                                                         root.keyUid,
                                                                                         d.keyPairName,
                                                                                         d.accountPathsJson)
                                    })
        }

        function startStopUsingKeycardForKeyPair() {
            d.currentStep = KeycardManagementPopup.FlowStep.Stopping
            d.keycardInteractionCompleted = true
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startStopUsingKeycardForKeyPair(root.keyUid,
                                                                                   d.seedPhrase,
                                                                                   d.authenticationPassword)
                                    })
        }

        function startStopUsingKeycardForProfileKeyPair() {
            d.currentStep = KeycardManagementPopup.FlowStep.Stopping
            d.keycardInteractionCompleted = true
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startStopUsingKeycardForProfileKeyPair(d.seedPhrase,
                                                                                          d.newStatusPassword)
                                    })
        }

        function startChangeKeycardPIN() {
            d.currentStep = KeycardManagementPopup.FlowStep.ChangingPin
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startChangeKeycardPIN(d.currentPin, d.newPin)
                                    })
        }

        function startChangeKeycardPUK() {
            d.currentStep = KeycardManagementPopup.FlowStep.ChangingPuk
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startChangeKeycardPUK(d.currentPin, d.newPuk)
                                    })
        }

        function startRenameKeycard() {
            d.currentStep = KeycardManagementPopup.FlowStep.RenamingKeycard
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startRenameKeycard(d.currentPin,
                                                                      d.newName,
                                                                      root.cardMetadataWalletAccountsJson)
                                    })
        }

        function startUnblockKeycardUsingPuk() {
            d.currentStep = KeycardManagementPopup.FlowStep.UnblockingKeycard
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startUnblockKeycardUsingPuk(d.newPin, d.puk)
                                    })
        }

        function startUnblockKeycardUsingRecoveryPhrase() {
            d.currentStep = KeycardManagementPopup.FlowStep.UnblockingKeycard
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startUnblockKeycardUsingRecoveryPhrase(d.newPin,
                                                                                          d.seedPhrase,
                                                                                          root.cardMetadataName,
                                                                                          root.cardMetadataWalletAccountsJson)
                                    })
        }

        function startOnboardingLoginWithKeycard() {
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        root.store.startAsyncLogin(root.keyUid, d.currentPin, true)
                                    })
        }

        function startOnboardingImportngKeyPair() {
            d.currentStep = KeycardManagementPopup.FlowStep.Importing
            d.processing = true
            Backpressure.setTimeout(this, 500, () => {
                                        // default wallet account only
                                        const accounts = [{
                                                              name: "",
                                                              colorId: "",
                                                              emoji: "",
                                                              path: Constants.walletRootPath + "/0" // default wallet account path
                                                          }]
                                        root.store.startImportingKeyPair(d.newPin, d.seedPhrase, d.keyPairName, JSON.stringify(accounts))
                                    })
        }

        function nextStep() {
            if (d.currentStep === KeycardManagementPopup.FlowStep.InsertEmptyKeycard) {
                d.startMigratingNonProfileKeypairToKeycard()
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.SelectKeyPair) {
                d.currentStep = d.keycardHasOnlyPinSet
                    ? KeycardManagementPopup.FlowStep.EnterPin
                    : KeycardManagementPopup.FlowStep.EnterNewPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmKeyPair) {
                d.currentStep = KeycardManagementPopup.FlowStep.EnterSeedPhrase
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword) {
                d.currentStep = KeycardManagementPopup.FlowStep.ConfirmPassword
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword) {
                if (root.flow === Constants.keycard.flow.startUsingProfileWithoutKeycard) {
                    d.onboardingResultDataJson = JSON.stringify({
                        flow: root.flow,
                        keyUid: root.keyUid,
                        seedPhrase: d.seedPhrase,
                        password: d.newStatusPassword
                    })
                    d.success = true
                    d.currentStep = KeycardManagementPopup.FlowStep.OnboardingMixedFlowSuccess
                    return
                }
                if (root.flow === Constants.keycard.flow.stopUsingKeycardForProfile) {
                    d.startStopUsingKeycardForProfileKeyPair()
                } else {
                    d.startStopUsingKeycardForKeyPair()
                }
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterPin) {
                if (root.flow === Constants.keycard.flow.onboardingLoginWithKeycard) {
                    d.startOnboardingLoginWithKeycard()
                    return
                }
                if (root.flow === Constants.keycard.flow.importNewKeyPair) {
                    d.seedPhrase = root.store.generateMnemonic()
                    d.currentStep = KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                    return
                }
                if (root.flow === Constants.keycard.flow.moveProfileKeyPair && !root.store.isMnemonicBackedUp()) {
                    d.seedPhrase = root.store.getMnemonic()
                    d.currentStep = KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                    return
                }
                if (root.flow === Constants.keycard.flow.addKeyPairToStatus) {
                    d.currentStep = KeycardManagementPopup.FlowStep.EnterKeyPairName
                    return
                }
                if (root.flow === Constants.keycard.flow.changePin) {
                    d.currentStep = KeycardManagementPopup.FlowStep.EnterNewPin
                    return
                }
                if (root.flow === Constants.keycard.flow.setOrChangePuk) {
                    d.currentStep = KeycardManagementPopup.FlowStep.CreatePuk
                    return
                }
                if (root.flow === Constants.keycard.flow.rename) {
                    d.currentStep = KeycardManagementPopup.FlowStep.RenameInput
                    return
                }

                d.currentStep = KeycardManagementPopup.FlowStep.EnterSeedPhrase
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.RenameInput) {
                d.startRenameKeycard()
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.CreatePuk) {
                d.currentStep = KeycardManagementPopup.FlowStep.RepeatPuk
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPuk) {
                d.startChangeKeycardPUK()
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterNewPin) {
                d.currentStep = KeycardManagementPopup.FlowStep.RepeatPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin) {
                if (root.flow === Constants.keycard.flow.changePin) {
                    d.startChangeKeycardPIN()
                    return
                }
                if (root.flow === Constants.keycard.flow.unblockWithPuk) {
                    d.currentStep = KeycardManagementPopup.FlowStep.EnterPuk
                    return
                }
                if (root.flow === Constants.keycard.flow.unblockWithRecoveryPhrase) {
                    d.currentStep = KeycardManagementPopup.FlowStep.EnterSeedPhrase
                    return
                }
                if (root.flow === Constants.keycard.flow.importNewKeyPair
                        || root.flow === Constants.keycard.flow.onboardingImportNewKeyPair) {
                    d.seedPhrase = root.store.generateMnemonic()
                    d.currentStep = KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                    return
                }
                if (root.flow === Constants.keycard.flow.moveProfileKeyPair && !root.store.isMnemonicBackedUp()) {
                    d.seedPhrase = root.store.getMnemonic()
                    d.currentStep = KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                    return
                }

                d.currentStep = KeycardManagementPopup.FlowStep.EnterSeedPhrase
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterPuk) {
                d.startUnblockKeycardUsingPuk()
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase) {
                if (root.flow === Constants.keycard.flow.moveKeyPair) {
                    Global.openAuthenticationPopup(Constants.keycard.flow.moveKeyPair, root.store.userProfileKeyUid, false)
                    return
                }
                if (root.flow === Constants.keycard.flow.moveProfileKeyPair) {
                    Global.openAuthenticationPopup(Constants.keycard.flow.moveProfileKeyPair, root.store.userProfileKeyUid, false)
                    return
                }
                if (root.flow === Constants.keycard.flow.stopUsingKeycard) {
                    Global.openAuthenticationPopup(Constants.keycard.flow.stopUsingKeycard, root.store.userProfileKeyUid, false)
                    return
                }
                if (root.flow === Constants.keycard.flow.stopUsingKeycardForProfile
                        || root.flow === Constants.keycard.flow.startUsingProfileWithoutKeycard) {
                    d.currentStep = KeycardManagementPopup.FlowStep.CreatePassword
                    return
                }
                if (root.flow === Constants.keycard.flow.unblockWithRecoveryPhrase) {
                    d.startUnblockKeycardUsingRecoveryPhrase()
                    return
                }
                if (root.flow === Constants.keycard.flow.onboardingImportSeedPhrase) {
                    d.startOnboardingImportngKeyPair()
                    return
                }

                if (d.keyPairKnown) {
                    d.startImportingKeyPair()
                    return
                }

                d.currentStep = KeycardManagementPopup.FlowStep.EnterKeyPairName
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase) {
                d.currentStep = KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords) {
                if (root.flow === Constants.keycard.flow.moveProfileKeyPair) {
                    Global.openAuthenticationPopup(Constants.keycard.flow.moveProfileKeyPair, root.store.userProfileKeyUid, false)
                    return
                }
                d.seedPhraseKeyUid = root.store.getKeyUidForSeedPhrase(d.seedPhrase)
                if (root.flow === Constants.keycard.flow.onboardingImportNewKeyPair) {
                    d.startOnboardingImportngKeyPair()
                    return
                }
                d.currentStep = KeycardManagementPopup.FlowStep.EnterKeyPairName
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName) {
                d.currentStep = KeycardManagementPopup.FlowStep.ManageAccounts
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts) {
                if (root.flow === Constants.keycard.flow.addKeyPairToStatus) {
                    d.startAddingKeyPairToStatus()
                    return
                }
                d.startImportingKeyPair()
                return
            }
        }

        function previousStep() {
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterNewPin
                    && (root.flow === Constants.keycard.flow.moveKeyPair
                        || root.flow === Constants.keycard.flow.moveProfileKeyPair)) {
                d.currentStep = KeycardManagementPopup.FlowStep.SelectKeyPair
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterNewPin
                    && root.flow === Constants.keycard.flow.changePin) {
                d.newPin = ""
                d.currentStep = KeycardManagementPopup.FlowStep.EnterPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.CreatePuk
                    && root.flow === Constants.keycard.flow.setOrChangePuk) {
                d.newPuk = ""
                d.currentStep = KeycardManagementPopup.FlowStep.EnterPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPuk
                    && root.flow === Constants.keycard.flow.setOrChangePuk) {
                d.newPuk = ""
                d.currentStep = KeycardManagementPopup.FlowStep.CreatePuk
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.RenameInput
                    && root.flow === Constants.keycard.flow.rename) {
                d.newName = ""
                d.currentStep = KeycardManagementPopup.FlowStep.EnterPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterPuk
                    && root.flow === Constants.keycard.flow.unblockWithPuk) {
                d.puk = ""
                d.currentStep = KeycardManagementPopup.FlowStep.RepeatPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin) {
                d.newPin = ""
                d.pinMismatch = false
                d.currentStep = KeycardManagementPopup.FlowStep.EnterNewPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterPin
                    && (root.flow === Constants.keycard.flow.moveKeyPair
                        || root.flow === Constants.keycard.flow.moveProfileKeyPair)) {
                d.newPin = ""
                d.currentStep = KeycardManagementPopup.FlowStep.SelectKeyPair
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase) {
                if (root.flow === Constants.keycard.flow.stopUsingKeycard
                        || root.flow === Constants.keycard.flow.stopUsingKeycardForProfile) {
                    d.currentStep = KeycardManagementPopup.FlowStep.ConfirmKeyPair
                    return
                }
                if (root.flow === Constants.keycard.flow.unblockWithRecoveryPhrase) {
                    d.seedPhrase = ""
                    d.seedPhraseKeyUid = ""
                    d.currentStep = KeycardManagementPopup.FlowStep.RepeatPin
                    return
                }
                d.newPin = ""
                d.pinMismatch = false
                d.seedPhrase = ""
                d.seedPhraseKeyUid = ""
                d.currentStep = d.keycardHasOnlyPinSet
                    ? KeycardManagementPopup.FlowStep.EnterPin
                    : KeycardManagementPopup.FlowStep.EnterNewPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword) {
                d.currentStep = KeycardManagementPopup.FlowStep.EnterSeedPhrase
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword) {
                d.currentStep = KeycardManagementPopup.FlowStep.CreatePassword
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase) {
                d.seedPhrase = ""
                d.seedPhraseRevealed = false
                d.newPin = ""
                d.pinMismatch = false
                if (d.keycardHasOnlyPinSet) {
                    d.currentStep = KeycardManagementPopup.FlowStep.EnterPin
                    return
                }
                d.currentStep = KeycardManagementPopup.FlowStep.EnterNewPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords) {
                d.currentStep = KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName) {
                d.keyPairName = ""
                if (root.flow === Constants.keycard.flow.importNewKeyPair) {
                    d.seedPhraseKeyUid = ""
                    d.currentStep = KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords
                    return
                }
                if (root.flow === Constants.keycard.flow.addKeyPairToStatus) {
                    d.newPin = ""
                    d.currentStep = KeycardManagementPopup.FlowStep.EnterPin
                    return
                }
                d.currentStep = KeycardManagementPopup.FlowStep.EnterSeedPhrase
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts) {
                d.accountPathsJson = "[]"
                d.currentStep = KeycardManagementPopup.FlowStep.EnterKeyPairName
                return
            }
        }
    }

    Connections {
        target: root.store
        ignoreUnknownSignals: true

        function onKeycardInteractionSuccessfullyCompleted() {
            switch(root.flow) {
            case Constants.keycard.flow.importSeedPhrase:
            case Constants.keycard.flow.importNewKeyPair:
                d.currentStep = KeycardManagementPopup.FlowStep.Importing
                break
            case Constants.keycard.flow.moveKeyPair:
            case Constants.keycard.flow.moveProfileKeyPair:
                d.currentStep = KeycardManagementPopup.FlowStep.Migrating
                break
            case Constants.keycard.flow.addKeyPairToStatus:
                d.currentStep = KeycardManagementPopup.FlowStep.AddingKeyPair
                break
            }

            d.keycardInteractionCompleted = true
        }

        function onKeycardGetMetadataSuccess() {
            d.processing = false
            d.success = true
            root.metadataResult(root.store.keycardState,
                                root.store.keycardUid,
                                root.store.keyUid,
                                root.store.keycardStatusAvailable,
                                root.store.remainingPinAttempts,
                                root.store.remainingPukAttempts,
                                root.store.availableSlots,
                                root.store.cardMetadataName,
                                root.store.cardMetadataWalletAccountsJson)
            root.close()
        }

        function onKeycardGetMetadataError(error) {
            console.error("Keycard get metadata, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error

            if (keycardErrors.internalError
                    || keycardErrors.wrongKeycardProfileError
                    || keycardErrors.wrongKeycardError
                    || (keycardErrors.wrongPinError1 && root.store.remainingPinAttempts > 0)
                    || keycardErrors.wrongPinError2
                    || keycardErrors.connectionKeycardError1
                    || keycardErrors.connectionKeycardError2
                    || keycardErrors.notKeycardError) {
                // in these cases the flow remains open, not a valid state to proceed to keycard details view
                return
            }

            root.metadataResult(root.store.keycardState,
                                root.store.keycardUid,
                                root.store.keyUid,
                                root.store.keycardStatusAvailable,
                                root.store.remainingPinAttempts,
                                root.store.remainingPukAttempts,
                                root.store.availableSlots,
                                root.store.cardMetadataName,
                                root.store.cardMetadataWalletAccountsJson)
            root.close()
        }

        function onKeycardFactoryResetSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardFactoryResetError(error) {
            console.error("Keycard factory reset, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardImportKeyPairSuccess() {
            d.processing = false
            d.success = true

            if (root.flow === Constants.keycard.flow.onboardingImportNewKeyPair
                    || root.flow === Constants.keycard.flow.onboardingImportSeedPhrase) {
                d.onboardingResultDataJson = JSON.stringify({
                    flow: root.flow,
                    keyUid: d.seedPhraseKeyUid,
                    keycardUid: root.store.keycardUid,
                    keyPairName: d.keyPairName,
                    seedPhrase: d.seedPhrase
                })
                d.currentStep = KeycardManagementPopup.FlowStep.OnboardingMixedFlowSuccess
            }
        }

        function onKeycardImportKeyPairError(error) {
            console.error("Keycard import key pair, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardAsyncLoginSuccess(dataJson) {
            d.processing = false
            d.success = true

            if (flow === Constants.keycard.flow.onboardingLoginWithKeycard) {
                d.onboardingResultDataJson = dataJson
                d.currentStep = KeycardManagementPopup.FlowStep.OnboardingMixedFlowSuccess
            }
        }

        function onKeycardAsyncLoginError(error) {
            console.error("Keycard async login, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardMoveKeyPairSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardMoveKeyPairError(error) {
            console.error("Keycard move key pair, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardMoveProfileKeyPairSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardMoveProfileKeyPairError(error) {
            console.error("Keycard move profile key pair, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardAddKeyPairSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardAddKeyPairError(error) {
            console.error("Keycard add key pair, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onStopUsingKeycardForKeyPairSuccess() {
            d.processing = false
            d.success = true
        }

        function onStopUsingKeycardForKeyPairError(error) {
            console.error("Stop using Keycard for key pair, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onStopUsingKeycardForProfileKeyPairSuccess() {
            d.processing = false
            d.success = true
        }

        function onStopUsingKeycardForProfileKeyPairError(error) {
            console.error("Stop using Keycard for profile key pair, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardChangePinSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardChangePinError(error) {
            console.error("Keycard change PIN, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardChangePukSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardChangePukError(error) {
            console.error("Keycard change PUK, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardRenameSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardRenameError(error) {
            console.error("Keycard rename, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardUnblockSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardUnblockError(error) {
            console.error("Keycard unblock, flow:", root.flow, "error:", error)
            d.processing = false
            d.error = error
        }
    }

    Connections {
        target: Global
        enabled: root.flow === Constants.keycard.flow.moveKeyPair
                 || root.flow === Constants.keycard.flow.moveProfileKeyPair
                 || root.flow === Constants.keycard.flow.stopUsingKeycard

        function onAuthenticationResult(reason, password, pin, keyUid) {
            if (!password) {
                return
            }

            d.authenticationPassword = password

            switch(reason) {
            case Constants.keycard.flow.moveKeyPair:
                if (root.store.isProfileMigratedToColdWallet)
                    d.currentStep = KeycardManagementPopup.FlowStep.InsertEmptyKeycard
                else
                    d.startMigratingNonProfileKeypairToKeycard()
                break
            case Constants.keycard.flow.moveProfileKeyPair:
                d.startMigratingProfileKeypairToKeycard()
                break
            case Constants.keycard.flow.stopUsingKeycard:
                d.startStopUsingKeycardForKeyPair()
                break
            default:
                console.warn("unknown authentication reason received in keycard popup", reason)
            }
        }
    }

    ErrorsHandler {
        id: keycardErrors
        errorText: d.error
    }

    contentItem: Item {
        implicitHeight: Constants.keycard.general.popupHeight

        Loader {
            id: contentLoader
            anchors.fill: parent

            sourceComponent: {
                if (d.processing) {
                    return keycardProgressComponent
                }

                if (root.flow === Constants.keycard.flow.readKeycard) {
                    if (!d.error
                            || (keycardErrors.wrongPinError1 && root.store.remainingPinAttempts > 0)
                            || keycardErrors.wrongPinError2) {
                        return enterPinComponent
                    }
                } else if (root.flow === Constants.keycard.flow.factoryReset) {
                    if (!d.error && !d.success) {
                        return factoryResetConfirmationComponent
                    }
                } else if (!d.error && !d.success) {
                    return d.componentForStep(d.currentStep) ?? keycardProgressComponent
                }

                return keycardProgressComponent
            }
        }
    }

    footer: StatusDialogFooter {
        leftButtons: ObjectModel {
            StatusBackButton {
                visible: (root.flow === Constants.keycard.flow.importSeedPhrase
                          && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                              || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                              || d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName
                              || d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts))
                         || (root.flow === Constants.keycard.flow.importNewKeyPair
                             && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                                 || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords
                                 || d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName
                                 || d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts))
                         || (root.flow === Constants.keycard.flow.moveKeyPair
                             && (d.currentStep === KeycardManagementPopup.FlowStep.EnterPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.EnterNewPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase))
                         || (root.flow === Constants.keycard.flow.moveProfileKeyPair
                             && (d.currentStep === KeycardManagementPopup.FlowStep.EnterPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.EnterNewPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                                 || d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                                 || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords))
                         || (root.flow === Constants.keycard.flow.addKeyPairToStatus
                             && (d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName
                                 || d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts))
                         || (root.flow === Constants.keycard.flow.stopUsingKeycard
                             && (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                                 || d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword
                                 || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword))
                         || (root.flow === Constants.keycard.flow.stopUsingKeycardForProfile
                             && (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                                 || d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword
                                 || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword))
                         || (root.flow === Constants.keycard.flow.startUsingProfileWithoutKeycard
                             && (d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword
                                 || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword))
                         || (root.flow === Constants.keycard.flow.changePin
                             && (d.currentStep === KeycardManagementPopup.FlowStep.EnterNewPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin))
                         || (root.flow === Constants.keycard.flow.setOrChangePuk
                             && (d.currentStep === KeycardManagementPopup.FlowStep.CreatePuk
                                 || d.currentStep === KeycardManagementPopup.FlowStep.RepeatPuk))
                         || (root.flow === Constants.keycard.flow.rename
                             && d.currentStep === KeycardManagementPopup.FlowStep.RenameInput)
                         || (root.flow === Constants.keycard.flow.unblockWithPuk
                             && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.EnterPuk))
                         || (root.flow === Constants.keycard.flow.unblockWithRecoveryPhrase
                             && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase))
                         || (root.flow === Constants.keycard.flow.onboardingImportNewKeyPair
                             && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                                 || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords))
                         || (root.flow === Constants.keycard.flow.onboardingImportSeedPhrase
                             && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                 || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase))

                onClicked: {
                    d.previousStep()
                }
            }
        }

        rightButtons: ObjectModel {
            StatusFlatButton {
                visible: d.currentStep !== KeycardManagementPopup.FlowStep.ManageAccounts
                         && d.currentStep !== KeycardManagementPopup.FlowStep.OnboardingMixedFlowSuccess
                text: {
                    if (root.flow === Constants.keycard.flow.readKeycard) {
                        if (contentLoader.status === Loader.Ready
                                && contentLoader.sourceComponent === enterPinComponent) {
                            return qsTr("Cancel")
                        }
                    } else if (root.flow === Constants.keycard.flow.factoryReset) {
                        if (contentLoader.status === Loader.Ready
                                && contentLoader.sourceComponent === factoryResetConfirmationComponent) {
                            return qsTr("Cancel")
                        }
                    } else if (root.flow === Constants.keycard.flow.importSeedPhrase
                               || root.flow === Constants.keycard.flow.importNewKeyPair
                               || root.flow === Constants.keycard.flow.moveKeyPair
                               || root.flow === Constants.keycard.flow.moveProfileKeyPair
                               || root.flow === Constants.keycard.flow.addKeyPairToStatus
                               || root.flow === Constants.keycard.flow.stopUsingKeycard
                               || root.flow === Constants.keycard.flow.stopUsingKeycardForProfile
                               || root.flow === Constants.keycard.flow.startUsingProfileWithoutKeycard
                               || root.flow === Constants.keycard.flow.changePin
                               || root.flow === Constants.keycard.flow.setOrChangePuk
                               || root.flow === Constants.keycard.flow.rename
                               || root.flow === Constants.keycard.flow.unblockWithPuk
                               || root.flow === Constants.keycard.flow.unblockWithRecoveryPhrase
                               || root.flow === Constants.keycard.flow.onboardingLoginWithKeycard
                               || root.flow === Constants.keycard.flow.onboardingImportNewKeyPair
                               || root.flow === Constants.keycard.flow.onboardingImportSeedPhrase) {
                        if (!d.processing && !d.success && !d.error) {
                            return qsTr("Cancel")
                        }
                    }

                    if (!!d.error) {
                        return qsTr("Done")
                    } else if (d.success) {
                        if (root.flow === Constants.keycard.flow.moveProfileKeyPair
                                || root.flow === Constants.keycard.flow.stopUsingKeycardForProfile) {
                            return qsTr("Quit and restart Status")
                        }
                        return qsTr("Done")
                    }
                    return qsTr("Cancel")
                }

                onClicked: {
                    if (d.success && (root.flow === Constants.keycard.flow.moveProfileKeyPair
                                      || root.flow === Constants.keycard.flow.stopUsingKeycardForProfile)) {
                        console.info("the app is closing due to successfully converted profile key pair - flow: ", root.flow)
                        root.store.signOutAndQuit()
                    }

                    root.close()
                }
            }

            StatusButton {
                visible: root.flow === Constants.keycard.flow.readKeycard
                         && contentLoader.status === Loader.Ready
                         && contentLoader.sourceComponent === enterPinComponent
                enabled: !d.processing
                text: qsTr("I don't have or don't know PIN")
                onClicked: d.startKeycardReading("")
            }

            StatusButton {
                visible: d.currentStep === KeycardManagementPopup.FlowStep.OnboardingMixedFlowSuccess
                         && (root.flow === Constants.keycard.flow.onboardingLoginWithKeycard
                             || root.flow === Constants.keycard.flow.onboardingImportNewKeyPair
                             || root.flow === Constants.keycard.flow.onboardingImportSeedPhrase
                             || root.flow === Constants.keycard.flow.startUsingProfileWithoutKeycard)
                text: qsTr("Continue")
                onClicked: {
                    d.mixedFlowSuccess = true
                    root.keycardFlowCompletedWithData(root.flow, d.onboardingResultDataJson)
                    root.close()
                }
            }

            StatusButton {
                visible: root.flow === Constants.keycard.flow.factoryReset
                         && contentLoader.status === Loader.Ready
                         && contentLoader.sourceComponent === factoryResetConfirmationComponent
                enabled: d.factoryResetConfirmationChecked
                text: qsTr("Factory reset this Keycard")
                onClicked: d.startFactoryReset()
            }

            StatusButton {
                visible: (root.flow === Constants.keycard.flow.importSeedPhrase
                          || root.flow === Constants.keycard.flow.importNewKeyPair
                          || root.flow === Constants.keycard.flow.addKeyPairToStatus)
                         && contentLoader.item
                         && d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts
                enabled: visible
                         && d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts
                         && contentLoader.item.allAccountsValid
                text: qsTr("Add another account")
                onClicked: {
                    if (contentLoader.item.numberOfAddedAccounts === root.store.remainingAccountCapacity()) {
                        Global.openLimitReachedPopup(Constants.LimitWarning.Accounts)
                        return
                    }
                    contentLoader.item.addAccount()
                }
            }

            StatusButton {
                visible: contentLoader.item
                         && ((root.flow === Constants.keycard.flow.importSeedPhrase
                              && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                  || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                                  || d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName
                                  || d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts))
                             || (root.flow === Constants.keycard.flow.importNewKeyPair
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                     || d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                                     || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords
                                     || d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName
                                     || d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts))
                             || (root.flow === Constants.keycard.flow.moveKeyPair
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.SelectKeyPair
                                     || d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                     || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                                     || d.currentStep === KeycardManagementPopup.FlowStep.InsertEmptyKeycard))
                             || (root.flow === Constants.keycard.flow.moveProfileKeyPair
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.SelectKeyPair
                                     || d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                     || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                                     || d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                                     || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords))
                             || (root.flow === Constants.keycard.flow.addKeyPairToStatus
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName
                                     || d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts))
                             || (root.flow === Constants.keycard.flow.stopUsingKeycard
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmKeyPair
                                     || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                                     || d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword
                                     || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword))
                             || (root.flow === Constants.keycard.flow.stopUsingKeycardForProfile
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmKeyPair
                                     || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                                     || d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword
                                     || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword))
                             || (root.flow === Constants.keycard.flow.startUsingProfileWithoutKeycard
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase
                                     || d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword
                                     || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword))
                             || (root.flow === Constants.keycard.flow.changePin
                                 && d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin)
                             || (root.flow === Constants.keycard.flow.setOrChangePuk
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.CreatePuk
                                     || d.currentStep === KeycardManagementPopup.FlowStep.RepeatPuk))
                             || (root.flow === Constants.keycard.flow.rename
                                 && d.currentStep === KeycardManagementPopup.FlowStep.RenameInput)
                             || (root.flow === Constants.keycard.flow.unblockWithPuk
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                     || d.currentStep === KeycardManagementPopup.FlowStep.EnterPuk))
                             || (root.flow === Constants.keycard.flow.unblockWithRecoveryPhrase
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                     || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase))
                             || (root.flow === Constants.keycard.flow.onboardingImportNewKeyPair
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                     || d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                                     || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords))
                             || (root.flow === Constants.keycard.flow.onboardingImportSeedPhrase
                                 && (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin
                                     || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase)))
                enabled: visible
                         && ((d.currentStep === KeycardManagementPopup.FlowStep.InsertEmptyKeycard)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin && d.pinMismatch)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase && contentLoader.item.seedPhraseValid)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase && contentLoader.item.seedPhraseRevealed)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords && contentLoader.item.allEntriesValid)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName && contentLoader.item.nameValid)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts && contentLoader.item.allAccountsValid)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.SelectKeyPair
                                 && !!contentLoader.item.selectedKeyUid
                                 && contentLoader.item.understandChecked)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmKeyPair
                                 && contentLoader.item.understandChecked)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword
                                 && contentLoader.item.ready)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword
                                 && contentLoader.item.passwordMatches)
                             || ((d.currentStep === KeycardManagementPopup.FlowStep.CreatePuk
                                  || d.currentStep === KeycardManagementPopup.FlowStep.RepeatPuk
                                  || d.currentStep === KeycardManagementPopup.FlowStep.EnterPuk)
                                 && contentLoader.item.pukValid)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.RenameInput
                                 && contentLoader.item.nameValid
                                 && contentLoader.item.keyPairName !== root.cardMetadataName))
                text: {
                    if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin) {
                        return qsTr("Try setting the PIN again")
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts
                            || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords) {
                        return qsTr("Continue")
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword) {
                        return qsTr("Create password")
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword) {
                        return qsTr("Finalize Status Password Creation")
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.RenameInput) {
                        return qsTr("Rename")
                    }

                    return qsTr("Next")
                }
                onClicked: {
                    if (d.currentStep === KeycardManagementPopup.FlowStep.InsertEmptyKeycard) {
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.SelectKeyPair) {
                        d.moveKeyPairSelectedKeyUid = contentLoader.item.selectedKeyUid
                        d.moveKeyPairSelectedKeyPairName = contentLoader.item.selectedKeyPairName
                        d.moveKeyPairUnderstandChecked = contentLoader.item.understandChecked
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmKeyPair) {
                        d.stopUsingUnderstandChecked = contentLoader.item.understandChecked
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.CreatePassword) {
                        d.newStatusPassword = contentLoader.item.password
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmPassword) {
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin) {
                        d.previousStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase) {
                        if (root.flow === Constants.keycard.flow.moveKeyPair
                                || root.flow === Constants.keycard.flow.moveProfileKeyPair
                                || root.flow === Constants.keycard.flow.unblockWithRecoveryPhrase
                                || root.flow === Constants.keycard.flow.onboardingImportSeedPhrase
                                || root.flow === Constants.keycard.flow.stopUsingKeycard
                                || root.flow === Constants.keycard.flow.stopUsingKeycardForProfile
                                || root.flow === Constants.keycard.flow.startUsingProfileWithoutKeycard) {
                            d.nextStep()
                            return
                        }
                        d.keyPairKnown = root.store.isKnownKeyUid(d.seedPhraseKeyUid)
                        if (d.keyPairKnown) {
                            d.keyPairName = root.store.getKeyPairNameForKeyUid(d.seedPhraseKeyUid)
                            d.accountPathsJson = root.store.getKeyPairAccountPathsJsonForKeyUid(d.seedPhraseKeyUid)
                        } else if (root.flow === Constants.keycard.flow.importSeedPhrase
                                   && root.store.remainingKeypairCapacity() === 0) {
                            Global.openLimitReachedPopup(Constants.LimitWarning.Keypairs)
                            return
                        }
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                            || d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords) {
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName) {
                        d.keyPairName = contentLoader.item.keyPairName
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts) {
                        d.accountPathsJson = contentLoader.item.getAccountsJson()
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.CreatePuk) {
                        d.newPuk = contentLoader.item.pukInput
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPuk) {
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.RenameInput) {
                        d.newName = contentLoader.item.keyPairName
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.EnterPuk) {
                        d.puk = contentLoader.item.pukInput
                        d.nextStep()
                        return
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.store.prepare()
        if (root.flow === Constants.keycard.flow.moveKeyPair
                || root.flow === Constants.keycard.flow.moveProfileKeyPair)
            root.store.prepareKeyPairModel()
        if (root.flow === Constants.keycard.flow.stopUsingKeycard)
            root.store.resolveKeyPairItemForKeyUid(root.keyUid)
        if (root.flow === Constants.keycard.flow.stopUsingKeycardForProfile)
            root.store.resolveKeyPairItemForKeyUid(root.store.userProfileKeyUid)
    }

    onClosed: {
        let keyUid = root.keyUid
        let keycardUid = root.keycardUid

        switch(root.flow) {
        case Constants.keycard.flow.readKeycard:
            keyUid = root.store.keyUid
            keycardUid = root.store.keycardUid
            break
        case Constants.keycard.flow.importSeedPhrase:
        case Constants.keycard.flow.importNewKeyPair:
            keyUid = d.seedPhraseKeyUid
            keycardUid = root.store.keycardUid
            break
        case Constants.keycard.flow.moveKeyPair:
        case Constants.keycard.flow.moveProfileKeyPair:
            keyUid = d.moveKeyPairSelectedKeyUid
            keycardUid = root.store.keycardUid
            break
        case Constants.keycard.flow.stopUsingKeycardForProfile:
            keyUid = root.store.userProfileKeyUid
            keycardUid = root.keycardUid
            break
        }

        let success = d.success
        if (flow === Constants.keycard.flow.onboardingLoginWithKeycard
                || flow === Constants.keycard.flow.onboardingImportNewKeyPair
                || flow === Constants.keycard.flow.onboardingImportSeedPhrase
                || flow === Constants.keycard.flow.startUsingProfileWithoutKeycard) {
            success = d.mixedFlowSuccess
        }

        root.keycardFlowCompleted(root.flow, keyUid, keycardUid, success)

        root.store.teardown()
    }

    Component {
        id: keycardProgressComponent
        KeycardProgressState {
            keycardInternalError: keycardErrors.internalError
            keycardNotEmptyError: keycardErrors.notEmptyKeycardError
            wrongKeycard: keycardErrors.wrongKeycardError
            wrongKeycardProfile: keycardErrors.wrongKeycardProfileError
            wrongPin: keycardErrors.wrongPinError1
                      || keycardErrors.wrongPinError2
            remainingPinAttempts: root.store.remainingPinAttempts
            wrongPuk: keycardErrors.wrongPukError1
                      || keycardErrors.wrongPukError2
            remainingPukAttempts: root.store.remainingPukAttempts

            keycardState: root.store.keycardState

            keycardInteractionCompleted: d.keycardInteractionCompleted

            processing: root.flow !== Constants.keycard.flow.readKeycard
                        && d.processing
            processingImage: Assets.png("keycard/scanning/scanning")
            processingTitle: {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return qsTr("Resetting Keycard...")
                case Constants.keycard.flow.importSeedPhrase:
                case Constants.keycard.flow.importNewKeyPair:
                    return qsTr("Importing key pair to Keycard...")
                case Constants.keycard.flow.moveKeyPair:
                    return qsTr("Moving key pair to Keycard...")
                case Constants.keycard.flow.moveProfileKeyPair:
                    return qsTr("Moving profile key pair to Keycard...")
                case Constants.keycard.flow.addKeyPairToStatus:
                    return qsTr("Adding key pair to Status...")
                case Constants.keycard.flow.stopUsingKeycard:
                    return qsTr("Moving key pair to Status...")
                case Constants.keycard.flow.stopUsingKeycardForProfile:
                    return qsTr("Moving profile key pair to Status...")
                case Constants.keycard.flow.changePin:
                    return qsTr("Changing Keycard PIN...")
                case Constants.keycard.flow.setOrChangePuk:
                    return qsTr("Setting your Keycard PUK...")
                case Constants.keycard.flow.rename:
                    return qsTr("Renaming Keycard...")
                case Constants.keycard.flow.unblockWithPuk:
                case Constants.keycard.flow.unblockWithRecoveryPhrase:
                    return qsTr("Unblocking Keycard...")
                case Constants.keycard.flow.onboardingLoginWithKeycard:
                    return qsTr("Logging in with Keycard...")
                case Constants.keycard.flow.onboardingImportNewKeyPair:
                case Constants.keycard.flow.onboardingImportSeedPhrase:
                    return qsTr("Importing key pair to Keycard...")
                default:
                    return qsTr("Reading...")
                }
            }
            processingSpecialWarning1: (root.flow === Constants.keycard.flow.moveProfileKeyPair
                                        || root.flow === Constants.keycard.flow.stopUsingKeycardForProfile)
                                       ? qsTr("Re-encrypting data may take some time")
                                       : ""
            processingSpecialWarning2: (root.flow === Constants.keycard.flow.moveProfileKeyPair
                                        || root.flow === Constants.keycard.flow.stopUsingKeycardForProfile)
                                       ? qsTr("Do not quit the application or turn off your device. Doing so will lead to data\ncorruption, loss of your Status profile and the inability to restart Status.")
                                       : ""

            success: {
                if (root.flow === Constants.keycard.flow.readKeycard)
                    return false
                return d.success
            }
            successImage: {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return Assets.png("keycard/factory_reset/keycard-factory-reset-positive")
                case Constants.keycard.flow.importSeedPhrase:
                case Constants.keycard.flow.importNewKeyPair:
                case Constants.keycard.flow.moveKeyPair:
                case Constants.keycard.flow.moveProfileKeyPair:
                case Constants.keycard.flow.addKeyPairToStatus:
                case Constants.keycard.flow.stopUsingKeycard:
                case Constants.keycard.flow.stopUsingKeycardForProfile:
                case Constants.keycard.flow.changePin:
                case Constants.keycard.flow.setOrChangePuk:
                case Constants.keycard.flow.rename:
                case Constants.keycard.flow.unblockWithPuk:
                case Constants.keycard.flow.unblockWithRecoveryPhrase:
                case Constants.keycard.flow.onboardingLoginWithKeycard:
                case Constants.keycard.flow.onboardingImportNewKeyPair:
                case Constants.keycard.flow.onboardingImportSeedPhrase:
                case Constants.keycard.flow.startUsingProfileWithoutKeycard:
                    return Assets.png("keycard/card_insert/insert")
                default:
                    return ""
                }
            }
            successTitle: {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return qsTr("Keycard has been reset")
                case Constants.keycard.flow.importSeedPhrase:
                case Constants.keycard.flow.importNewKeyPair:
                    return qsTr("Key pair has been imported to Keycard")
                case Constants.keycard.flow.moveKeyPair:
                    return qsTr("Key pair has been moved to Keycard")
                case Constants.keycard.flow.moveProfileKeyPair:
                    return qsTr("Profile key pair has been moved to Keycard")
                case Constants.keycard.flow.addKeyPairToStatus:
                    return qsTr("Key pair has been added to Status")
                case Constants.keycard.flow.stopUsingKeycard:
                    return qsTr("Key pair has been moved to Status")
                case Constants.keycard.flow.stopUsingKeycardForProfile:
                    return qsTr("Profile key pair has been moved to Status")
                case Constants.keycard.flow.startUsingProfileWithoutKeycard:
                    return qsTr("Ready to recover your profile")
                case Constants.keycard.flow.changePin:
                    return qsTr("Keycard PIN has been changed")
                case Constants.keycard.flow.setOrChangePuk:
                    return qsTr("Keycard’s PUK successfully set")
                case Constants.keycard.flow.rename:
                    return qsTr("Keycard has been renamed")
                case Constants.keycard.flow.unblockWithPuk:
                case Constants.keycard.flow.unblockWithRecoveryPhrase:
                    return qsTr("Keycard has been unblocked")
                case Constants.keycard.flow.onboardingLoginWithKeycard:
                    return qsTr("Keycard read completed")
                case Constants.keycard.flow.onboardingImportNewKeyPair:
                case Constants.keycard.flow.onboardingImportSeedPhrase:
                    return qsTr("Key pair has been imported to Keycard")
                default:
                    return qsTr("Success")
                }
            }
            successMessage: {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return qsTr("Keycard is now empty.")
                case Constants.keycard.flow.importSeedPhrase:
                case Constants.keycard.flow.importNewKeyPair:
                case Constants.keycard.flow.moveKeyPair:
                    return qsTr("Keycard is now required to sign with this key pair.")
                case Constants.keycard.flow.moveProfileKeyPair:
                    return qsTr("Keycard is now required to log in and sign.")
                case Constants.keycard.flow.addKeyPairToStatus:
                    return qsTr("Now you can sign with this key pair using Keycard.")
                case Constants.keycard.flow.stopUsingKeycard:
                    return qsTr("Status password is now required to sign.")
                case Constants.keycard.flow.stopUsingKeycardForProfile:
                    return qsTr("Status password is now required to log in and sign.")
                case Constants.keycard.flow.startUsingProfileWithoutKeycard:
                    return qsTr("Continue to log in and convert your profile to use a Status password.")
                case Constants.keycard.flow.changePin:
                    return qsTr("New PIN is required to interact with Keycard.")
                case Constants.keycard.flow.rename:
                    return qsTr("New name: %1").arg(d.newName)
                case Constants.keycard.flow.unblockWithPuk:
                    return qsTr("You can now use your Keycard again")
                case Constants.keycard.flow.unblockWithRecoveryPhrase:
                    return qsTr("It is now ready to use.")
                case Constants.keycard.flow.onboardingLoginWithKeycard:
                    return qsTr("Continue to finish logging in.")
                case Constants.keycard.flow.onboardingImportNewKeyPair:
                case Constants.keycard.flow.onboardingImportSeedPhrase:
                    return qsTr("Continue to finish setting up your profile.")
                default:
                    return ""
                }
            }

            failure: {
                if (root.flow === Constants.keycard.flow.readKeycard)
                    return false
                return !!d.error
            }
            failureImage: {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return Assets.png("keycard/factory_reset/keycard-factory-reset-negative")
                case Constants.keycard.flow.importSeedPhrase:
                case Constants.keycard.flow.importNewKeyPair:
                case Constants.keycard.flow.moveKeyPair:
                case Constants.keycard.flow.moveProfileKeyPair:
                case Constants.keycard.flow.addKeyPairToStatus:
                case Constants.keycard.flow.stopUsingKeycard:
                case Constants.keycard.flow.stopUsingKeycardForProfile:
                case Constants.keycard.flow.startUsingProfileWithoutKeycard:
                case Constants.keycard.flow.changePin:
                case Constants.keycard.flow.setOrChangePuk:
                case Constants.keycard.flow.rename:
                case Constants.keycard.flow.unblockWithPuk:
                case Constants.keycard.flow.unblockWithRecoveryPhrase:
                case Constants.keycard.flow.onboardingLoginWithKeycard:
                case Constants.keycard.flow.onboardingImportNewKeyPair:
                case Constants.keycard.flow.onboardingImportSeedPhrase:
                    return Assets.png("keycard/wrong_card/something-went-wrong")
                default:
                    return ""
                }
            }
            failureTitle: qsTr("Something went wrong")
            failureMessage: qsTr("Try again")
        }
    }

    Component {
        id: enterPinComponent
        EnterPinState {
            wrongPin: keycardErrors.wrongPinError1
                      || keycardErrors.wrongPinError2
            remainingAttempts: root.store.remainingPinAttempts

            onPinCompleteChanged: {
                if (!pinComplete) {
                    return
                }

                switch(root.flow) {
                case Constants.keycard.flow.readKeycard:
                    d.startKeycardReading(pinInput)
                    return
                case Constants.keycard.flow.importSeedPhrase:
                case Constants.keycard.flow.importNewKeyPair:
                case Constants.keycard.flow.moveKeyPair:
                case Constants.keycard.flow.moveProfileKeyPair:
                case Constants.keycard.flow.addKeyPairToStatus:
                    d.newPin = pinInput
                    d.nextStep()
                    return
                case Constants.keycard.flow.changePin:
                case Constants.keycard.flow.setOrChangePuk:
                case Constants.keycard.flow.rename:
                    d.currentPin = pinInput
                    d.nextStep()
                    return
                case Constants.keycard.flow.onboardingLoginWithKeycard:
                    d.currentPin = pinInput
                    d.nextStep()
                    return
                default:
                    return
                }
            }
        }
    }

    Component {
        id: createPinComponent
        EnterPinState {
            mode: EnterPinState.Mode.CreatePin

            onPinCompleteChanged: {
                if (!pinComplete) {
                    return
                }

                switch(root.flow) {
                case Constants.keycard.flow.importSeedPhrase:
                case Constants.keycard.flow.importNewKeyPair:
                case Constants.keycard.flow.moveKeyPair:
                case Constants.keycard.flow.moveProfileKeyPair:
                case Constants.keycard.flow.changePin:
                case Constants.keycard.flow.unblockWithPuk:
                case Constants.keycard.flow.unblockWithRecoveryPhrase:
                case Constants.keycard.flow.onboardingImportNewKeyPair:
                case Constants.keycard.flow.onboardingImportSeedPhrase:
                    d.newPin = pinInput
                    d.nextStep()
                    return
                default:
                    return
                }
            }
        }
    }

    Component {
        id: repeatPinComponent
        EnterPinState {
            mode: EnterPinState.Mode.RepeatPin
            pinToMatch: d.newPin

            onPinMismatchChanged: {
                d.pinMismatch = pinMismatch
            }

            onPinCompleteChanged: {
                if (!pinComplete) {
                    return
                }

                switch(root.flow) {
                case Constants.keycard.flow.importSeedPhrase:
                case Constants.keycard.flow.importNewKeyPair:
                case Constants.keycard.flow.moveKeyPair:
                case Constants.keycard.flow.moveProfileKeyPair:
                case Constants.keycard.flow.changePin:
                case Constants.keycard.flow.unblockWithPuk:
                case Constants.keycard.flow.unblockWithRecoveryPhrase:
                case Constants.keycard.flow.onboardingImportNewKeyPair:
                case Constants.keycard.flow.onboardingImportSeedPhrase:
                    d.nextStep()
                    return
                default:
                    return
                }
            }
        }
    }

    Component {
        id: factoryResetConfirmationComponent
        FactoryResetConfirmationState {
            onConfirmationUpdated: function(value) {
                d.factoryResetConfirmationChecked = value
            }
        }
    }

    Component {
        id: enterSeedPhraseComponent
        EnterSeedPhraseState {
            initialSeedPhrase: d.seedPhrase

            validateSeedPhrase: function(phrase) {
                const keyUid = root.store.getKeyUidForSeedPhrase(phrase)
                if (root.store.isKnownKeyUid(keyUid) && !root.store.isKeypairMigratedToColdWallet(keyUid)) {
                    console.error("trying to import onto a keycard a key pair that exists in the app, but not migrated to keycard (use move flow)")
                    return ""
                }
                return keyUid
            }

            onSeedPhraseValidated: function(phrase, keyUid) {
                d.seedPhrase = phrase
                d.seedPhraseKeyUid = keyUid
            }
        }
    }

    Component {
        id: enterKeyPairNameComponent
        EnterKeyPairNameState {
            initialKeyPairName: d.keyPairName.length > 0
                                ? d.keyPairName
                                : (root.flow === Constants.keycard.flow.addKeyPairToStatus
                                   ? root.cardMetadataName
                                   : "")

            onDone: {
                d.keyPairName = keyPairName
                d.nextStep()
            }
        }
    }

    Component {
        id: manageKeyPairAccountsComponent
        ManageKeyPairAccountsState {
            emojiPopup: root.emojiPopup
            keyPairName: d.keyPairName
            userProfilePublicKey: root.store.userProfilePubKey

            onDone: {
                d.accountPathsJson = getAccountsJson()
                d.nextStep()
            }
        }
    }

    Component {
        id: seedPhraseDisplayComponent
        SeedPhraseDisplayState {
            seedPhrase: d.seedPhrase
            seedPhraseRevealed: d.seedPhraseRevealed

            onSeedPhraseRevealedChanged: {
                d.seedPhraseRevealed = seedPhraseRevealed
            }
        }
    }

    Component {
        id: confirmSeedPhraseWordsComponent
        ConfirmSeedPhraseWordsState {
            seedPhrase: d.seedPhrase
        }
    }

    Component {
        id: insertEmptyKeycardComponent
        InsertEmptyKeycardState {}
    }

    Component {
        id: selectKeyPairComponent
        SelectKeyPairState {
            userProfilePublicKey: root.store.userProfilePubKey

            keypairsModel: root.store.keypairsModel
            fixedKeyUid: root.keyUid
            initialSelectedKeyUid: root.keyUid.length > 0 ? root.keyUid : d.moveKeyPairSelectedKeyUid
            initialUnderstandChecked: d.moveKeyPairUnderstandChecked
        }
    }

    Component {
        id: moveKeyPairEnterSeedPhraseComponent
        EnterSeedPhraseState {
            validateSeedPhrase: function(phrase) {
                const keyUid = root.store.getKeyUidForSeedPhrase(phrase)
                if (keyUid === d.moveKeyPairSelectedKeyUid)
                    return keyUid
                console.error("provided seed phrase doesn't match the previously selected key pair for moving to a keycard")
                return ""
            }

            onSeedPhraseValidated: function(phrase, keyUid) {
                d.seedPhrase = phrase
                d.seedPhraseKeyUid = keyUid
            }
        }
    }

    Component {
        id: selectProfileKeyPairComponent
        SelectKeyPairState {
            profileOnly: true

            userProfilePublicKey: root.store.userProfilePubKey

            keypairsModel: root.store.keypairsModel
            initialSelectedKeyUid: root.store.userProfileKeyUid
            initialUnderstandChecked: d.moveKeyPairUnderstandChecked
        }
    }

    Component {
        id: moveProfileKeyPairEnterSeedPhraseComponent
        EnterSeedPhraseState {
            validateSeedPhrase: function(phrase) {
                const keyUid = root.store.getKeyUidForSeedPhrase(phrase)
                if (keyUid === root.store.userProfileKeyUid)
                    return keyUid
                console.error("provided seed phrase doesn't match the profile key pair")
                return ""
            }

            onSeedPhraseValidated: function(phrase, keyUid) {
                d.seedPhrase = phrase
                d.seedPhraseKeyUid = keyUid
            }
        }
    }

    Component {
        id: stopUsingEnterSeedPhraseComponent
        EnterSeedPhraseState {
            initialSeedPhrase: d.seedPhrase

            validateSeedPhrase: function(phrase) {
                const keyUid = root.store.getKeyUidForSeedPhrase(phrase)
                if (keyUid === root.keyUid)
                    return keyUid
                console.error("provided seed phrase doesn't match the key pair being tried to stop using a keycard for")
                return ""
            }

            onSeedPhraseValidated: function(phrase, keyUid) {
                d.seedPhrase = phrase
                d.seedPhraseKeyUid = keyUid
            }
        }
    }

    Component {
        id: stopUsingForProfileEnterSeedPhraseComponent
        EnterSeedPhraseState {
            initialSeedPhrase: d.seedPhrase

            validateSeedPhrase: function(phrase) {
                const keyUid = root.store.getKeyUidForSeedPhrase(phrase)
                if (keyUid === root.store.userProfileKeyUid)
                    return keyUid
                console.error("provided seed phrase doesn't match the profile key pair being tried to stop using a keycard for")
                return ""
            }

            onSeedPhraseValidated: function(phrase, keyUid) {
                d.seedPhrase = phrase
                d.seedPhraseKeyUid = keyUid
            }
        }
    }

    Component {
        id: startUsingProfileWithoutKeycardEnterSeedPhraseComponent
        EnterSeedPhraseState {
            initialSeedPhrase: d.seedPhrase

            validateSeedPhrase: function(phrase) {
                const keyUid = root.store.getKeyUidForSeedPhrase(phrase)
                if (keyUid === root.keyUid)
                    return keyUid
                console.error("provided seed phrase doesn't match the profile key pair selected for keycard-less recovery")
                return ""
            }

            onSeedPhraseValidated: function(phrase, keyUid) {
                d.seedPhrase = phrase
                d.seedPhraseKeyUid = keyUid
            }
        }
    }

    Component {
        id: unblockWithRecoveryPhraseEnterSeedPhraseComponent
        EnterSeedPhraseState {
            initialSeedPhrase: d.seedPhrase

            validateSeedPhrase: function(phrase) {
                const keyUid = root.store.getKeyUidForSeedPhrase(phrase)
                if (keyUid === root.keyUid)
                    return keyUid
                console.error("provided seed phrase doesn't match the keycard's key pair being unblocked")
                return ""
            }

            onSeedPhraseValidated: function(phrase, keyUid) {
                d.seedPhrase = phrase
                d.seedPhraseKeyUid = keyUid
            }
        }
    }

    Component {
        id: onboardingEnterSeedPhraseComponent
        EnterSeedPhraseState {
            initialSeedPhrase: d.seedPhrase

            validateSeedPhrase: function(phrase) {
                const keyUid = root.store.getKeyUidForSeedPhrase(phrase)
                if (!root.store.isKnownKeyUid(keyUid) || root.store.isKeypairMigratedToColdWallet(keyUid)) {
                    return keyUid
                }
                console.error("trying to import onto a keycard a profile that exists in the app or not migrated to keycard (hint: login and use move flow)")
                return ""
            }

            onSeedPhraseValidated: function(phrase, keyUid) {
                d.seedPhrase = phrase
                d.seedPhraseKeyUid = keyUid
            }
        }
    }

    Component {
        id: confirmKeyPairForStopUsingComponent
        ConfirmKeyPairForStopUsingState {
            keyPairItem: root.store.keyPairItem
            userProfileKeyUid: root.store.userProfileKeyUid
            userProfilePubKey: root.store.userProfilePubKey
            areTestNetworksEnabled: false
            initialUnderstandChecked: d.stopUsingUnderstandChecked
        }
    }

    Component {
        id: createPasswordComponent
        CreatePasswordState {
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction
            initialPassword: d.newStatusPassword
        }
    }

    Component {
        id: confirmPasswordComponent
        ConfirmPasswordState {
            expectedPassword: d.newStatusPassword
        }
    }

    Component {
        id: createPukComponent
        EnterPukState {
            mode: EnterPukState.Mode.CreatePuk
        }
    }

    Component {
        id: repeatPukComponent
        EnterPukState {
            mode: EnterPukState.Mode.RepeatPuk
            pukToMatch: d.newPuk
        }
    }

    Component {
        id: renameKeycardComponent
        EnterKeyPairNameState {
            title: ""
            initialKeyPairName: root.cardMetadataName
        }
    }

    Component {
        id: enterPukComponent
        EnterPukState {
            mode: EnterPukState.Mode.EnterPuk
        }
    }
}
