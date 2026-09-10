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
    readonly property bool markAsUntrusted: d.markAsUntrusted

    title: qsTr("Remove contact")

    QtObject {
        id: d

        property bool removeIDVerification
        property bool markAsUntrusted
    }

    bodyComponent: ColumnLayout {
        spacing: Theme.halfPadding

        StatusBaseText {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.halfPadding
            text: qsTr("You and %1 will no longer be contacts").arg(mainDisplayName)
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
            id: ctrlMarkAsUntrusted
            visible: contactDetails.trustStatus !== Constants.trustStatus.untrustworthy
            text: qsTr("Mark %1 as untrusted").arg(mainDisplayName)
            onCheckedChanged: d.markAsUntrusted = checked
            Component.onCompleted: d.markAsUntrusted = checked
        }
    }

    footerRightButtons: ObjectModel {
        StatusFlatButton {
            text: qsTr("Cancel")
            onClicked: root.close()
        }
        StatusButton {
            type: StatusBaseButton.Type.Danger
            text: qsTr("Remove contact")
            objectName: "removeContactButton"
            onClicked: root.accepted()
        }
    }
}
