import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import utils

import shared.panels
import shared.popups
import shared.controls
import shared.status

import SortFilterProxyModel

import AppLayouts.Profile.stores as ProfileStores
import "../popups"

SettingsContentBase {
    id: root

    property ProfileStores.DevicesStore devicesStore
    property ProfileStores.ProfileStore profileStore
    property ProfileStores.PrivacyStore privacyStore
    property ProfileStores.AdvancedStore advancedStore

    ColumnLayout {
        id: layout
        width: root.contentWidth
        spacing: Theme.padding

        QtObject {
            id: d

            readonly property var instructionsModel: [
                qsTr("Verify your login with password or Keycard"),
                qsTr("Reveal a temporary QR and Sync Code") + "*",
                qsTr("Share that information with your new device"),
            ]

            property bool messageSyncingEnabled: false

            function personalizeDevice(model) {
                Global.openPopup(personalizeDevicePopup, {
                                     "deviceModel": model
                                 })
            }

            function setupPair(installationId) {
                Global.openPopup(pairDeviceDialogComponent, {
                                     "installationId": installationId
                                 })
            }

            function setupUnpair(installationId) {
                Global.openPopup(unpairDeviceDialogComponent, {
                                     "installationId": installationId
                                 })
            }

            function setupDeleteDevice(installationId) {
                Global.openPopup(deleteDeviceDialogComponent, {
                                     "installationId": installationId
                                 })
            }

            function setupSyncing() {
                root.devicesStore.generateConnectionStringAndRunSetupSyncingPopup(messageSyncingEnabled)
            }
        }


        Connections {
            target: devicesStore.devicesModule

            function onOpenPopupWithConnectionStringSignal(rawConnectionString) {
                Global.openPopup(setupSyncingPopup, {
                                     rawConnectionString: rawConnectionString,
                                 })
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: qsTr("Devices")
            color: Theme.palette.baseColor1
        }

        StatusBaseText {
            Layout.fillWidth: true
            visible: root.devicesStore.devicesModule.devicesLoading
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Loading devices...")
        }

        StatusBaseText {
            Layout.fillWidth: true
            visible: root.devicesStore.devicesModule.devicesLoadingError
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Error loading devices. Please try again later.")
            color: Theme.palette.dangerColor1
        }

        StatusListView {
            Layout.fillWidth: true
            implicitHeight: contentHeight

            interactive: false
            spacing: 0
            visible: !root.devicesStore.devicesModule.devicesLoading &&
                     !root.devicesStore.devicesModule.devicesLoadingError &&
                     root.devicesStore.isDeviceSetup

            model: SortFilterProxyModel {
                sourceModel: root.devicesStore.devicesModel
                sorters: [
                    RoleSorter {
                        roleName: "isCurrentDevice"
                        sortOrder: Qt.DescendingOrder
                        priority: 2
                    },
                    RoleSorter {
                        roleName: "enabled"
                        sortOrder: Qt.DescendingOrder
                        priority: 1 // Higher number === higher priority
                    }
                ]
            }

            delegate: StatusSyncDeviceDelegate {
                width: ListView.view.width
                deviceName: model.name
                deviceType: model.deviceType
                deviceEnabled: model.enabled
                timestamp: model.timestamp
                isCurrentDevice: model.isCurrentDevice
                onPairRequested: {
                    d.setupPair(model.installationId)
                }
                onUnpairRequested: {
                    d.setupUnpair(model.installationId)
                }
                onClicked: {
                    d.personalizeDevice(model)
                }
            }
        }

        Control {
            Layout.preferredWidth: parent.width * .75
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.padding

            horizontalPadding: Theme.padding
            verticalPadding: Theme.xlPadding

            background: Rectangle {
                color: Theme.palette.primaryColor3
                radius: Theme.radius
            }

            contentItem: ColumnLayout {
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true

                    horizontalAlignment: Text.AlignHCenter
                    objectName: "syncNewDeviceTextLabel"
                    elide: Text.ElideRight
                    color: Theme.palette.primaryColor1
                    font.pixelSize: Theme.secondaryAdditionalTextSize
                    font.weight: Font.Bold
                    text: qsTr("Sync a New Device")
                }

                StatusBaseText {
                    objectName: "syncNewDeviceSubTitleTextLabel"

                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.palette.baseColor1
                    font.weight: Font.Medium
                    text: qsTr("You own your data. Sync it among your devices.")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.xlPadding

                    Repeater {
                        model: d.instructionsModel
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            StatusBaseText {
                                color: Theme.palette.baseColor1
                                font.pixelSize: Theme.additionalTextSize
                                font.weight: Font.Medium
                                text: index + 1
                            }
                            StatusBaseText {
                                Layout.fillWidth: true
                                text: modelData
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.halfPadding

                        StatusCheckBox {
                            Layout.fillWidth: true
                            objectName: "enableMessageSyncingCheckBox"

                            text: qsTr("Restore my past messages to this device")
                            leftSide: true
                            checked: false
                            onToggled: d.messageSyncingEnabled = checked
                        }

                        StatusFlatRoundButton {
                            Layout.rightMargin: Theme.padding
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: width
                            radius: width/2
                            icon.name: "help"
                            tooltip.text: qsTr("Copies and sends your direct, group, and community messages to your new device using encrypted local pairing.")
                        }
                    }
                }

                StatusButton {
                    objectName: "setupSyncingStatusButton"

                    Layout.alignment: Qt.AlignHCenter
                    type: StatusBaseButton.Type.Primary
                    text: qsTr("Setup Syncing")
                    onClicked: d.setupSyncing()
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                    text: "* " + qsTr("This is best done in private. The code will grant access to your profile.")
                    wrapMode: Text.Wrap
                }
            }
        }

        StatusFlatButton {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("How to get a sync code")
            icon.name: "info"
            onClicked: Global.openPopup(getSyncCodeInstructionsPopup)
        }

        Component {
            id: personalizeDevicePopup

            SyncDeviceCustomizationPopup {
                destroyOnClose: true
                devicesStore: root.devicesStore
                advancedStore: root.advancedStore
                onDeleteDeviceRequested: installationId => d.setupDeleteDevice(installationId)
            }
        }

        Component {
            id: setupSyncingPopup

            SetupSyncingPopup {
                destroyOnClose: true
                devicesStore: root.devicesStore
                profileStore: root.profileStore
            }
        }

        Component {
            id: pairDeviceDialogComponent
            ConfirmationDialog {
                property string installationId

                id: pairDeviceDialog
                destroyOnClose: true
                headerSettings.title: qsTr("Pair Device")
                confirmationText: qsTr("Are you sure you want to pair this device?")
                confirmButtonLabel: qsTr("Pair")
                btnType: "normal"
                onConfirmButtonClicked: {
                    const error = devicesStore.devicesModule.pairDevice(installationId)
                    if (error) {
                        pairDeviceDialog.confirmationText = qsTr("Error pairing device: %1").arg(error)
                    } else {
                        Global.closePopup()
                    }
                }
            }
        }

        Component {
            id: unpairDeviceDialogComponent
            ConfirmationDialog {
                property string installationId

                id: unpairDeviceDialog
                destroyOnClose: true
                headerSettings.title: qsTr("Unpair Device")
                confirmationText: qsTr("Are you sure you want to unpair this device?")
                confirmButtonLabel: qsTr("Unpair")
                onConfirmButtonClicked: {
                    const error = devicesStore.devicesModule.unpairDevice(installationId)
                    if (error) {
                        unpairDeviceDialog.confirmationText = qsTr("Error unpairing device: %1").arg(error)
                    } else {
                        Global.closePopup()
                    }
                }
            }
        }

        Component {
            id: deleteDeviceDialogComponent
            ConfirmationDialog {
                property string installationId

                id: deleteDeviceDialog
                destroyOnClose: true
                headerSettings.title: qsTr("Delete Device")
                confirmationText: qsTr("Are you sure you want to delete this device?\nThis action cannot be undone.")
                confirmButtonLabel: qsTr("Delete")
                onConfirmButtonClicked: {
                    const error = devicesStore.devicesModule.deleteDevice(installationId)
                    if (error) {
                        deleteDeviceDialog.confirmationText = qsTr("Error deleting device: %1").arg(error)
                    } else {
                        Global.closePopup()
                    }
                }
            }
        }

        Component {
            id: getSyncCodeInstructionsPopup
            GetSyncCodeInstructionsPopup {
                destroyOnClose: true
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }
    }
}
