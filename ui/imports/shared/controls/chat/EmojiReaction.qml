import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components

import utils
import shared
import shared.panels

Rectangle {
    id: root

    required property string emojiId

    property int emojiSize: 23
    property bool reactedByUser: false
    property bool isHovered: false
    signal toggleReaction()

    width: statusEmoji.width + Theme.halfPadding
    height: width
    color: reactedByUser ? Theme.palette.secondaryBackground :
                           (isHovered ? Theme.palette.backgroundHover : StatusColors.transparent)
    border.width: reactedByUser ? 1 : 0
    border.color: Theme.palette.primaryColor1
    radius: Theme.radius

    Accessible.role: Accessible.Button
    Accessible.name: root.emojiId

    StatusEmoji {
        id: statusEmoji
        objectName: "emojiReaction_statusEmoji"
        anchors.centerIn: parent
        width: root.emojiSize
        height: root.emojiSize
        // emojiId is what the backend knows this reaction by; the character comes from
        // the catalogue, which has the fully-qualified form (❤️, not ❤)
        emoji: SQUtils.Emoji.emojiModel.getEmojiFromHexcode(root.emojiId)
               || SQUtils.Emoji.getEmojiCodepoint(root.emojiId)
    }

    StatusMouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: !reactedByUser
        onEntered: root.isHovered = true
        onExited: root.isHovered = false
        onClicked: root.toggleReaction()
    }
}
