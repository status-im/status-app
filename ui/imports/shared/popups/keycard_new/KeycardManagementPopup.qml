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

    required property KeycardManagementStore store

    property var emojiPopup: null

    signal metadataResult(string keycardState, string keycardUid, string keyUid, int remainingPinAttempts, int remainingPukAttempts,
                          int availableSlots, string cardMetadataName, string cardMetadataWalletAccountsJson)
    signal factoryResetResult(bool success)
    signal importKeyPairResult(bool success, string keyUid)

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
        DisplaySeedPhrase,
        ConfirmSeedPhraseWords,
        SelectKeyPair
    }

    QtObject {
        id: d

        readonly property bool keycardHasOnlyPinSet: !!root.keycardUid && !root.keyUid

        property bool processing: false
        property bool success: false
        property string error: ""

        property bool factoryResetConfirmationChecked: false

        property int currentStep: root.flow === Constants.keycard.flow.moveKeyPair
                                     ? KeycardManagementPopup.FlowStep.SelectKeyPair
                                     : d.keycardHasOnlyPinSet
                                         ? KeycardManagementPopup.FlowStep.EnterPin
                                         : KeycardManagementPopup.FlowStep.EnterNewPin

        property string newPin: ""
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

        function componentForStep(step) {
            switch (step) {
            case KeycardManagementPopup.FlowStep.EnterPin:
                return enterPinComponent
            case KeycardManagementPopup.FlowStep.EnterNewPin:
                return createPinComponent
            case KeycardManagementPopup.FlowStep.RepeatPin:
                return repeatPinComponent
            case KeycardManagementPopup.FlowStep.EnterSeedPhrase:
                return root.flow === Constants.keycard.flow.moveKeyPair
                    ? moveKeyPairEnterSeedPhraseComponent
                    : enterSeedPhraseComponent
            case KeycardManagementPopup.FlowStep.EnterKeyPairName:
                return enterKeyPairNameComponent
            case KeycardManagementPopup.FlowStep.ManageAccounts:
                return manageKeyPairAccountsComponent
            case KeycardManagementPopup.FlowStep.DisplaySeedPhrase:
                return seedPhraseDisplayComponent
            case KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords:
                return confirmSeedPhraseWordsComponent
            case KeycardManagementPopup.FlowStep.SelectKeyPair:
                return selectKeyPairComponent
            default: return null
            }
        }

        function startKeycardReading(pin) {
            d.processing = true
            root.store.startGetMetadata(pin)
        }

        function startFactoryReset() {
            d.processing = true
            root.store.startFactoryReset(root.keycardUid)
        }

        function startImportingKeyPair() {
            d.currentStep = KeycardManagementPopup.FlowStep.Importing
            d.processing = true
            root.store.startImportingKeyPair(d.newPin,
                                             d.seedPhrase,
                                             d.keyPairName,
                                             d.accountPathsJson)
        }

        function startMigratingNonProfileKeypairToKeycard() {
            d.currentStep = KeycardManagementPopup.FlowStep.Migrating
            d.processing = true
            Backpressure.debounce(this, 500, () => {
                                      root.store.startMigratingNonProfileKeypairToKeycard(d.authenticationPassword,
                                                                                          d.newPin,
                                                                                          d.seedPhrase,
                                                                                          root.store.getKeyPairNameForKeyUid(d.moveKeyPairSelectedKeyUid),
                                                                                          root.store.getKeyPairAccountPathsJsonForKeyUid(d.moveKeyPairSelectedKeyUid))
                                  })()
        }

        function nextStep() {
            if (d.currentStep === KeycardManagementPopup.FlowStep.SelectKeyPair) {
                d.currentStep = d.keycardHasOnlyPinSet
                    ? KeycardManagementPopup.FlowStep.EnterPin
                    : KeycardManagementPopup.FlowStep.EnterNewPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterPin) {
                if (root.flow === Constants.keycard.flow.importNewKeyPair) {
                    d.seedPhrase = root.store.generateMnemonic()
                    d.currentStep = KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                    return
                }

                d.currentStep = KeycardManagementPopup.FlowStep.EnterSeedPhrase
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterNewPin) {
                d.currentStep = KeycardManagementPopup.FlowStep.RepeatPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin) {
                if (root.flow === Constants.keycard.flow.importNewKeyPair) {
                    d.seedPhrase = root.store.generateMnemonic()
                    d.currentStep = KeycardManagementPopup.FlowStep.DisplaySeedPhrase
                    return
                }

                d.currentStep = KeycardManagementPopup.FlowStep.EnterSeedPhrase
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase) {
                if (root.flow === Constants.keycard.flow.moveKeyPair) {
                    Global.openAuthenticationPopup(Constants.keycard.flow.moveKeyPair, root.store.userProfileKeyUid)
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
                d.seedPhraseKeyUid = root.store.getKeyUidForSeedPhrase(d.seedPhrase)
                d.currentStep = KeycardManagementPopup.FlowStep.EnterKeyPairName
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName) {
                d.currentStep = KeycardManagementPopup.FlowStep.ManageAccounts
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts) {
                d.startImportingKeyPair()
                return
            }
        }

        function previousStep() {
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterNewPin
                    && root.flow === Constants.keycard.flow.moveKeyPair) {
                d.currentStep = KeycardManagementPopup.FlowStep.SelectKeyPair
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin) {
                d.newPin = ""
                d.pinMismatch = false
                d.currentStep = KeycardManagementPopup.FlowStep.EnterNewPin
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterPin
                    && root.flow === Constants.keycard.flow.moveKeyPair) {
                d.newPin = ""
                d.currentStep = KeycardManagementPopup.FlowStep.SelectKeyPair
                return
            }
            if (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase) {
                d.newPin = ""
                d.pinMismatch = false
                d.seedPhrase = ""
                d.seedPhraseKeyUid = ""
                d.currentStep = d.keycardHasOnlyPinSet
                    ? KeycardManagementPopup.FlowStep.EnterPin
                    : KeycardManagementPopup.FlowStep.EnterNewPin
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
                d.newPin = ""
                d.pinMismatch = false
                d.seedPhrase = ""
                d.seedPhraseKeyUid = ""
                if (d.keycardHasOnlyPinSet) {
                    d.currentStep = KeycardManagementPopup.FlowStep.EnterPin
                    return
                }
                d.currentStep = KeycardManagementPopup.FlowStep.EnterNewPin
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

        function onKeycardGetMetadataSuccess() {
            d.processing = false
            d.success = true
            root.metadataResult(root.store.keycardState,
                                root.store.keycardUid,
                                root.store.keyUid,
                                root.store.remainingPinAttempts,
                                root.store.remainingPukAttempts,
                                root.store.availableSlots,
                                root.store.cardMetadataName,
                                root.store.cardMetadataWalletAccountsJson)
            root.close()
        }

        function onKeycardGetMetadataError(error) {
            console.error("Keycard get metadata error:", error)
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
            console.error("Keycard factory reset error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardImportKeyPairSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardImportKeyPairError(error) {
            console.error("Keycard import key pair error:", error)
            d.processing = false
            d.error = error
        }

        function onKeycardMoveKeyPairSuccess() {
            d.processing = false
            d.success = true
        }

        function onKeycardMoveKeyPairError(error) {
            console.error("Keycard move key pair error:", error)
            d.processing = false
            d.error = error
        }
    }

    Connections {
        target: Global
        enabled: root.flow === Constants.keycard.flow.moveKeyPair

        function onAuthenticationResult(reason, password, pin, keyUid) {
            if (reason !== Constants.keycard.flow.moveKeyPair)
                return
            if (!password) {
                return
            }
            d.authenticationPassword = password
            d.startMigratingNonProfileKeypairToKeycard()
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

                onClicked: {
                    d.previousStep()
                }
            }
        }

        rightButtons: ObjectModel {
            StatusFlatButton {
                visible: d.currentStep !== KeycardManagementPopup.FlowStep.ManageAccounts
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
                               || root.flow === Constants.keycard.flow.moveKeyPair) {
                        if (!d.processing && !d.success && !d.error) {
                            return qsTr("Cancel")
                        }
                    }

                    return !!d.error || d.success ? qsTr("Done") : qsTr("Cancel")
                }

                onClicked: root.close()
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
                visible: root.flow === Constants.keycard.flow.factoryReset
                         && contentLoader.status === Loader.Ready
                         && contentLoader.sourceComponent === factoryResetConfirmationComponent
                enabled: d.factoryResetConfirmationChecked
                text: qsTr("Factory reset this Keycard")
                onClicked: d.startFactoryReset()
            }

            StatusButton {
                visible: (root.flow === Constants.keycard.flow.importSeedPhrase
                          || root.flow === Constants.keycard.flow.importNewKeyPair)
                         && contentLoader.item
                         && d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts
                enabled: visible
                         && d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts
                         && contentLoader.item.allAccountsValid
                         && contentLoader.item.numberOfAddedAccounts < Constants.keycard.maxNumberOfAccountsToAddWhenImportingKeyPair
                text: qsTr("Add another account")
                onClicked: {
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
                                     || d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase)))
                enabled: visible
                         && ((d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin && d.pinMismatch)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase && contentLoader.item.seedPhraseValid)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.DisplaySeedPhrase && contentLoader.item.seedPhraseRevealed)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.ConfirmSeedPhraseWords && contentLoader.item.allEntriesValid)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.EnterKeyPairName && contentLoader.item.nameValid)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts && contentLoader.item.allAccountsValid)
                             || (d.currentStep === KeycardManagementPopup.FlowStep.SelectKeyPair
                                 && !!contentLoader.item.selectedKeyUid
                                 && contentLoader.item.understandChecked))
                text: {
                    if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin) {
                        return qsTr("Try setting the PIN again")
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.ManageAccounts) {
                        return qsTr("Continue")
                    }

                    return qsTr("Next")
                }
                onClicked: {
                    if (d.currentStep === KeycardManagementPopup.FlowStep.SelectKeyPair) {
                        d.moveKeyPairSelectedKeyUid = contentLoader.item.selectedKeyUid
                        d.moveKeyPairSelectedKeyPairName = contentLoader.item.selectedKeyPairName
                        d.moveKeyPairUnderstandChecked = contentLoader.item.understandChecked
                        d.nextStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.RepeatPin) {
                        d.previousStep()
                        return
                    }
                    if (d.currentStep === KeycardManagementPopup.FlowStep.EnterSeedPhrase) {
                        if (root.flow === Constants.keycard.flow.moveKeyPair) {
                            d.nextStep()
                            return
                        }
                        d.keyPairKnown = root.store.isKnownKeyUid(d.seedPhraseKeyUid)
                        if (d.keyPairKnown) {
                            d.keyPairName = root.store.getKeyPairNameForKeyUid(d.seedPhraseKeyUid)
                            d.accountPathsJson = root.store.getKeyPairAccountPathsJsonForKeyUid(d.seedPhraseKeyUid)
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
                }
            }
        }
    }

    Component.onCompleted: {
        root.store.prepare()
        if (root.flow === Constants.keycard.flow.moveKeyPair)
            root.store.prepareKeyPairModel()
    }

    onClosed: {
        if (root.flow === Constants.keycard.flow.factoryReset) {
            root.factoryResetResult(d.success)
        } else if (root.flow === Constants.keycard.flow.importSeedPhrase
                   || root.flow === Constants.keycard.flow.importNewKeyPair) {
            root.importKeyPairResult(d.success, d.seedPhraseKeyUid)
        } else if (root.flow === Constants.keycard.flow.moveKeyPair) {
            root.importKeyPairResult(d.success, d.moveKeyPairSelectedKeyUid)
        }
        root.store.teardown()
    }

    Component {
        id: keycardProgressComponent
        KeycardProgressState {
            keycardInternalError: keycardErrors.internalError
            wrongKeycard: keycardErrors.wrongKeycardError
            wrongKeycardProfile: keycardErrors.wrongKeycardProfileError
            wrongPin: keycardErrors.wrongPinError1
                      || keycardErrors.wrongPinError2
            remainingAttempts: root.store.remainingPinAttempts

            keycardState: root.store.keycardState

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
                default:
                    return qsTr("Reading...")
                }
            }

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
            validateSeedPhrase: function(phrase) {
                const keyUid = root.store.getKeyUidForSeedPhrase(phrase)
                if (root.store.isKnownKeyUid(keyUid)) {
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
            initialKeyPairName: d.keyPairName

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
        id: selectKeyPairComponent
        SelectKeyPairState {
            keypairsModel: root.store.keypairsModel
            initialSelectedKeyUid: d.moveKeyPairSelectedKeyUid
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
                return ""
            }

            onSeedPhraseValidated: function(phrase, keyUid) {
                d.seedPhrase = phrase
                d.seedPhraseKeyUid = keyUid
            }
        }
    }
}
