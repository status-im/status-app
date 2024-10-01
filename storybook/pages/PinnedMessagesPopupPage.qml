import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Components

import Storybook
import Models

import utils
import shared.views.chat
import shared.status
import AppLayouts.Chat.popups
import AppLayouts.Chat.stores

SplitView {
    QtObject {
        id: d
    }

    Logs { id: logs }

    MessageStore {
        id: mockMessageStore

        property ListModel pinnedMessagesModel: ListModel {
        }

        function getMessageByIndexAsJson(index) {
            if (index >= 0 && index < pinnedMessagesModel.count) {
                return pinnedMessagesModel.get(index)
            }
            return undefined
        }

        function unpinMessage(messageId) {
            console.log("Unpinning message:", messageId)
        }

        property bool amIChatAdmin: false
        property int chatType: Constants.chatType.oneToOne

        function setEditModeOff(messageId) {
            console.log("Setting edit mode off for message:", messageId)
        }

        function setEditModeOn(messageId) {
            console.log("Setting edit mode on for message:", messageId)
        }

        function warnAndDeleteMessage(messageId) {
            console.log("Warning and deleting message:", messageId)
        }

        function toggleReaction(messageId, emojiId) {
            console.log("Toggling reaction for message:", messageId, "with emoji:", emojiId)
        }

        function markMessageAsUnread(messageId) {
            console.log("Marking message as unread:", messageId)
        }

        function pinMessage(messageId) {
            console.log("Pinning message:", messageId)
        }

        function appendPinnedMessage(index) {
            if (index < 0 || index >= messagesModel.count) {
                return
            }

            const message = messagesModel.get(index)
            // `id` cannot be declared as a ListElement role, so add it when appending.
            message.id = message.messageId
            pinnedMessagesModel.append(message)
        }

        readonly property var messagesModel: ListModel {
            ListElement {
                messageId: "pinned-message-1"
                timestamp: 1656937930123
                responseToMessageWithId: ""
                senderId: "zq123456789"
                senderDisplayName: "simon"
                senderOptionalName: ""
                senderEnsVerified: false
                senderIsAdded: true
                profileImage: ""
                senderIcon: ""
                senderTrustStatus: StatusContactVerificationIcons.TrustedType.Verified
                amISender: false
                contentType: StatusMessage.ContentType.Text
                messageText: "Hello, this is awesome! Feels like decentralized Discord! And it even supports HTML markup, like <b>bold</b>, <i>italics</i> or <u>underline</u>"
                message: "Hello, this is awesome! Feels like decentralized Discord! And it even supports HTML markup, like <b>bold</b>, <i>italics</i> or <u>underline</u>"
                messageImage: ""
                isContact: true
                isAReply: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.Verified
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                pinned: true
                pinnedBy: "zq123456789"
                reactions: null
                sticker: ""
                stickerPack: -1
                linkPreviewModel: null
                links: ""
                transactionParameters: null
                quotedMessageParsedText: ""
                quotedMessageFrom: ""
                quotedMessageContentType: StatusMessage.ContentType.Text
                quotedMessageDeleted: false
                quotedMessageAuthorName: ""
                quotedMessageAuthorDisplayName: ""
                quotedMessageAuthorThumbnailImage: ""
                quotedMessageAuthorEnsVerified: false
                quotedMessageAuthorIsContact: false
                bridgeName: ""
            }
            ListElement {
                messageId: "pinned-message-2"
                timestamp: 1657937930135
                responseToMessageWithId: ""
                senderId: "zqABCDEFG"
                senderDisplayName: "Mark Cuban"
                senderOptionalName: ""
                senderEnsVerified: false
                senderIsAdded: false
                senderIcon: ""
                senderTrustStatus: StatusContactVerificationIcons.TrustedType.Untrustworthy
                amISender: false
                contentType: StatusMessage.ContentType.Text
                messageText: "I know a lot of you really seem to get off or be validated by arguing with strangers online but please know it's a complete waste of your time and energy"
                message: "I know a lot of you really seem to get off or be validated by arguing with strangers online but please know it's a complete waste of your time and energy"
                messageImage: ""
                isContact: false
                isAReply: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.Untrustworthy
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                pinned: true
                pinnedBy: "zq123456789"
                reactions: null
                sticker: ""
                stickerPack: -1
                linkPreviewModel: null
                links: ""
                transactionParameters: null
                quotedMessageParsedText: ""
                quotedMessageFrom: ""
                quotedMessageContentType: StatusMessage.ContentType.Text
                quotedMessageDeleted: false
                quotedMessageAuthorName: ""
                quotedMessageAuthorDisplayName: ""
                quotedMessageAuthorThumbnailImage: ""
                quotedMessageAuthorEnsVerified: false
                quotedMessageAuthorIsContact: false
                bridgeName: ""
            }
            ListElement {
                messageId: "pinned-message-3"
                timestamp: 1667937930159
                responseToMessageWithId: "pinned-message-2"
                senderId: "zqdeadbeef"
                senderDisplayName: "replicator.stateofus.eth"
                senderOptionalName: ""
                senderEnsVerified: true
                senderIsAdded: true
                senderIcon: ""
                senderTrustStatus: StatusContactVerificationIcons.TrustedType.None
                amISender: false
                contentType: StatusMessage.ContentType.Text
                messageText: "Test reply; the original text above should have a horizontal gradient mask"
                message: "Test reply; the original text above should have a horizontal gradient mask"
                messageImage: ""
                isContact: true
                isAReply: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                pinned: true
                pinnedBy: "zq123456789"
                reactions: null
                sticker: ""
                stickerPack: -1
                linkPreviewModel: null
                links: ""
                transactionParameters: null
                quotedMessageParsedText: "I know a lot of you really seem to get off or be validated by arguing with strangers online but please know it's a complete waste of your time and energy"
                quotedMessageFrom: "zqABCDEFG"
                quotedMessageContentType: StatusMessage.ContentType.Text
                quotedMessageDeleted: false
                quotedMessageAuthorName: "Mark Cuban"
                quotedMessageAuthorDisplayName: "Mark Cuban"
                quotedMessageAuthorThumbnailImage: ""
                quotedMessageAuthorEnsVerified: false
                quotedMessageAuthorIsContact: false
                bridgeName: ""
            }
        }
        readonly property var colorHash: ListModel {
            ListElement { colorId: 13; segmentLength: 5 }
            ListElement { colorId: 31; segmentLength: 5 }
            ListElement { colorId: 10; segmentLength: 1 }
        }
    }

    RootStore {
        id: mockRootStore
        property var messageStore: mockMessageStore
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                Button {
                    text: "Open Empty Pinned Messages Popup"
                    onClicked: {
                        mockMessageStore.pinnedMessagesModel.clear()
                        pinnedMessagesPopup.messageToPin = ""
                        pinnedMessagesPopup.open()
                    }
                }

                Button {
                    text: "Open Pinned Messages Popup (2 messages)"
                    onClicked: {
                        mockMessageStore.pinnedMessagesModel.clear()
                        mockMessageStore.appendPinnedMessage(0)
                        mockMessageStore.appendPinnedMessage(1)
                        pinnedMessagesPopup.messageToPin = ""
                        pinnedMessagesPopup.open()
                    }
                }

                Button {
                    text: "Open Full Pinned Messages Popup (3 messages)"
                    onClicked: {
                        mockMessageStore.pinnedMessagesModel.clear()
                        mockMessageStore.appendPinnedMessage(0)
                        mockMessageStore.appendPinnedMessage(1)
                        mockMessageStore.appendPinnedMessage(2)
                        pinnedMessagesPopup.messageToPin = ""
                        pinnedMessagesPopup.open()
                    }
                }

                Button {
                    text: "Open Unpin Messages Popup (3 messages + messageToPin)"
                    onClicked: {
                        mockMessageStore.pinnedMessagesModel.clear()
                        mockMessageStore.appendPinnedMessage(0)
                        mockMessageStore.appendPinnedMessage(1)
                        mockMessageStore.appendPinnedMessage(2)
                        pinnedMessagesPopup.messageToPin = "This is a message to pin"
                        pinnedMessagesPopup.open()
                    }
                }
            }

            PinnedMessagesPopup {
                id: pinnedMessagesPopup
                store: mockRootStore
                messageStore: mockMessageStore
                pinnedMessagesModel: mockMessageStore.pinnedMessagesModel
                chatId: "chat1"

                property var chatContentModule: QtObject {
                    property var chatDetails: QtObject {
                        property bool canPostReactions: true
                        property bool canPost: true
                        property bool canView: true
                    }
                    property var pinnedMessagesModel: mockMessageStore.pinnedMessagesModel
                }

                property var usersStore: QtObject {
                    property var usersModel: []
                }

                property var contactsStore: QtObject {
                    function getProfileContext(publicKey, myPublicKey, isBridgedAccount) {
                        return {
                            profileType: Constants.profileType.regular,
                            trustStatus: Constants.trustStatus.unknown,
                            contactType: Constants.contactType.nonContact,
                            ensVerified: false,
                            onlineStatus: Constants.onlineStatus.unknown,
                            hasLocalNickname: false
                        }
                    }
                }

                property var emojiPopup: null
                property var stickersPopup: null

                onPinMessageRequested: (messageId) => {
                    logs.logEvent("Pin message requested:", messageId)
                }
                onUnpinMessageRequested: (messageId) => {
                    logs.logEvent("Unpin message requested:", messageId)
                }
                onJumpToMessageRequested: (messageId) => {
                    logs.logEvent("Jump to message requested:", messageId)
                }
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumWidth: 150
        SplitView.preferredWidth: 250

        logsView.logText: logs.logText

        controls: ColumnLayout {
            spacing: 16
        }
    }
}

// category: Views
// status: good
