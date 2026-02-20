import QtQuick
import QtQuick.Controls

import QtQml.Models

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

StatusDialog {
    id: root

    property alias body: bodyItem.text
    property alias acceptButtonText: acceptButton.text
    property alias rejectButtonText: rejectButton.text

    implicitWidth: 480
    closePolicy: Popup.NoAutoClose
    
    footer: StatusDialogFooter {
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom
        spacing: 16
        rightButtons: ObjectModel {
            StatusButton {
                id: rejectButton
                type: StatusButton.Danger
                onClicked: {
                    root.reject();
                }
            }
            StatusButton {
                id: acceptButton
                onClicked: {
                    root.accept();
                }
            }
        }
    }

    StatusBaseText {
        id: bodyItem
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }
}
