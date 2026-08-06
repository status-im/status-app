import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Controls

import SortFilterProxyModel

import utils

RowLayout {
    id: root

    enum Size {
        Regular,
        Big
    }

    required property var emojiModel
    property int size: MessageReactionsRow.Size.Regular
    property int emojiSize: root.Theme.fontSize(
                                root.size === MessageReactionsRow.Size.Regular ? 23 : 33)
    property int itemSize: root.emojiSize + Theme.halfPadding
    property color addReactionIconColor: addReactionButton.hovered ? Theme.palette.primaryColor1 : Theme.palette.baseColor1

    signal toggleReaction(string hexcode)
    signal openEmojiPopup(var parent, var mouse)

    // Set to 0 to show as many recent reactions as fit in the available width.
    property int countLimit: 5

    spacing: Theme.smallPadding

    QtObject {
        id: d

        readonly property int reactionWidth: root.itemSize
        readonly property int dynamicAvailableWidth: root.width - reactionWidth
        readonly property int effectiveCountLimit: root.countLimit > 0
                                               ? root.countLimit
                                               : Math.max(0, Math.floor(dynamicAvailableWidth / (reactionWidth + root.spacing)) - 1)
    }

    Repeater {
        id: recentEmojisRepeater
        model: SortFilterProxyModel {
            sourceModel: root.emojiModel
            filters: IndexFilter {
                maximumIndex: d.effectiveCountLimit - 1
            }
        }
        delegate: EmojiReaction {
            required property string unicode

            Layout.alignment: Qt.AlignVCenter

            emojiId: unicode
            emojiSize: root.emojiSize
            itemSize: root.itemSize

            // TODO not implemented yet. We'll need to pass this info
            // reactedByUser: model.didIReactWithThisEmoji
            onToggleReaction: {
                root.toggleReaction(unicode)
            }
        }
    }

    StatusFlatRoundButton {
        id: addReactionButton

        Layout.alignment: Qt.AlignVCenter

        Layout.preferredHeight: root.itemSize
        Layout.preferredWidth: Layout.preferredHeight

        icon.width: root.emojiSize
        icon.height: root.emojiSize
        icon.color: root.addReactionIconColor
        icon.name: "reaction-b"
        type: StatusFlatRoundButton.Type.Tertiary
        onClicked: mouse => root.openEmojiPopup(this, mouse)
        Accessible.name: qsTr("Add reaction")
    }
}
