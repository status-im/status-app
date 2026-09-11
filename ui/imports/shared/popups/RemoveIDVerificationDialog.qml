import QtQuick
import QtQuick.Layouts
import QtQml.Models

import utils

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

CommonContactAdaptiveDialog {
    id: root

    readonly property bool markAsUntrusted: d.markAsUntrusted
    readonly property bool removeContact: d.removeContact

    title: qsTr("Remove trust mark")

    QtObject {
        id: d

        property bool markAsUntrusted
        property bool removeContact
    }

    bodyComponent: ColumnLayout {
        spacing: Theme.halfPadding

        StatusBaseText {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.halfPadding
            wrapMode: Text.WordWrap
            text: qsTr("%1 will no longer be marked as trusted. This is only visible to you.").arg(mainDisplayName)
        }

        StatusCheckBox {
            id: ctrlMarkAsUntrusted
            text: qsTr("Mark %1 as untrusted").arg(mainDisplayName)
            onCheckedChanged: d.markAsUntrusted = checked
            Component.onCompleted: d.markAsUntrusted = checked
        }

        StatusCheckBox {
            id: ctrlRemoveContact
            text: qsTr("Remove contact")
            onCheckedChanged: d.removeContact = checked
            Component.onCompleted: d.removeContact = checked
        }
    }

    footerRightButtons: ObjectModel {
        StatusFlatButton {
            text: qsTr("Cancel")
            onClicked: root.close()
        }
        StatusButton {
            type: StatusBaseButton.Type.Danger
            text: qsTr("Remove trust mark")
            onClicked: root.accepted()
        }
    }
}
