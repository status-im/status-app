import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils

import utils
import shared.controls
import shared.views

import AppLayouts.Profile.stores as ProfileStores

StatusDialog {
    id: root

    required property string rawConnectionString

    property ProfileStores.DevicesStore devicesStore
    property ProfileStores.ProfileStore profileStore

    width: 480
    padding: 16
    modal: true

    title: qsTr("Sync a New Device")

    QtObject {
        id: d

        readonly property int stateDisplaySyncCode: 0
        readonly property int stateLocalPairingInProgress: 1
        readonly property int stateLocalPairingFailed: 2
        readonly property int stateLocalPairingSuccess: 3
        readonly property int stateError: 4

        property int state: d.stateDisplaySyncCode

        readonly property bool localPairing: d.state === d.stateLocalPairingInProgress
                                             || d.state === d.stateLocalPairingFailed
                                             || d.state === d.stateLocalPairingSuccess
        property string localPairingErrorMessage

        property string connectionString
        property string errorMessage

        function generateConnectionString() {

            d.connectionString = ""
            d.errorMessage = ""

            try {
                const json = JSON.parse(root.rawConnectionString)
                d.errorMessage = json.error
            } catch (e) {
                d.connectionString = root.rawConnectionString
            }

            if (d.errorMessage !== "") {
                if (d.state === d.stateDisplaySyncCode)
                    d.state = d.stateError
                return
            }

            displaySyncCodeView.secondsTimeout = 5 * 60 // This timeout should be moved to status-go.
            displaySyncCodeView.start()
        }
    }

    Connections {
        target: root.devicesStore
        function onLocalPairingStateChanged() {
            switch (root.devicesStore.localPairingState) {
            case Constants.LocalPairingState.Transferring:
                if (d.state === d.stateDisplaySyncCode)
                    d.state = d.stateLocalPairingInProgress
                break
            case Constants.LocalPairingState.Error:
                if (d.state === d.stateDisplaySyncCode || d.state === d.stateLocalPairingInProgress)
                    d.state = d.stateLocalPairingFailed
                break
            case Constants.LocalPairingState.Finished:
                if (d.state === d.stateDisplaySyncCode || d.state === d.stateLocalPairingInProgress)
                    d.state = d.stateLocalPairingSuccess
                break
            }
        }
    }

    onAboutToShow: {
        d.state = d.stateDisplaySyncCode
        d.generateConnectionString()
    }

    contentItem: Item {

        implicitWidth: Math.max(displaySyncCodeView.implicitWidth,
                                localPairingView.implicitWidth,
                                errorView.implicitWidth)

        implicitHeight: Math.max(displaySyncCodeView.implicitHeight,
                                 localPairingView.implicitHeight,
                                 errorView.implicitHeight)

        SyncingDisplayCode {
            id: displaySyncCodeView
            anchors.fill: parent
            visible: d.state === d.stateDisplaySyncCode

            connectionStringLabel: qsTr("Sync code")
            connectionString: d.connectionString
            importCodeInstructions: qsTr("On your other device, navigate to the Syncing<br>screen and select Enter Sync Code.")
            codeExpiredMessage: qsTr("Your QR and Sync Code have expired.")

            onRequestConnectionString: {
                d.generateConnectionString()
            }
        }

        SyncingDeviceView {
            id: localPairingView
            anchors.fill: parent
            visible: d.localPairing
            devicesModel: root.devicesStore.devicesModel
            userDisplayName: root.profileStore.displayName
            usesDefaultName: root.profileStore.usesDefaultName
            userPublicKey: root.profileStore.pubKey
            userImage: root.profileStore.icon
            userColorId: root.profileStore.colorId

            localPairingState: root.devicesStore.localPairingState
            localPairingError: root.devicesStore.localPairingError

            installationId: root.devicesStore.localPairingInstallationId
            installationName: root.devicesStore.localPairingInstallationName
            installationDeviceType: root.devicesStore.localPairingInstallationDeviceType
        }

        SyncingErrorMessage {
            id: errorView
            anchors.fill: parent
            visible: d.state === d.stateError
            primaryText: qsTr("Failed to generate sync code")
            secondaryText: qsTr("Failed to start pairing server")
            errorDetails: d.errorMessage
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusButton {

                objectName: "syncAnewDeviceNextButton"

                id: nextButton
                visible: !!text
                enabled: d.state !== d.stateLocalPairingInProgress
                onClicked: root.close()
                text: {
                    if (d.state === d.stateDisplaySyncCode
                        || d.state === d.stateLocalPairingInProgress
                        || d.state === d.stateLocalPairingSuccess)
                        return qsTr("Done");
                    if (d.state === d.stateLocalPairingFailed
                        || d.state === d.stateError)
                        return qsTr("Close");
                    return ""
                }
            }
        }
    }
}
