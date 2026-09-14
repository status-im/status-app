import QtQuick
import QtQuick.Layouts
import QtQml.Models

import utils

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

CommonContactAdaptiveDialog {
    id: root

    readonly property bool markAsUntrusted: root.hostedItem?.bodyItem?.markAsUntrusted ?? false
    readonly property bool removeContact: root.hostedItem?.bodyItem?.removeContact ?? false

    title: qsTr("Remove trust mark")

    bodyComponent: ColumnLayout {
        readonly property alias markAsUntrusted: ctrlMarkAsUntrusted.checked
        readonly property alias removeContact: ctrlRemoveContact.checked

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
        }

        StatusCheckBox {
            id: ctrlRemoveContact
            text: qsTr("Remove contact")
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
