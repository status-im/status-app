import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils

import shared.controls

import AppLayouts.Profile.stores as ProfileStores

StatusDialog {
    id: root

    property ProfileStores.DevicesStore devicesStore
    property ProfileStores.AdvancedStore advancedStore
    property var deviceModel

    readonly property string deviceName: d.deviceName

    signal deleteDeviceRequested(string installationId)

    title: qsTr("Personalize %1").arg(deviceModel.name)
    width: implicitWidth
    padding: 16

    QtObject {
        id: d
        property string deviceName: ""

        function saveNewName() {
            if (!nameInput.valid)
                return
            root.devicesStore.setInstallationName(root.deviceModel.installationId, nameInput.text.trim())
            root.close()
        }
    }

    onOpened: {
        nameInput.text = deviceModel.name
        nameInput.forceActiveFocus()
    }

    contentItem: ColumnLayout {
        spacing: 8
        StatusInput {
            id: nameInput
            Layout.fillWidth: true
            label: qsTr("Device name")
            validators: [
                StatusValidator {
                    errorMessage: qsTr("Device name can not be empty")
                    validate: (value) => {
                                  return value.trim() !== ""
                              }
                }

            ]
            Keys.onReturnPressed: {
                d.saveNewName()
            }
        }
        StatusInput {
            id: idInput
            Layout.fillWidth: true
            label: qsTr("Installation ID")
            enabled: false
            text: root.deviceModel.installationId
            visible: root.advancedStore.isDebugEnabled
        }
    }

     footer: StatusDialogFooter {
        leftButtons: ObjectModel {
            StatusButton {
                text: qsTr("Delete Device")
                type: StatusBaseButton.Type.Danger
                onClicked : {
                    root.deleteDeviceRequested(root.deviceModel.installationId)
                    root.close()
                }
            }
        }

        rightButtons: ObjectModel {
            StatusButton {
                text: qsTr("Done")
                enabled: nameInput.valid
                onClicked : {
                    d.saveNewName()
                }
            }
        }
    }
}
