import QtQuick

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import shared.controls.delegates

ContactListItemDelegate {
    id: root

    property bool showSendMessageButton: false
    property bool showRejectContactRequestButton: false
    property bool showAcceptContactRequestButton: false
    property bool showRemoveRejectionButton: false
    property string contactText: ""

    signal contextMenuRequested
    signal sendMessageRequested
    signal acceptContactRequested
    signal rejectRequestRequested
    signal removeRejectionRequested

    icon.width: 40
    icon.height: 40

    components: [
        StatusFlatRoundButton {
            objectName: "chatBtn"
            visible: showSendMessageButton
            width: visible ? 32 : 0
            height: visible ? 32 : 0
            icon.name: "chat"
            icon.color: Theme.palette.directColor1
            tooltip.text: qsTr("Send message")
            onClicked: root.sendMessageRequested()

            StatusToolTip {
                text: qsTr('Send message')
                visible: parent.hovered
            }
        },
        StatusFlatRoundButton {
            objectName: "declineBtn"
            visible: showRejectContactRequestButton
            width: visible ? 32 : 0
            height: visible ? 32 : 0
            icon.name: "close-circle"
            icon.color: Theme.palette.dangerColor1
            tooltip.text: qsTr("Reject")
            Accessible.name: Utils.formatAccessibleName(
                tooltip.text,
                "ContactsView_PendingRequestDecline_Button"
            )
            onClicked: root.rejectRequestRequested()

            StatusToolTip {
                text: qsTr('Decline Request')
                visible: parent.hovered
            }
        },
        StatusFlatRoundButton {
            objectName: "acceptBtn"
            visible: showAcceptContactRequestButton
            width: visible ? 32 : 0
            height: visible ? 32 : 0
            icon.name: "checkmark-circle"
            icon.color: Theme.palette.successColor1
            tooltip.text: qsTr("Accept")
            Accessible.name: Utils.formatAccessibleName(
                tooltip.text,
                "ContactsView_PendingRequestAccept_Button"
            )
            onClicked: root.acceptContactRequested()

            StatusToolTip {
                text: qsTr('Accept Request')
                visible: parent.hovered
            }
        },
        StatusFlatRoundButton {
            objectName: "removeRejectBtn"
            visible: showRemoveRejectionButton
            width: visible ? 32 : 0
            height: visible ? 32 : 0
            icon.name: "cancel"
            icon.color: Theme.palette.dangerColor1
            onClicked: root.removeRejectionRequested()

            StatusToolTip {
                text: qsTr('Remove Rejection')
                visible: parent.hovered
            }
        },
        StatusBaseText {
            text: root.contactText
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.palette.baseColor1
        },
        StatusFlatRoundButton {
            objectName: "moreBtn"
            width: 32
            height: 32
            icon.name: "more"
            icon.color: Theme.palette.directColor1
            onClicked: root.contextMenuRequested()
        }
    ]
}
