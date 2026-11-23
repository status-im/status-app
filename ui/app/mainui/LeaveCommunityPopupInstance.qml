import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups

import AppLayouts.Communities.stores as CommunitiesStores

StatusModal {
    id: root

    required property CommunitiesStores.CommunitiesStore communitiesStore

    property string community
    property string communityId
    property string outroMessage

    headerSettings.title: qsTranslate("Popups", "Are you sure want to leave '%1'?").arg(community)
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
            text: qsTranslate("Popups", "You will need to request to join if you want to become a member again in the future. If you joined the Community via public key ensure you have a copy of it before you go.")
        }
    }

    rightButtons: [
        StatusFlatButton {
            text: qsTranslate("Popups", "Cancel")
            onClicked: root.close()
        },
        StatusButton {
            objectName: "CommunitiesListPanel_leaveCommunityButtonInPopup"
            type: StatusBaseButton.Type.Danger
            text: qsTranslate("Popups", "Leave %1").arg(root.community)
            onClicked: {
                root.close()
                root.communitiesStore.leaveCommunity(root.communityId)
            }
        }
    ]
}
