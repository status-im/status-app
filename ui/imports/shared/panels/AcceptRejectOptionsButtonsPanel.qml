import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Popups

import utils
import shared.controls.chat.menuItems

Row {
    id: root
    height: declineBtn.height
    spacing: Theme.halfPadding

    property alias menuButton: menuButton

    signal acceptClicked()
    signal declineClicked()
    signal blockClicked()
    signal profileClicked()
    signal detailsClicked()

    StatusFlatRoundButton {
        objectName: "declineBtn"
        id: declineBtn
        width: 32
        height: 32
        anchors.verticalCenter: parent.verticalCenter
        icon.name: "close-circle"
        icon.color: Theme.palette.dangerColor1
        backgroundHoverColor: Utils.setColorAlpha(Theme.palette.dangerColor1, 0.1)
        Accessible.name: Utils.formatAccessibleName(
            qsTr("Decline"),
            "AcceptRejectOptions_Decline_Button"
        )
        onClicked: root.declineClicked()
    }

    StatusFlatRoundButton  {
        objectName: "acceptBtn"
        id: acceptBtn
        width: 32
        height: 32
        anchors.verticalCenter: parent.verticalCenter
        icon.name: "checkmark-circle"
        icon.color: Theme.palette.successColor1
        backgroundHoverColor: Utils.setColorAlpha(Theme.palette.successColor1, 0.1)
        Accessible.name: Utils.formatAccessibleName(
            qsTr("Accept"),
            "AcceptRejectOptions_Accept_Button"
        )
        onClicked: root.acceptClicked()
    }

    StatusFlatRoundButton {
        objectName: "moreBtn"
        id: menuButton
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        icon.name: "more"
        type: StatusFlatRoundButton.Type.Secondary
        onClicked: {
            highlighted = true
            contactContextMenu.popup(-contactContextMenu.width+menuButton.width, menuButton.height + 4)
        }

        StatusMenu {
            id: contactContextMenu

            onClosed: {
                menuButton.highlighted = false
            }

            ViewProfileMenuItem {
                onTriggered: root.profileClicked()
            }

            StatusAction {
                text: qsTr("Details")
                icon.name: "info"
                onTriggered: root.detailsClicked()
            }

            StatusMenuSeparator {}

            StatusAction {
                text: qsTr("Decline and block")
                icon.name: "cancel"
                type: StatusAction.Type.Danger
                onTriggered: root.blockClicked()
            }
        }
    }
}
