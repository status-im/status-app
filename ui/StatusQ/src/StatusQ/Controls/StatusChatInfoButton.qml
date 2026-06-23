import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Universal

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

Button {
    id: root
    objectName: "chatInfoButton"

    property string title: text
    property string subTitle
    property bool muted
    property int pinnedMessagesCount
    property bool requiresPermissions
    property bool locked
    property bool forceHideTypeIcon: false

    property StatusAssetSettings asset: StatusAssetSettings {
        width: 36
        height: 36
        charactersLen: 2
    }

    property int type: StatusChatInfoButton.Type.Unknown0
    property alias tooltip: statusToolTip

    signal pinnedMessagesCountClicked()
    signal unmute()
    signal linkActivated(string link)

    enum Type {
        Unknown0, // 0
        OneToOneChat, // 1
        PublicChat, // 2
        GroupChat, // 3
        Unknown1, // 4
        Unknown2, // 5
        CommunityChat // 6
    }

    horizontalPadding: 4
    verticalPadding: 2
    spacing: 4

    HoverHandler {
        enabled: root.hoverEnabled
        cursorShape: hovered ? Qt.PointingHandCursor : undefined
    }

    background: Rectangle {
        radius: Theme.radius
        color: root.enabled && root.hovered ? Theme.palette.baseColor2 : "transparent"
    }

    component TruncatedTextWithTooltip: StatusBaseText {
        readonly property alias hovered: truncatedHandler.hovered

        elide: Text.ElideRight

        StatusToolTip {
            text: parent.text
            visible: truncatedHandler.hovered && parent.truncated
            orientation: StatusToolTip.Orientation.Bottom
            delay: 500
            y: parent.height + 12
        }

        HoverHandler {
            id: truncatedHandler
            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : undefined
        }
    }

    contentItem: RowLayout {
        spacing: root.spacing

        // identicon
        StatusSmartIdenticon {
            id: identicon
            asset: root.asset
            name: root.title
        }

        // text
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // title
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeading | Qt.AlignBottom
                spacing: 2

                StatusIcon {
                    visible: root.type !== StatusChatInfoButton.Type.OneToOneChat && !root.forceHideTypeIcon && icon
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    color: root.muted ? Theme.palette.baseColor1 : Theme.palette.directColor1
                    icon: {
                        switch (root.type) {
                        case StatusChatInfoButton.Type.PublicChat:
                            return "tiny/public-chat"
                        case StatusChatInfoButton.Type.GroupChat:
                            return "tiny/group"
                        case StatusChatInfoButton.Type.CommunityChat: {
                            var iconName = "tiny/channel"
                            if (root.requiresPermissions)
                                iconName = root.locked ? "tiny/channel-locked" : "tiny/channel-unlocked"
                            return iconName
                        }
                        default:
                            return ""
                        }
                    }
                }

                TruncatedTextWithTooltip {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.ceil(implicitWidth)
                    objectName: "statusChatInfoButtonNameText"
                    text: root.title
                    Accessible.role: Accessible.StaticText
                    Accessible.name: root.title
                    color: root.muted ? Theme.palette.directColor5 : Theme.palette.directColor1
                    font.weight: Font.Medium
                }

                StatusIcon {
                    objectName: "mutedIcon"
                    Layout.preferredWidth: 13
                    Layout.preferredHeight: 13
                    icon: "tiny/muted"
                    color: mutedIconSensor.containsMouse ? Theme.palette.directColor1 : Theme.palette.baseColor1
                    visible: root.muted

                    StatusMouseArea {
                        id: mutedIconSensor
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        onClicked: root.unmute()
                    }

                    StatusToolTip {
                        id: statusToolTip
                        text: qsTr("Unmute")
                        visible: mutedIconSensor.containsMouse
                        orientation: StatusToolTip.Orientation.Bottom
                        y: parent.height + 12
                    }
                }
            }

            // subtitle
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeading | Qt.AlignTop
                visible: root.subTitle || root.pinnedMessagesCount
                spacing: 0

                TruncatedTextWithTooltip {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.ceil(implicitWidth)
                    text: root.subTitle
                    visible: text
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.tertiaryTextFontSize
                    onLinkActivated: (link) => root.linkActivated(link)
                }

                Rectangle {
                    Layout.preferredHeight: 12
                    Layout.preferredWidth: 1
                    Layout.leftMargin: 4
                    Layout.rightMargin: 2
                    color: Theme.palette.directColor7
                    visible: root.subTitle && root.pinnedMessagesCount
                }

                StatusIcon {
                    Layout.preferredHeight: 14
                    Layout.preferredWidth: 14
                    visible: root.pinnedMessagesCount
                    icon: "pin"
                    color: pinText.hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
                }

                TruncatedTextWithTooltip {
                    id: pinText
                    objectName: "StatusChatInfo_pinText"
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.ceil(implicitWidth)
                    text: qsTr("%Ln pinned message(s)", "", root.pinnedMessagesCount)
                    font.pixelSize: Theme.tertiaryTextFontSize
                    font.underline: hovered
                    visible: root.pinnedMessagesCount
                    color: hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: parent.enabled && parent.visible
                        cursorShape: containsMouse ? Qt.PointingHandCursor : undefined
                        onClicked: root.pinnedMessagesCountClicked()
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
    }
}
