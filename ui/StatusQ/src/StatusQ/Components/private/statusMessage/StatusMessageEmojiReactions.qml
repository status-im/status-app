import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls
import StatusQ.Components

Flow {
    id: root
    objectName: "statusMessageEmojiReactions"

    spacing: Theme.defaultHalfPadding/2

    signal addEmojiClicked(var sender, var mouse)
    signal hoverChanged(bool hovered)
    signal toggleReaction(string hexcode)

    property var reactionsModel
    property bool limitReached: false
    property bool messageHighlighted

    QtObject {
        id: d

        function showReactionAuthors(jsonArrayOfUsersReactedWithThisEmoji, emoji) {
            if (!jsonArrayOfUsersReactedWithThisEmoji) {
                return
            }
            const listOfUsers = JSON.parse(jsonArrayOfUsersReactedWithThisEmoji)
            if (listOfUsers.error) {
                console.error("error parsing users who reacted to a message, error: ", obj.error)
                return
            }

            const maxReactions = 12
            const extraCount = listOfUsers.splice(maxReactions).length
            if (extraCount > 0) {
                listOfUsers.push(qsTr("%1 more").arg(extraCount)) // "a, b, ... and N more"
            }

            // Create a simple comma-separated list without using QLocale.createSeparatedList (not available in QML)
            return qsTr("%1 reacted with %2").arg(listOfUsers.join(", ")).arg(StatusQUtils.Emoji.fromCodePoint(emoji))
        }

        // design values
        readonly property int iconSize: 22
        readonly property int cornerRadius: 12
        readonly property int buttonWidth: 36
        readonly property int buttonHeight: 32
    }

    Repeater {
        model: root.reactionsModel

        StatusButton {
            id: reactionDelegate
            objectName: "messageReaction_" + model.emoji

            Accessible.role: Accessible.Button
            Accessible.name: model.emoji

            size: StatusBaseButton.Size.Small
            horizontalPadding: Theme.defaultHalfPadding
            verticalPadding: Theme.defaultHalfPadding/2
            spacing: Theme.defaultHalfPadding

            background: Rectangle {
                implicitWidth: d.buttonWidth
                implicitHeight: d.buttonHeight
                topLeftRadius: 0
                topRightRadius: d.cornerRadius
                bottomLeftRadius: d.cornerRadius
                bottomRightRadius: d.cornerRadius
                color: {
                    if (reactionDelegate.hovered) {
                        return Theme.palette.statusMessage.emojiReactionBackgroundHovered
                    }
                    return model.didIReactWithThisEmoji ? Theme.palette.primaryColor2 : Theme.palette.statusMessage.emojiReactionBackground
                }
                border.width: model.didIReactWithThisEmoji || reactionDelegate.hovered || root.messageHighlighted ? 1 : 0
                border.color: model.didIReactWithThisEmoji ? Theme.palette.primaryColor1 : Theme.palette.statusMessage.emojiReactionBorderHovered
            }

            contentItem: RowLayout {
                spacing: reactionDelegate.spacing

                StatusIcon {
                    objectName: "emojiReaction"
                    Layout.preferredWidth: d.iconSize
                    Layout.preferredHeight: d.iconSize

                    icon: Assets.emoji(model.emoji)
                }

                StatusBaseText {
                    text: model.numberOfReactions
                    font.pixelSize: Theme.fontSize(13)
                }
            }

            StatusToolTip {
                visible: reactionDelegate.hovered
                maxWidth: 400
                text: d.showReactionAuthors(model.jsonArrayOfUsersReactedWithThisEmoji, model.emoji) || ""
            }

            HoverHandler {
                cursorShape: hovered ? Qt.PointingHandCursor : undefined
                onHoveredChanged: root.hoverChanged(hovered)
            }

            onClicked: root.toggleReaction(model.emoji)
        }
    }

    StatusFlatButton {
        width: d.buttonWidth
        height: d.buttonHeight
        visible: root.enabled
        icon.name: "reaction-b"
        icon.width: d.iconSize
        icon.height: d.iconSize
        size: StatusBaseButton.Size.Small
        icon.color: hovered && !root.limitReached ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
        tooltip.text: root.limitReached ? qsTr("Maximum number of different reactions reached") : qsTr("Add reaction")

        // We use a MouseArea because we need to pass the mouse event to the signal
        StatusMouseArea {
            anchors.fill: parent
            cursorShape: !root.limitReached ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: (mouse) => {
                mouse.accepted = true
                if (root.limitReached)
                    return
                root.addEmojiClicked(this, mouse)
            }
        }
    }
}
