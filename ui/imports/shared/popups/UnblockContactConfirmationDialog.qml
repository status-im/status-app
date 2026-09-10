import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import utils

import StatusQ.Core
import StatusQ.Controls

CommonContactAdaptiveDialog {
    id: root

    title: qsTr("Unblock user")

    bodyComponent: StatusBaseText {
        objectName: "unblockingText"
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Unblocking %1 will allow new messages you receive from %1 to reach you.").arg(mainDisplayName)
    }

    footerRightButtons: ObjectModel {
        StatusFlatButton {
            objectName: "cancelButton"
            text: qsTr("Cancel")
            onClicked: root.close()
        }
        StatusButton {
            objectName: "unblockUserButton"
            type: StatusBaseButton.Type.Danger
            text: qsTr("Unblock")
            onClicked: root.accepted()
        }
    }
}
