import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups

StatusModal {
    id: root

    property string community
    property string communityId
    property string outroMessage

    signal leaveRequested(string communityId)

    headerSettings.title: qsTr("Are you sure want to leave '%1'?").arg(community)
    padding: 16
    width: 640
    contentItem: ColumnLayout {
        spacing: 16
        StatusBaseText {
            id: outroMessage
            Layout.fillWidth: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            text: root.outroMessage
            visible: !!text
        }
        StatusMenuSeparator {
            Layout.fillWidth: true
            visible: outroMessage.visible
        }
        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font.pixelSize: Theme.additionalTextSize
            text: qsTr("You will need to request to join if you want to become a member again in the future. If you joined the Community via public key ensure you have a copy of it before you go.")
        }
    }

    rightButtons: [
        StatusFlatButton {
            text: qsTr("Cancel")
            onClicked: root.close()
        },
        StatusButton {
            objectName: "CommunitiesListPanel_leaveCommunityButtonInPopup"
            type: StatusBaseButton.Type.Danger
            text: qsTr("Leave %1").arg(root.community)
            onClicked: {
                root.close()
                root.leaveRequested(root.communityId)
            }
        }
    ]
}
