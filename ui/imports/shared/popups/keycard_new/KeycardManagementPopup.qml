import QtQuick
import QtQuick.Controls
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
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
        default:
            return qsTr("Keycard Flow")
        }
    }

    enum ImportFlowSteps {
        EnterPin,
        EnterNewPin,
        RepeatPin,
        EnterSeedPhrase,
        EnterKeyPairName,
        ManageAccounts,
        Importing
    }

    QtObject {
        id: d

        readonly property bool keycardHasOnlyPinSet: !!root.keycardUid && !root.keyUid

        property bool processing: false
        property bool success: false
        property string error: ""

        property bool factoryResetConfirmationChecked: false

        property int importStep: d.keycardHasOnlyPinSet?
                                     KeycardManagementPopup.ImportFlowSteps.EnterPin
                                   : KeycardManagementPopup.ImportFlowSteps.EnterNewPin

        property string newPin: ""
        property bool pinMismatch: false
        property string seedPhrase: ""
        property string seedPhraseKeyUid: ""
        property bool keyPairKnown: false
        property string keyPairName: ""
        property string accountPathsJson: "[]"

        function startKeycardReading(pin) {
            d.processing = true
            root.store.startGetMetadata(pin)
        }

        function startFactoryReset() {
            d.processing = true
            root.store.startFactoryReset(root.keycardUid)
        }

        function startLoadSeedPhrase() {
            d.importStep = KeycardManagementPopup.ImportFlowSteps.Importing
            d.processing = true
            root.store.startLoadSeedPhrase(d.newPin, d.seedPhrase, d.keyPairName, d.accountPathsJson)
        }

        function nextImportStep() {
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterPin) {
                d.importStep = KeycardManagementPopup.ImportFlowSteps.EnterSeedPhrase
                return
            }
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterNewPin) {
                d.importStep = KeycardManagementPopup.ImportFlowSteps.RepeatPin
                return
            }
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.RepeatPin) {
                d.importStep = KeycardManagementPopup.ImportFlowSteps.EnterSeedPhrase
                return
            }
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterSeedPhrase) {
                if (d.keyPairKnown) {
                    d.startLoadSeedPhrase()
                } else {
                    d.importStep = KeycardManagementPopup.ImportFlowSteps.EnterKeyPairName
                }
                return
            }
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterKeyPairName) {
                d.importStep = KeycardManagementPopup.ImportFlowSteps.ManageAccounts
                return
            }
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.ManageAccounts) {
                d.startLoadSeedPhrase()
                return
            }
        }

        function previousImportStep() {
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.RepeatPin) {
                d.newPin = ""
                d.pinMismatch = false
                d.importStep = KeycardManagementPopup.ImportFlowSteps.EnterNewPin
                return
            }
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterSeedPhrase) {
                d.newPin = ""
                d.pinMismatch = false
                if (d.keycardHasOnlyPinSet) {
                    d.importStep = KeycardManagementPopup.ImportFlowSteps.EnterPin
                    return
                }
                d.importStep = KeycardManagementPopup.ImportFlowSteps.EnterNewPin
                return
            }
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterKeyPairName) {
                d.newPin = ""
                d.pinMismatch = false
                d.seedPhrase = ""
                d.seedPhraseKeyUid = ""
                d.keyPairName = ""
                if (d.keycardHasOnlyPinSet) {
                    d.importStep = KeycardManagementPopup.ImportFlowSteps.EnterPin
                    return
                }
                d.importStep = KeycardManagementPopup.ImportFlowSteps.EnterNewPin
                return
            }
            if (d.importStep === KeycardManagementPopup.ImportFlowSteps.ManageAccounts) {
                d.accountPathsJson = "[]"
                d.importStep = KeycardManagementPopup.ImportFlowSteps.EnterKeyPairName
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
                } else if (root.flow === Constants.keycard.flow.importSeedPhrase) {
                    if (!d.error && !d.success) {
                        switch(d.importStep) {
                        case KeycardManagementPopup.ImportFlowSteps.EnterPin:
                            return enterPinComponent
                        case KeycardManagementPopup.ImportFlowSteps.EnterNewPin:
                            return createPinComponent
                        case KeycardManagementPopup.ImportFlowSteps.RepeatPin:
                            return repeatPinComponent
                        case KeycardManagementPopup.ImportFlowSteps.EnterSeedPhrase:
                            return enterSeedPhraseComponent
                        case KeycardManagementPopup.ImportFlowSteps.EnterKeyPairName:
                            return enterKeyPairNameComponent
                        case KeycardManagementPopup.ImportFlowSteps.ManageAccounts:
                            return manageKeyPairAccountsComponent
                        }
                    }
                }

                return keycardProgressComponent
            }
        }
    }

    footer: StatusDialogFooter {
        leftButtons: ObjectModel {
            StatusBackButton {
                visible: root.flow === Constants.keycard.flow.importSeedPhrase
                         && (d.importStep === KeycardManagementPopup.ImportFlowSteps.RepeatPin
                             || d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterSeedPhrase
                             || d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterKeyPairName
                             || d.importStep === KeycardManagementPopup.ImportFlowSteps.ManageAccounts)

                onClicked: {
                    d.previousImportStep()
                }
            }
        }

        rightButtons: ObjectModel {
            StatusFlatButton {
                visible: d.importStep !== KeycardManagementPopup.ImportFlowSteps.ManageAccounts
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
                    } else if (root.flow === Constants.keycard.flow.importSeedPhrase) {
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
                visible: root.flow === Constants.keycard.flow.importSeedPhrase
                         && contentLoader.item
                         && d.importStep === KeycardManagementPopup.ImportFlowSteps.ManageAccounts
                enabled: visible
                         && d.importStep === KeycardManagementPopup.ImportFlowSteps.ManageAccounts
                         && contentLoader.item.allAccountsValid
                         && contentLoader.item.numberOfAddedAccounts < Constants.keycard.maxNumberOfAccountsToAddWhenImportingKeyPair
                text: qsTr("Add another account")
                onClicked: {
                    contentLoader.item.addAccount()
                }
            }

            StatusButton {
                visible: root.flow === Constants.keycard.flow.importSeedPhrase
                         && contentLoader.item
                         && (d.importStep === KeycardManagementPopup.ImportFlowSteps.RepeatPin
                             || d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterSeedPhrase
                             || d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterKeyPairName
                             || d.importStep === KeycardManagementPopup.ImportFlowSteps.ManageAccounts)
                enabled: visible
                         && ((d.importStep === KeycardManagementPopup.ImportFlowSteps.RepeatPin && d.pinMismatch)
                             || (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterSeedPhrase && contentLoader.item.seedPhraseValid)
                             || (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterKeyPairName && contentLoader.item.nameValid)
                             || (d.importStep === KeycardManagementPopup.ImportFlowSteps.ManageAccounts && contentLoader.item.allAccountsValid))
                text: {
                    if (d.importStep === KeycardManagementPopup.ImportFlowSteps.RepeatPin) {
                        return qsTr("Try setting the PIN again")
                    }
                    if (d.importStep === KeycardManagementPopup.ImportFlowSteps.ManageAccounts) {
                        return qsTr("Continue")
                    }

                    return qsTr("Next")
                }
                onClicked: {
                    if (d.importStep === KeycardManagementPopup.ImportFlowSteps.RepeatPin) {
                        d.previousImportStep()
                        return
                    }
                    if (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterSeedPhrase) {
                        d.keyPairKnown = root.store.isKnownKeyUid(d.seedPhraseKeyUid)
                        if (d.keyPairKnown) {
                            d.keyPairName = root.store.getKeyPairNameForKeyUid(d.seedPhraseKeyUid)
                            d.accountPathsJson = root.store.getKeyPairAccountPathsJsonForKeyUid(d.seedPhraseKeyUid)
                        }
                        d.nextImportStep()
                        return
                    }
                    if (d.importStep === KeycardManagementPopup.ImportFlowSteps.EnterKeyPairName) {
                        d.keyPairName = contentLoader.item.keyPairName
                        d.nextImportStep()
                        return
                    }
                    if (d.importStep === KeycardManagementPopup.ImportFlowSteps.ManageAccounts) {
                        d.accountPathsJson = contentLoader.item.getAccountsJson()
                        d.nextImportStep()
                        return
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.store.prepare()
    }

    onClosed: {
        if (root.flow === Constants.keycard.flow.factoryReset) {
            root.factoryResetResult(d.success)
        } else if (root.flow === Constants.keycard.flow.importSeedPhrase) {
            root.importKeyPairResult(d.success, d.seedPhraseKeyUid)
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
                    return qsTr("Importing key pair to Keycard...")
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
                    d.newPin = pinInput
                    d.nextImportStep()
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
                    d.newPin = pinInput
                    d.nextImportStep()
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
                    d.nextImportStep()
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
                return root.store.getKeyUidForSeedPhrase(phrase)
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
                d.nextImportStep()
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
                d.nextImportStep()
            }
        }
    }
}
