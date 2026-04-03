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

    signal metadataResult(string keycardState, string keycardUid, string keyUid, int remainingPinAttempts, int remainingPukAttempts,
                          int availableSlots, string cardMetadataName, string cardMetadataWalletAccountsJson)
    signal factoryResetResult(bool success)

    width: Constants.keycard.general.popupWidth
    padding: Theme.halfPadding
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    title: {
        switch(root.flow) {
        case Constants.keycard.flow.readKeycard:
            return qsTr("Read Keycard")
        case Constants.keycard.flow.factoryReset:
            return qsTr("Factory reset")
        default:
            return qsTr("Keycard Flow")
        }
    }

    QtObject {
        id: d

        property bool processing: false
        property bool success: false
        property string error: ""

        property bool factoryResetConfirmationChecked: false

        function startKeycardReading(pin) {
            d.processing = true
            root.store.startGetMetadata(pin)
        }

        function startFactoryReset() {
            d.processing = true
            root.store.startFactoryReset(root.keycardUid)
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
                }

                return keycardProgressComponent
            }
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusFlatButton {
                text: {
                    if (root.flow === Constants.keycard.flow.readKeycard){
                        if (contentLoader.status === Loader.Ready
                                && contentLoader.sourceComponent === enterPinComponent) {
                            return qsTr("Cancel")
                        }
                    } else if (root.flow === Constants.keycard.flow.factoryReset){
                        if (contentLoader.status === Loader.Ready
                                && contentLoader.sourceComponent === factoryResetConfirmationComponent) {
                            return qsTr("Cancel")
                        }
                    }

                    return !!d.error || d.success? qsTr("Done") : qsTr("Cancel")
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
        }
    }

    Component.onCompleted: {
        root.store.prepare()
    }

    onClosed: {
        if (root.flow === Constants.keycard.flow.factoryReset) {
            root.factoryResetResult(d.success)
        }
        root.store.teardown()
    }

    Component {
        id: enterPinComponent
        EnterPinState {
            wrongPin: keycardErrors.wrongPinError1 || keycardErrors.wrongPinError2
            remainingAttempts: root.store.remainingPinAttempts

            onPinCompleteChanged: {
                if (pinComplete) {
                    if (root.flow === Constants.keycard.flow.readKeycard) {
                        d.startKeycardReading(pinInput)
                    }
                }
            }
        }
    }

    Component {
        id: keycardProgressComponent
        KeycardProgressState {
            keycardInternalError: keycardErrors.internalError
            wrongKeycard: keycardErrors.wrongKeycardError
            wrongKeycardProfile: keycardErrors.wrongKeycardProfileError

            keycardState: root.store.keycardState

            processing: root.flow !== Constants.keycard.flow.readKeycard
                        && d.processing
            processingImage: Assets.png("keycard/scanning/scanning")
            processingTitle: {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return qsTr("Resetting Keycard...")
                default:
                    return qsTr("Reading...")
                }
            }

            success: root.flow !== Constants.keycard.flow.readKeycard
                     && d.success
            successImage: {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return Assets.png("keycard/factory_reset/keycard-factory-reset-positive")
                default:
                    return ""
                }
            }
            successTitle: {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return qsTr("Keycard has been reset")
                default:
                    return qsTr("Success")
                }
            }
            successMessage: {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return qsTr("Keycard is now empty.")
                default:
                    return ""
                }
            }

            failure: root.flow !== Constants.keycard.flow.readKeycard
                     && !!d.error
            failureImage:      {
                switch(root.flow) {
                case Constants.keycard.flow.factoryReset:
                    return Assets.png("keycard/factory_reset/keycard-factory-reset-negative")
                default:
                    return ""
                }
            }
            failureTitle: qsTr("Something went wrong")
            failureMessage: qsTr("Try again")
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
}
