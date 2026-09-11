import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

CommonContactAdaptiveDialog {
    id: root

    readonly property bool removeIDVerification: d.removeIDVerification
    readonly property bool removeContact: d.removeContact

    title: qsTr("Mark as untrusted")

    QtObject {
        id: d

        property bool removeIDVerification
        property bool removeContact
    }

    bodyComponent: ColumnLayout {
        spacing: Theme.halfPadding

        StatusBaseText {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.halfPadding
            text: qsTr("%1 will be marked as untrusted. This mark will only be visible to you.").arg(mainDisplayName)
            wrapMode: Text.WordWrap
        }

        StatusCheckBox {
            id: ctrlRemoveIDVerification
            visible: contactDetails.trustStatus === Constants.trustStatus.trusted
            checked: visible
            enabled: false
            text: qsTr("Remove trust mark")
            onCheckedChanged: d.removeIDVerification = checked
            Component.onCompleted: d.removeIDVerification = checked
        }

        StatusCheckBox {
            id: ctrlRemoveContact
            visible: contactDetails.isContact
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
            text: qsTr("Mark as untrusted")
            onClicked: root.accepted()
        }
    }
}
