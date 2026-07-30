import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils
import shared.views

import "../stores"

Item {
    id: root

    property KeypairImportStore store

    implicitHeight: layout.implicitHeight

    Component.onCompleted: {
        Qt.callLater(root.store.currentState.doSecondaryAction)
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 16

        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            visible: !root.store.keypairImportModule.connectionString
                     && !root.store.keypairImportModule.connectionStringError
            spacing: Theme.padding

            StatusBaseText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Authenticate to create a QR code")
                font.pixelSize: Theme.secondaryAdditionalTextSize
            }

            StatusButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Authenticate")
                visible: !root.store.keypairImportModule.connectionString
                         && !root.store.keypairImportModule.connectionStringError

                icon.name: Utils.resolveAuthSignIcon(root.store.userProfileKeyUid,
                                                     root.store.migratedToColdWallet,
                                                     Constants.AuthSignPurpose.General)
                onClicked: {
                    root.store.currentState.doSecondaryAction()
                }
            }
        }

        SyncingDisplayCode {
            Layout.fillWidth: true
            Layout.margins: 16
            visible: !!root.store.keypairImportModule.connectionString

            connectionStringLabel: qsTr("Encrypted key pairs code")
            connectionString: root.store.keypairImportModule.connectionString
            importCodeInstructions: qsTr("On your other device, navigate to the Wallet screen<br>and select ‘Import missing key pairs’. For security reasons,<br>do not save this code anywhere.")
            codeExpiredMessage: qsTr("Your QR and encrypted key pairs code have expired.")

            onConnectionStringChanged: {
                if (!!connectionString) {
                    start()
                }
            }

            onRequestConnectionString: {
                root.store.generateConnectionStringForExporting()
            }
        }

        SyncingErrorMessage {
            Layout.fillWidth: true
            visible: !!root.store.keypairImportModule.connectionStringError
            primaryText: qsTr("Failed to generate sync code")
            secondaryText: qsTr("Failed to start pairing server")
            errorDetails: root.store.keypairImportModule.connectionStringError
        }
    }
}
