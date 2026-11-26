import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import shared.panels

// Offered while the profile has no password of its own
ModuleWarning {
    id: root

    signal setPasswordRequested()
    signal createOrLoginRequested()

    type: ModuleWarning.Warning
    collapsible: true
    delay: false

    actions: RowLayout {
        spacing: Theme.halfPadding

        ModuleWarningButton {
            objectName: "setPasswordButton"
            text: qsTr("Set password")
            icon.name: "password"
            onClicked: root.setPasswordRequested()
        }
        StatusBaseText {
            objectName: "orText"
            text: qsTr("or")
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Medium
            color: Theme.palette.indirectColor1
        }
        ModuleWarningButton {
            objectName: "createOrLoginButton"
            text: qsTr("Create / Log in")
            icon.name: "profile/contacts"
            onClicked: root.createOrLoginRequested()
        }
    }
}
