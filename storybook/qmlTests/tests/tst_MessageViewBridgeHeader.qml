import QtQuick
import QtTest

import utils

import shared.views.chat

import AppLayouts.Chat.stores as ChatStores

// Header grouping of bridged messages, which share the relaying account's senderId.
Item {
    id: root

    width: 800
    height: 600

    ListModel {
        id: contactsModel

        function hasUser(pubKey) {
            return false
        }
    }

    ChatStores.RootStore {
        id: rootStoreMock

        property var contactsModel: contactsModel

        function populateContactDetailsRequested(pubKey) {}
    }

    ChatStores.MessageStore { id: messageStoreMock }

    QtObject {
        id: chatContentModuleMock

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.communityChat
            readonly property bool canPostReactions: true
        }
    }

    readonly property double now: Date.now()

    Component {
        id: messageViewComp

        // Follows a message from the same sender on the same day, within the repeat interval.
        MessageView {
            width: 600

            rootStore: rootStoreMock
            messageStore: messageStoreMock
            chatContentModule: chatContentModuleMock

            messageId: "msg-2"
            senderId: "0xbot"
            senderDisplayName: "ForumUser42"
            messageText: "gm"
            messageTimestamp: root.now
            messageContentType: Constants.messageContentType.messageType
            amISender: false

            prevMessageIndex: 1
            prevMessageSenderId: "0xbot"
            prevMessageTimestamp: root.now - 1000
            prevMessageContentType: Constants.messageContentType.messageType
        }
    }

    TestCase {
        name: "MessageViewBridgeHeader"
        when: windowShown

        function headerShown(view) {
            tryVerify(() => view.status === Loader.Ready)
            const avatar = findChild(view, "messageProfileImage")
            verify(!!avatar)
            // the avatar is active only with a header
            return avatar.active
        }

        function test_bridgedMessageAfterRelayingAccountShowsHeader() {
            const view = createTemporaryObject(messageViewComp, root, {
                messageContentType: Constants.messageContentType.bridgeMessageType,
                bridgeName: "forum"
            })
            verify(headerShown(view),
                   "a bridged message must not fold into the relaying account's message")
        }

        function test_bridgedMessageAfterBridgedMessageShowsHeader() {
            const view = createTemporaryObject(messageViewComp, root, {
                messageContentType: Constants.messageContentType.bridgeMessageType,
                prevMessageContentType: Constants.messageContentType.bridgeMessageType,
                bridgeName: "forum"
            })
            verify(headerShown(view))
        }

        function test_ordinaryMessagesFromOneSenderStillFold() {
            const view = createTemporaryObject(messageViewComp, root)
            verify(!headerShown(view), "grouping of ordinary messages must be unchanged")
        }
    }
}
