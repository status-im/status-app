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

    signal toggleReaction(string hexcode)
    signal openEmojiPopup(var parent, var mouse)

    property int countLimit: 5

    spacing: Theme.smallPadding

    QtObject {
        id: d

        readonly property int emojiSize:
            root.Theme.fontSize(
                root.size === MessageReactionsRow.Size.Regular ? 23 : 33)
    }

    Repeater {
        id: recentEmojisRepeater
        model: SortFilterProxyModel {
            sourceModel: root.emojiModel
            filters: IndexFilter {
                maximumIndex: root.countLimit - 1
            }
        }
        delegate: EmojiReaction {
            required property string unicode

            Layout.alignment: Qt.AlignVCenter

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
        Layout.alignment: Qt.AlignVCenter

        Layout.preferredHeight: d.emojiSize + Theme.halfPadding
        Layout.preferredWidth: Layout.preferredHeight

        icon.width: d.emojiSize
        icon.height: d.emojiSize
        icon.name: "reaction-b"
        type: StatusFlatRoundButton.Type.Tertiary
        onClicked: mouse => root.openEmojiPopup(this, mouse)
        Accessible.name: qsTr("Add reaction")
    }
}
