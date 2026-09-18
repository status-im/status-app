import QtQuick
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Controls

Rectangle {
    id: root

    objectName: "chatItem"
    property string chatId: ""
    property string categoryId: ""
    property string name: ""
    property bool isThread: false
    property alias badge: statusBadge
    property bool hasUnreadMessages: false
    property int notificationsCount: 0
    property bool muted: false
    property int onlineStatus: StatusChatListItem.OnlineStatus.Inactive
    property bool requiresPermissions: false
    property bool locked: false

    property StatusAssetSettings asset: StatusAssetSettings {
        width: 24
        height: 24
        color: root.Theme.palette.miscColor5
        emoji: ""
        useAcronymForLetterIdenticon: root.type === StatusChatListItem.Type.OneToOneChat
        charactersLen: useAcronymForLetterIdenticon ? 2 : 1
    }
    property int type: StatusChatListItem.Type.Unknown0
    property bool highlighted: false
    property bool highlightWhenCreated: false
    property bool selected: false
    property bool dragged: false
    property alias sensor: sensor

    readonly property int verticalPadding: 4
    readonly property int horizontalMargin: Math.max(Theme.halfPadding, 8)

    signal clicked(var mouse)
    signal unmute()

    enum Type {
        Unknown0, // 0
        OneToOneChat, // 1
        PublicChat, // 2
        GroupChat, // 3
        Unknown1, // 4
        Unknown2, // 5
        CommunityChat // 6
    }

    enum OnlineStatus {
        Inactive,
        Online
    }

    implicitWidth: 288
    implicitHeight: 40 + 2 * verticalPadding

    radius: Theme.radius

    color: {
        if (selected) {
            return Theme.palette.statusChatListItem.selectedBackgroundColor
        }
        return hoverHander.hovered || highlighted ? Theme.palette.statusChatListItem.hoverBackgroundColor : Theme.palette.baseColor4
    }

    opacity: dragged ? 0.7 : 1

    StatusMouseArea {
        id: sensor

        HoverHandler {
            id: hoverHander
        }

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => root.clicked(mouse)

        StatusSmartIdenticon {
            id: identicon
            anchors.left: parent.left
            anchors.leftMargin: root.horizontalMargin
            anchors.verticalCenter: parent.verticalCenter
            asset: root.asset
            name: root.name
            active: !root.isThread
            visible: active

            badge {
                visible: root.type === StatusChatListItem.Type.OneToOneChat
                color: root.onlineStatus === StatusChatListItem.OnlineStatus.Online ? Theme.palette.successColor1 : Theme.palette.baseColor1
                border.width: 2
                border.color: hoverHander.hovered ? Theme.palette.statusBadge.hoverBorderColor : root.color
                height: 9
                width: 9
            }
        }

        StatusIcon {
            id: statusIcon
            anchors.left: identicon.right
            anchors.leftMargin: root.isThread ? Theme.defaultXlPadding : Theme.halfPadding
            anchors.verticalCenter: parent.verticalCenter

            width: 16
            visible: root.isThread || root.type !== StatusChatListItem.Type.OneToOneChat
            color: chatName.color
            icon: {
                if (root.isThread)
                    return "thread"
                switch (root.type) {
                case StatusChatListItem.Type.GroupChat:
                    return "tiny/group"
                case StatusChatListItem.Type.CommunityChat: {
                    if (root.requiresPermissions)
                        return root.locked ? "tiny/channel-locked" : "tiny/channel-unlocked"
                    return "tiny/channel"
                }
                default:
                    return "tiny/public-chat"
                }
            }
        }

        StatusBaseText {
            id: chatName
            anchors.left: statusIcon.visible ? statusIcon.right : identicon.right
            anchors.leftMargin: statusIcon.visible ? (root.isThread ? Theme.halfPadding : 1) : Theme.halfPadding
            anchors.right: mutedIcon.visible ? mutedIcon.left :
                                               statusBadge.visible ? statusBadgeContainer.left : parent.right
            anchors.rightMargin: root.horizontalMargin
            anchors.verticalCenter: parent.verticalCenter

            text: root.name
            elide: Text.ElideRight
            color: {
                if (root.muted && !hoverHander.hovered && !root.highlighted) {
                    return Theme.palette.directColor5
                }
                return root.hasUnreadMessages ||
                        root.notificationsCount > 0 ||
                        root.selected ||
                        root.highlighted ||
                        root.highlightWhenCreated ||
                        hoverHander.hovered ||
                        statusBadge.visible ? Theme.palette.directColor1 : Theme.palette.directColor2
            }
            font.weight: !root.muted &&
                         (root.hasUnreadMessages ||
                          root.notificationsCount > 0 ||
                          root.highlightWhenCreated ||
                          statusBadge.visible) ? Font.Bold : Font.Medium
            font.pixelSize: root.isThread ? Theme.fontSize(14) : Theme.primaryTextFontSize
        }

        // most rows are not muted — the icon, its sensor and tooltip only
        // exist while the row actually is
        Loader {
            id: mutedIcon
            anchors.right: statusBadge.visible ? statusBadgeContainer.left : parent.right
            anchors.rightMargin: statusBadge.visible ? root.horizontalMargin : root.horizontalMargin * 2
            anchors.verticalCenter: parent.verticalCenter
            active: root.muted
            visible: active

            sourceComponent: StatusIconWithTooltip {
                width: 16
                height: 16
                opacity: hovered ? 1.0 : 0.2
                icon: "tiny/muted"
                color: chatName.color
                tooltipText: qsTr("Unmute")
                onClicked: root.unmute()
            }
        }
        Item {
            id: statusBadgeContainer
            width: 32
            height: parent.height
            anchors.right: parent.right
            anchors.rightMargin: root.horizontalMargin
            StatusBadge {
                id: statusBadge
                readonly property bool onlyUnread: !root.muted && root.notificationsCount === 0 && root.hasUnreadMessages
                anchors.centerIn: parent
                color: onlyUnread ? Theme.palette.baseColor1 :
                                    root.muted ? Theme.palette.primaryColor2 : Theme.palette.primaryColor1
                border.width: onlyUnread ? -2 : 4
                border.color: color
                value: root.notificationsCount
                visible: (root.notificationsCount > 0 || onlyUnread)
            }
        }
    }
}
