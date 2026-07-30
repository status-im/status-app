import QtQuick
import QtQuick.Controls // for the Popup.xxx enums
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

StatusDialog {
    id: root

    width: 440
    padding: Theme.smallPadding*2
    topPadding: Theme.xlPadding
    bottomPadding: Theme.xlPadding

    closePolicy: Popup.NoAutoClose

    title: qsTr("Enable full message history")

    contentItem: ColumnLayout {
        spacing: Theme.xlPadding

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("Enabling the Community History Service ensures every member can view the complete message history for all channels they have permission to view. Without this feature, message history will be limited to the last 30 days. Your computer, which is the control node for the community, must remain online for this to work.")
        }

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.palette.directColor5
            text: qsTr("This service operates using the Archive Protocol, which will be automatically enabled using Logos Storage by default.")
        }
    }

    footer: StatusDialogFooter {
        spacing: Theme.padding
        rightButtons: ObjectModel {
            StatusFlatButton {
                objectName: "readMoreStatusFlatButton"
                icon.name: "external-link"
                text: qsTr("Read more")
                onClicked: root.accept()
            }

            StatusButton {
                objectName: "gotItStatusFlatButton"
                text: qsTr("Got it")
                onClicked: root.close()
            }
        }
    }
}
