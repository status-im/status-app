pragma ComponentBehavior: Bound

import QtQuick

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
                console.error("error parsing users who reacted to a message, error: ", listOfUsers.error)
                return
            }

            const maxReactions = 12
            const extraCount = listOfUsers.splice(maxReactions).length
            if (extraCount > 0) {
                listOfUsers.push(qsTr("%1 more").arg(extraCount)) // "a, b, ... and N more"
            }

            const authors = Qt.locale(Qt.uiLanguage).createSeparatedList(listOfUsers) // "a, b, c and d"
            // the catalogue has the fully-qualified character; decoding the id drops U+FE0F
            const character = StatusQUtils.Emoji.emojiModel.getEmojiFromHexcode(emoji)
                              || StatusQUtils.Emoji.getEmojiCodepoint(emoji)
            return qsTr("%1 reacted with %2").arg(authors).arg(character)
        }

        // Read once here: a Theme.* lookup inside a delegate creates a Theme
        // attached object for every item it is made in
        readonly property real padding: root.Theme.defaultHalfPadding
        readonly property real countFontSize: root.Theme.fontSize(13)
        readonly property color countColor: root.Theme.palette.directColor1
        readonly property color background: root.Theme.palette.statusMessage.emojiReactionBackground
        readonly property color backgroundHovered: root.Theme.palette.statusMessage.emojiReactionBackgroundHovered
        readonly property color backgroundMine: root.Theme.palette.primaryColor2
        readonly property color borderMine: root.Theme.palette.primaryColor1
        readonly property color borderHovered: root.Theme.palette.statusMessage.emojiReactionBorderHovered

        // The reaction under the mouse, if any - the one the shared tooltip shows
        property Item hoveredReaction: null

        // design values
        readonly property int iconSize: 22
        readonly property int cornerRadius: 12
        readonly property int buttonWidth: 36
        readonly property int buttonHeight: 32
    }

    Repeater {
        model: root.reactionsModel

        Rectangle {
            id: reactionDelegate

            required property var model

            objectName: "messageReaction_" + model.emoji

            Accessible.role: Accessible.Button
            Accessible.name: model.emoji
            Accessible.onPressAction: root.toggleReaction(model.emoji)

            implicitWidth: Math.max(d.buttonWidth, content.implicitWidth + 2 * d.padding)
            implicitHeight: d.buttonHeight

            topLeftRadius: 0
            topRightRadius: d.cornerRadius
            bottomLeftRadius: d.cornerRadius
            bottomRightRadius: d.cornerRadius
            color: {
                if (mouseArea.containsMouse)
                    return d.backgroundHovered
                return model.didIReactWithThisEmoji ? d.backgroundMine : d.background
            }
            border.width: model.didIReactWithThisEmoji || mouseArea.containsMouse || root.messageHighlighted ? 1 : 0
            border.color: model.didIReactWithThisEmoji ? d.borderMine : d.borderHovered

            Row {
                id: content

                anchors.centerIn: parent
                spacing: d.padding

                StatusEmoji {
                    objectName: "emojiReaction"
                    width: d.iconSize
                    height: d.iconSize

                    // model.emoji is the reaction's hexcode id; the character comes from the
                    // catalogue, which has the fully-qualified form (❤️, not ❤)
                    emoji: StatusQUtils.Emoji.emojiModel.getEmojiFromHexcode(reactionDelegate.model.emoji)
                           || StatusQUtils.Emoji.getEmojiCodepoint(reactionDelegate.model.emoji)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: reactionDelegate.model.numberOfReactions
                    font.family: Fonts.baseFont.family
                    font.pixelSize: d.countFontSize
                    color: d.countColor
                }
            }

            // hover, cursor and click in one; a plain MouseArea, as a long press on
            // a reaction is no right click
            MouseArea {
                id: mouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: {
                    if (containsMouse)
                        d.hoveredReaction = reactionDelegate
                    else if (d.hoveredReaction === reactionDelegate)
                        d.hoveredReaction = null
                    root.hoverChanged(containsMouse)
                }
                onClicked: root.toggleReaction(reactionDelegate.model.emoji)
            }
        }
    }

    // A tooltip is a pointer affordance, so a touch never raises one
    HoverHandler {
        id: pointerHoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
    }

    // One authors tooltip for all the reactions, built on the first hover of one;
    // zero-sized, so the Flow doesn't give it a slot
    Loader {
        id: authorsToolTipLoader

        width: 0
        height: 0
        active: false

        readonly property Item target: pointerHoverHandler.hovered ? d.hoveredReaction : null
        onTargetChanged: if (target) active = true

        sourceComponent: StatusToolTip {
            id: authorsToolTip

            // QQuickToolTip only applies its show delay to an already completed
            // popup, so the show request is withheld until then
            property bool completed: false
            Component.onCompleted: authorsToolTip.completed = true

            objectName: "reactionAuthorsTooltip"
            parent: authorsToolTipLoader.target
            maxWidth: 400
            // the JSON parse of the authors list happens only for a shown tooltip
            text: !!authorsToolTipLoader.target
                  ? d.showReactionAuthors(authorsToolTipLoader.target.model.jsonArrayOfUsersReactedWithThisEmoji,
                                          authorsToolTipLoader.target.model.emoji) || ""
                  : ""
            visible: authorsToolTip.completed && !!authorsToolTipLoader.target && !!authorsToolTip.text
        }
    }

    Rectangle {
        id: addReactionButton

        width: d.buttonWidth
        height: d.buttonHeight
        visible: root.enabled
        radius: 8
        color: addReactionHoverHandler.hovered ? root.Theme.palette.primaryColor3 : "transparent"

        Accessible.role: Accessible.Button

        StatusIcon {
            anchors.centerIn: parent
            width: d.iconSize
            height: d.iconSize
            icon: "reaction-b"
            color: addReactionHoverHandler.hovered && !root.limitReached ? root.Theme.palette.primaryColor1
                                                                         : root.Theme.palette.baseColor1
        }

        HoverHandler {
            id: addReactionHoverHandler
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        }

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

        StatusLazyToolTip {
            target: addReactionButton
            centerArrowOnTarget: true
            text: root.limitReached ? qsTr("Maximum number of different reactions reached") : qsTr("Add reaction")
        }
    }
}
