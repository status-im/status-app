import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls

import Storybook

import utils
import shared.views.chat

import SortFilterProxyModel

SplitView {
    id: root

    Logs { id: logs }
    property var contextMenu

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Rectangle {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            color: Theme.palette.background

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    id: messageCard

                    Layout.preferredWidth: 520
                    Layout.preferredHeight: 160
                    color: Theme.palette.baseColor2
                    radius: 8

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 24
                        spacing: 12

                        Label {
                            Layout.fillWidth: true
                            text: "This is a sample chat message"
                            color: Theme.palette.directColor1
                            font.pixelSize: 18
                            wrapMode: Text.WordWrap
                        }

                        StatusButton {
                            id: openMenuButton
                            text: "Open message context menu"
                            onClicked: root.openMessageContextMenu(Qt.point(openMenuButton.x,
                                                                            openMenuButton.y + openMenuButton.height + 8))
                        }
                    }
                }
            }
        }
    }

    function openMessageContextMenu(point) {
        contextMenu?.close()

        contextMenu = messageContextMenuComponent.createObject(messageCard, {
            myPublicKey: ctrlMyMessage.checked ? "foobar" : "",
            amIChatAdmin: false,
            chatType: Constants.chatType.oneToOne,
            messageId: "Oxdeadbeef",
            unparsedText: "This is a sample chat message",
            messageSenderId: "foobar",
            messageContentType: Constants.messageContentType.messageType,
            pinnedMessage: ctrlPinned.checked,
            canPin: true,
            selectedText: "",
            hideDisabledItems: true,
            openExpanded: ctrlExpanded.checked
        })
        contextMenu.popup(point)
    }

    Component {
        id: messageContextMenuComponent

        MessageContextMenuView {
            id: messageContextMenuView

            emojiModel: SortFilterProxyModel {
                sourceModel: StatusQUtils.Emoji.emojiModel
            }

            onPinMessage: logs.logEvent(`onPinMessage: ${messageContextMenuView.messageId}`)
            onUnpinMessage: logs.logEvent(`onUnpinMessage: ${messageContextMenuView.messageId}`)
            onPinnedMessagesLimitReached: logs.logEvent(`onPinnedMessagesLimitReached: ${messageContextMenuView.messageId}`)
            onMarkMessageAsUnread: logs.logEvent(`onMarkMessageAsUnread: ${messageContextMenuView.messageId}`)
            onToggleReaction: (hexcode) => logs.logEvent("onToggleReaction", ["hexcode"], [hexcode])
            onDeleteMessage: logs.logEvent(`onDeleteMessage: ${messageContextMenuView.messageId}`)
            onEditClicked: logs.logEvent(`onEditClicked: ${messageContextMenuView.messageId}`)
            onShowReplyArea: (senderId) => logs.logEvent("onShowReplyArea", ["senderId"], [senderId])
            onCopyToClipboard: (text) => logs.logEvent("onCopyToClipboard", ["text"], [text])
            onOpenEmojiPopup: logs.logEvent("onOpenEmojiPopup")
            onClosed: destroy()
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumWidth: 150
        SplitView.preferredWidth: 250

        logsView.logText: logs.logText

        controls: ColumnLayout {
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    text: "Menu state"
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.secondaryTextFontSize
                }

                ButtonGroup {
                    id: menuStateGroup
                }

                RadioButton {
                    id: ctrlExpanded
                    text: "Expanded"
                    ButtonGroup.group: menuStateGroup
                }

                RadioButton {
                    text: "Collapsed"
                    checked: true
                    ButtonGroup.group: menuStateGroup
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    text: "Message state"
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.secondaryTextFontSize
                }

                CheckBox {
                    id: ctrlMyMessage
                    text: "My message"
                }

                CheckBox {
                    id: ctrlPinned
                    text: "Pinned message"
                }
            }
        }
    }
}

// category: Views
// status: good
