import QtQuick

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Controls

import shared.controls.chat

import SortFilterProxyModel

Row {
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

    spacing: Theme.halfPadding
    leftPadding: Theme.halfPadding
    rightPadding: Theme.halfPadding

    Loader {
        active: root.visible

        sourceComponent: Row {
            spacing: Theme.halfPadding

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

                    emojiId: unicode
                    emojiSize: Theme.fontSize(
                                   root.size === MessageReactionsRow.Size.Regular ? 23 : 33)

                    anchors.verticalCenter: parent.verticalCenter
                    // TODO not implemented yet. We'll need to pass this info
                    // reactedByUser: model.didIReactWithThisEmoji
                    onToggleReaction: {
                        root.toggleReaction(unicode)
                    }
                }
            }
        }
    }

    StatusFlatRoundButton {
        height: parent.height
        width: height

        Binding on icon.width {
            when: root.size === MessageReactionsRow.Size.Big
            value: height * 0.75
        }

        icon.height: icon.width
        icon.name: "reaction-b"
        type: StatusFlatRoundButton.Type.Tertiary
        onClicked: mouse => root.openEmojiPopup(this, mouse)
        Accessible.name: qsTr("Add reaction")
    }
}
