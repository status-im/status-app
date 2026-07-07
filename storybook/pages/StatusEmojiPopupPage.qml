import QtCore
import QtQuick

import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils

import Storybook

import utils
import shared.status

SplitView {
    id: root
    orientation: Qt.Vertical

    Logs { id: logs }

    QtObject {
        id: d
        property string lastSelectedEmoji: "N/A"
        property string lastSelectedEmojiHexcode: ""
    }

    Pane {
        id: topPane

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        background: Rectangle {
            color: Theme.palette.baseColor3
        }

        Button {
            anchors.centerIn: parent
            text: "Reopen"
            onClicked: emojiPopup.open()
        }

        Settings {
            id: settings
            category: "EmojiPopup"
            property var recentEmojis: []
            property string skinColor
        }

        StatusEmojiPopup {
            id: emojiPopup

            directParent: topPane
            relativeX: (parent.width - width) / 2
            relativeY: (parent.height - height) / 2

            height: 440
            visible: true
            modal: false
            recentEmojis: settings.recentEmojis
            skinColor: settings.skinColor
            emojiModel: StatusQUtils.Emoji.emojiModel
            onEmojiSelected: function(emoji, atCu, hexcode) {
                logs.logEvent("onEmojiSelected", ["emoji", "atCu", "hexcode"], arguments)
                d.lastSelectedEmoji = emoji
                d.lastSelectedEmojiHexcode = hexcode
            }
            onSetSkinColorRequested: function(skinColor) {
                logs.logEvent("onSetSkinColorRequested", ["skinColor"], arguments)
                settings.skinColor = skinColor
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 200
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent

            Button {
                text: "Clear settings (reload to take effect)"
                onClicked: {
                    d.lastSelectedEmoji = ""
                    d.lastSelectedEmojiHexcode = ""
                    settings.recentEmojis = []
                    settings.skinColor = ""
                    settings.sync()
                }
            }

            RowLayout {
                Label {
                    text: "Last selected: %1 ('%2')".arg(d.lastSelectedEmoji).arg(d.lastSelectedEmojiHexcode)
                }
                ToolButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    text: "📋"
                    enabled: !!d.lastSelectedEmojiHexcode
                    onClicked: ClipboardUtils.setText(d.lastSelectedEmojiHexcode)
                    ToolTip.text: "Copy to clipboard"
                    ToolTip.visible: hovered
                }
            }

            Button {
                text: "Random emoji"
                onClicked: d.lastSelectedEmoji = StatusQUtils.Emoji.getRandomEmoji()
            }

            Item { Layout.fillHeight: true }
        }
    }
}

// category: Popups
// status: good
// https://www.figma.com/design/Mr3rqxxgKJ2zMQ06UAKiWL/%F0%9F%92%AC-Chat%E2%8E%9CDesktop?node-id=1006-0&t=VC6BL8H0Il3VbDxX-0
