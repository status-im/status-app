import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import QtQml.StateMachine as DSM

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

        signal generatingConnectionStringFailed
        signal connectionStringGenerated

        signal localPairingStarted
        signal localPairingFailed
        signal localPairingFinished
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
                d.generatingConnectionStringFailed()
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
                d.localPairingStarted()
                break
            case Constants.LocalPairingState.Error:
                d.localPairingFailed()
                break
            case Constants.LocalPairingState.Finished:
                d.localPairingFinished()
                break
            }
        }
    }

    DSM.StateMachine {
        id: stateMachine

        running: root.visible
        initialState: displaySyncCodeState

        DSM.State {
            id: displaySyncCodeState

            onEntered: {
                d.generateConnectionString()
            }

            DSM.SignalTransition {
                targetState: errorState
                signal: d.generatingConnectionStringFailed
            }

            DSM.SignalTransition {
                targetState: localPairingBaseState
                signal: d.localPairingStarted
            }

            DSM.SignalTransition {
                targetState: finalState
                signal: nextButton.clicked
            }

            // Next 2 transitions are here temporarily.
            // TODO: Remove when server notifies with ProcessSuccess/ProcessError event.

            DSM.SignalTransition {
                targetState: localPairingFailedState
                signal: d.localPairingFailed
            }

            DSM.SignalTransition {
                targetState: localPairingSuccessState
                signal: d.localPairingFinished
            }
        }

        DSM.State {
            id: localPairingBaseState

            initialState: localPairingInProgressState

            DSM.State {
                id: localPairingInProgressState

                DSM.SignalTransition {
                    targetState: localPairingFailedState
                    signal: d.localPairingFailed
                }

                DSM.SignalTransition {
                    targetState: localPairingSuccessState
                    signal: d.localPairingFinished
                }
            }

            DSM.State {
                id: localPairingFailedState

                DSM.SignalTransition {
                    targetState: finalState
                    signal: nextButton.clicked
                }
            }

            DSM.State {
                id: localPairingSuccessState

                DSM.SignalTransition {
                    targetState: finalState
                    signal: nextButton.clicked
                }
            }
        }

        DSM.State {
            id: errorState

            DSM.SignalTransition {
                targetState: finalState
                signal: nextButton.clicked
            }
        }

        DSM.FinalState {
            id: finalState
            onEntered: {
                root.close()
            }
        }
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
            visible: displaySyncCodeState.active

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
            visible: localPairingBaseState.active
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
            visible: errorState.active
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
                enabled: !localPairingInProgressState.active
                text: {
                    if (displaySyncCodeState.active
                        || localPairingInProgressState.active
                        || localPairingSuccessState.active)
                        return qsTr("Done");
                    if (localPairingFailedState.active
                        || errorState.active)
                        return qsTr("Close");
                    return ""
                }
            }
        }
    }
}
