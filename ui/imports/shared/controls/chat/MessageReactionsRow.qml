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
        Big,
        Compact
    }

    required property var emojiModel
    property int size: MessageReactionsRow.Size.Regular
    property color addReactionIconColor: addReactionButton.hovered ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
    property real reactionSize: 0

    signal toggleReaction(string hexcode)
    signal openEmojiPopup(var parent, var mouse)

    // Set to 0 to show as many recent reactions as fit in the available width.
    property int countLimit: 5

    spacing: Theme.smallPadding

    QtObject {
        id: d

        readonly property int compactEmojiSize: 20
        readonly property int compactReactionWidth: 32
        readonly property int emojiSize: {
            switch (root.size) {
            case MessageReactionsRow.Size.Compact:
                return compactEmojiSize
            case MessageReactionsRow.Size.Big:
                return root.Theme.fontSize(33)
            default:
                return root.Theme.fontSize(23)
            }
        }
        readonly property real reactionWidth: root.reactionSize > 0
                                               ? root.reactionSize
                                               : root.size === MessageReactionsRow.Size.Compact
                                                 ? compactReactionWidth
                                                 : d.emojiSize + Theme.halfPadding
        readonly property int dynamicAvailableWidth: root.width - reactionWidth
        readonly property int effectiveCountLimit: root.countLimit > 0
                                               ? root.countLimit
                                               : Math.max(0, Math.floor(dynamicAvailableWidth / (reactionWidth + root.spacing)))
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
            Layout.preferredWidth: d.reactionWidth
            Layout.preferredHeight: d.reactionWidth

            emojiId: unicode
            emojiSize: d.emojiSize

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

        Layout.preferredHeight: d.reactionWidth
        Layout.preferredWidth: Layout.preferredHeight

        icon.width: d.emojiSize
        icon.height: d.emojiSize
        icon.color: root.addReactionIconColor
        icon.name: "reaction-b"
        type: StatusFlatRoundButton.Type.Tertiary
        onClicked: mouse => root.openEmojiPopup(this, mouse)
        Accessible.name: qsTr("Add reaction")
    }
}
