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
        color: Theme.palette.miscColor5
        emoji: ""
        charactersLen: root.type === StatusChatListItem.Type.OneToOneChat ? 2 : 1
    }
    property int type: StatusChatListItem.Type.Unknown0
    property bool highlighted: false
    property bool highlightWhenCreated: false
    property bool selected: false
    property bool dragged: false
    property alias sensor: sensor

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
    implicitHeight: 40

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

        onClicked: root.clicked(mouse)

        StatusSmartIdenticon {
            id: identicon
            anchors.left: parent.left
            anchors.leftMargin: Theme.halfPadding
            anchors.verticalCenter: parent.verticalCenter
            asset: root.asset
            name: root.name

            badge {
                visible: root.type === StatusChatListItem.Type.OneToOneChat
                color: onlineStatus === StatusChatListItem.OnlineStatus.Online ? Theme.palette.successColor1 : Theme.palette.baseColor1
                border.width: 2
                border.color: hoverHander.hovered ? Theme.palette.statusBadge.hoverBorderColor : root.color
                height: 9
                width: 9
            }
        }

        StatusIcon {
            id: statusIcon
            anchors.left: identicon.right
            anchors.leftMargin: Theme.halfPadding
            anchors.verticalCenter: parent.verticalCenter

            width: 16
            visible: root.type !== StatusChatListItem.Type.OneToOneChat
            opacity: {
                if (root.muted && !hoverHander.hovered && !root.highlighted) {
                    return ThemeUtils.disabledOpacity
                }
                return root.hasUnreadMessages ||
                        root.notificationsCount > 0 ||
                        root.selected ||
                        root.highlighted ||
                        statusBadge.visible ||
                        hoverHander.hovered ? 1.0 : 0.7
            }

            icon: {
                switch (root.type) {
                case StatusChatListItem.Type.GroupChat:
                    return Theme.palette.name === "light" ? "tiny/group" : "tiny/group-white"
                case StatusChatListItem.Type.CommunityChat: {
                    var iconName = "tiny/channel"
                    if (root.requiresPermissions)
                        iconName = root.locked ? "tiny/channel-locked" : "tiny/channel-unlocked"
                    return Theme.palette.name === "light" ? iconName : iconName+"-white"
                }
                default:
                    return Theme.palette.name === "light" ? "tiny/public-chat" : "tiny/public-chat-white"
                }
            }
        }

        StatusBaseText {
            id: chatName
            anchors.left: statusIcon.visible ? statusIcon.right : identicon.right
            anchors.leftMargin: statusIcon.visible ? 1 : Theme.halfPadding
            anchors.right: mutedIcon.visible ? mutedIcon.left :
                                               statusBadge.visible ? statusBadgeContainer.left : parent.right
            anchors.rightMargin: Theme.halfPadding
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
                        statusBadge.visible ? Theme.palette.directColor1 : Theme.palette.directColor4
            }
            font.weight: !root.muted &&
                         (root.hasUnreadMessages ||
                          root.notificationsCount > 0 ||
                          root.highlightWhenCreated ||
                          statusBadge.visible) ? Font.Bold : Font.Medium
            font.pixelSize: Theme.primaryTextFontSize
        }

        StatusIcon {
            id: mutedIcon
            anchors.right: statusBadge.visible ? statusBadgeContainer.left : parent.right
            anchors.rightMargin: Theme.halfPadding
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            opacity: mutedIconSensor.containsMouse ? 1.0 : 0.2
            icon: Theme.palette.name === "light" ? "tiny/muted" : "tiny/muted-white"
            visible: root.muted

            StatusMouseArea {
                id: mutedIconSensor
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked: root.unmute()
            }

            StatusToolTip {
                text: qsTr("Unmute")
                visible: mutedIconSensor.containsMouse
            }
        }
        Item {
            id: statusBadgeContainer
            width: 32
            height: parent.height
            anchors.right: parent.right
            anchors.rightMargin: Theme.halfPadding
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
