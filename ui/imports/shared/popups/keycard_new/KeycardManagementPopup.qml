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

    width: Constants.keycard.general.popupWidth
    padding: Theme.halfPadding
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    title: {
        switch(root.flow) {
        case Constants.keycard.flow.readKeycard:
            return qsTr("Read Keycard")
        default:
            return qsTr("Keycard Flow")
        }
    }

    QtObject {
        id: d

        property bool processing: false
        property string error: ""

        function startKeycardReading(pin) {
            d.processing = true
            root.store.startGetMetadata(pin)
        }
    }

    Connections {
        target: root.store

        function onKeycardGetMetadataSuccess() {
            d.processing = false
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
            console.warn("Keycard get metadata error:", error)
            d.processing = false
            d.error = error

            if (keycardErrors.wrongKeycardError
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
                    return readingComponent
                }

                if (root.flow === Constants.keycard.flow.readKeycard) {
                    if (!d.error
                            || (keycardErrors.wrongPinError1 && root.store.remainingPinAttempts > 0)
                            || keycardErrors.wrongPinError2) {
                        return enterPinComponent
                    }
                }

                return readingComponent
            }
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusFlatButton {
                text: {
                    if (root.flow === Constants.keycard.flow.readKeycard
                            && contentLoader.status === Loader.Ready
                            && contentLoader.sourceComponent === enterPinComponent) {
                        return qsTr("Cancel")
                    }

                    return !!d.error? qsTr("Done") : qsTr("Cancel")
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
        }
    }

    Component.onCompleted: {
        root.store.prepare()
    }

    onClosed: {
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
        id: readingComponent
        ReadingKeycardState {
            wrongKeycard: keycardErrors.wrongKeycardError
            keycardState: root.store.keycardState
        }
    }
}
