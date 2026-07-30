import QtQuick
import QtQuick.Layouts

import shared.views

import utils

import "../stores"

Item {
    id: root

    property KeypairImportStore store

    implicitHeight: layout.implicitHeight

    SyncingEnterCode {
        id: layout

        anchors.fill: parent
        anchors.margins: 24
        spacing: 32

        firstTabName: qsTr("Scan encrypted QR code")
        secondTabName: qsTr("Enter encrypted key")
        syncQrErrorMessage: qsTr("This does not look like the correct key pair QR code")
        syncCodeErrorMessage: qsTr("This does not look like an encrypted key pair code")
        firstInstructionButtonName: Constants.keypairImportPopup.instructionsLabelForQr
        secondInstructionButtonName: Constants.keypairImportPopup.instructionsLabelForEncryptedKey
        syncCodeLabel: qsTr("Paste encrypted key")
        proceedWithContineButton: false

        validateConnectionString: function(connectionString) {
            const result = root.store.validateConnectionString(connectionString)
            return result === ""
        }

        onSyncViaQrChanged: {
            root.store.syncViaQr = syncViaQr
        }

        onProceed: {
            root.store.keypairImportModule.connectionString = connectionString
            if (!syncViaQr) {
                return
            }
            root.store.submitPopup()
        }

        onDisplayInstructions: {
            root.store.currentState.doSecondaryAction()
        }
    }
}
