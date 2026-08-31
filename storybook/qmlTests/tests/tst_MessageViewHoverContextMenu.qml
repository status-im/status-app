import QtQuick
import QtTest

import utils

import shared.views.chat

import AppLayouts.Chat.stores as ChatStores

Item {
    id: root

    width: 800
    height: 600

    ListModel {
        id: contactsModel
    }

    ChatStores.RootStore {
        id: rootStoreMock

        property var contactsModel: contactsModel
    }

    ChatStores.MessageStore {
        id: messageStoreMock
    }

    QtObject {
        id: chatContentModuleMock

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool canPostReactions: true
        }
    }

    Component {
        id: messageViewComp

        MessageView {
            width: 600

            rootStore: rootStoreMock
            messageStore: messageStoreMock
            chatContentModule: chatContentModuleMock

            joined: true
            messageContentType: Constants.messageContentType.messageType
            messageTimestamp: Date.now()
        }
    }

    Component {
        id: messagePairComp

        Column {
            spacing: 0
            width: 600

            MessageView {
                width: parent.width

                rootStore: rootStoreMock
                messageStore: messageStoreMock
                chatContentModule: chatContentModuleMock

                joined: true
                messageId: "msg-1"
                senderId: "0xsender"
                senderDisplayName: "Sender"
                messageText: "first message"
                unparsedText: "first message"
                messageTimestamp: Date.now()
                messageContentType: Constants.messageContentType.messageType
            }

            MessageView {
                width: parent.width

                rootStore: rootStoreMock
                messageStore: messageStoreMock
                chatContentModule: chatContentModuleMock

                joined: true
                messageId: "msg-2"
                senderId: "0xother"
                senderDisplayName: "Other"
                messageText: "second message"
                unparsedText: "second message"
                messageTimestamp: Date.now() + 1
                messageContentType: Constants.messageContentType.messageType
            }
        }
    }

    TestCase {
        name: "MessageViewHoverContextMenu"
        when: windowShown

        function messageViewReady(view) {
            return view.status === Loader.Ready
        }

        function findMessageDelegate(view) {
            const bubble = findChild(view, "StatusMessage_textMessage")
            if (!bubble)
                return null

            let item = bubble
            while (item && item.effectiveHovered === undefined)
                item = item.parent
            return item
        }

        function hasQuickActionsMenu(view) {
            const menu = findChild(view, "MessageContextMenuView")
            return !!menu && menu.opened
        }

        function hoverMessageDelegate(view) {
            const delegate = findMessageDelegate(view)
            verify(!!delegate, "message delegate must exist")
            mouseMove(delegate, Math.max(1, delegate.width / 2), Math.max(1, delegate.height / 2))
            return delegate
        }

        function test_mouseHoverOpensQuickActionsMenu() {
            const view = createTemporaryObject(messageViewComp, root, {
                messageId: "msg-hover",
                senderId: "0xsender",
                senderDisplayName: "Sender",
                messageText: "hover me",
                unparsedText: "hover me"
            })
            verify(!!view)
            tryVerify(() => messageViewReady(view), 5000, "MessageView must be ready")

            hoverMessageDelegate(view)
            tryVerify(() => hasQuickActionsMenu(view), 3000,
                      "mouse hover must open the quick-actions context menu")
        }

        function test_hoverDoesNotOpenQuickActionsWhenInPinnedPopup() {
            const view = createTemporaryObject(messageViewComp, root, {
                messageId: "msg-pinned-popup",
                senderId: "0xsender",
                senderDisplayName: "Sender",
                messageText: "pinned popup message",
                unparsedText: "pinned popup message",
                isInPinnedPopup: true,
                joined: true
            })
            verify(!!view)
            tryVerify(() => messageViewReady(view), 5000, "MessageView must be ready")

            hoverMessageDelegate(view)
            wait(500)
            verify(!hasQuickActionsMenu(view),
                   "hover must not open the chat quick-actions menu inside a pinned popup")
        }

        function test_hoverMenuClosesWhenPointerEntersMessageGap() {
            const pair = createTemporaryObject(messagePairComp, root)
            verify(!!pair)
            compare(pair.children.length, 2)

            const firstView = pair.children[0]
            const secondView = pair.children[1]
            tryVerify(() => messageViewReady(firstView) && messageViewReady(secondView),
                      5000, "both MessageView rows must be ready")

            const delegate = hoverMessageDelegate(firstView)
            tryVerify(() => hasQuickActionsMenu(firstView), 3000,
                      "hover must open the quick-actions menu before gap test")

            const gapPoint = delegate.mapToItem(pair, delegate.width / 2, delegate.height + 1)
            mouseMove(pair, gapPoint.x, gapPoint.y)

            tryVerify(() => !hasQuickActionsMenu(firstView), 2000,
                      "moving into the inter-message gap must close the hover menu")
            verify(!hasQuickActionsMenu(secondView),
                   "gap hover must not open a menu on the neighboring message")
        }
    }
}
