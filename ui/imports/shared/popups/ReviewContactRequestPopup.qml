import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

import utils

CommonContactDialog {
    id: root

    // expected roles: id, from, clock, text, contactRequestState
    required property var crDetails

    signal contactRequestAccepted(string contactRequestId)
    signal contactRequestDiscarded(string contactRequestId)

    title: qsTr("Review contact request")

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: msgColumn.implicitHeight + msgColumn.anchors.topMargin + msgColumn.anchors.bottomMargin
        color: "transparent"
        border.width: 1
        border.color: Theme.palette.baseColor2
        radius: Theme.radius

        ColumnLayout {
            id: msgColumn
            anchors.fill: parent
            anchors.margins: Theme.padding

            StatusTimeStampLabel {
                Layout.maximumWidth: parent.width
                timestamp: crDetails.clock
            }
            StatusBaseText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: crDetails.text
            }
        }
    }

    rightButtons: ObjectModel {
        StatusFlatButton {
            text: qsTr("Ignore")
            objectName: "ignoreButton"
            onClicked: root.contactRequestDiscarded(crDetails.id ?? "")
        }
        StatusButton {
            text: qsTr("Accept")
            type: StatusBaseButton.Type.Success
            objectName: "acceptButton"
            onClicked: root.contactRequestAccepted(crDetails.id ?? "")
        }
    }
}
