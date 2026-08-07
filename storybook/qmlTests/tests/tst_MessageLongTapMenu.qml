import QtQuick
import QtTest

import utils

import shared.views.chat

import AppLayouts.Chat.stores as ChatStores

/*
 Regression: long tap on a message must open the message context menu
 ====================================================================
 The touch path is a TapHandler (TouchScreen device) inside the StatusMessage
 delegate: onLongPressed → openMessageContextMenu(). The desktop path is a
 right-click TapHandler → same function. Both must yield a
 MessageContextMenuView instance (created on demand, popped up at the press
 position).
*/
Item {
    id: root

    width: 800
    height: 600

    ChatStores.RootStore { id: rootStoreMock }
    ChatStores.MessageStore { id: messageStoreMock }

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

            messageId: "msg-1"
            senderId: "0xsender"
            senderDisplayName: "Sender"
            messageText: "hello world this is a longer message so the text has real geometry"
            unparsedText: "hello world this is a longer message so the text has real geometry"
            messageTimestamp: Date.now()
            messageContentType: Constants.messageContentType.messageType
            amISender: false
            joined: true
        }
    }

    TestCase {
        name: "MessageLongTapMenu"
        when: windowShown

        function findMenu(view) {
            return findChild(view, "messageContextMenu_replyTo")
        }

        function test_longTapOpensMessageMenu() {
            const view = createTemporaryObject(messageViewComp, root)
            tryVerify(() => view.status === Loader.Ready)
            waitForRendering(view)

            const target = view.item
            verify(!!target)

            const touch = touchEvent(target)
            touch.press(0, target, target.width / 2, target.height / 2)
            touch.commit()
            // TapHandler.onLongPressed fires while holding, after the
            // long-press threshold
            wait(1500)

            tryVerify(() => !!findMenu(view), 3000,
                      "long tap must open the message context menu")

            const release = touchEvent(target)
            release.release(0, target, target.width / 2, target.height / 2)
            release.commit()
        }

        // Regression (device): long tap ON THE TEXT must also open the menu.
        // The text is a TextEdit that takes the touch grab for text
        // interaction; the row's long-press detection must survive that.
        function test_longTapOnTextOpensMessageMenu() {
            const view = createTemporaryObject(messageViewComp, root)
            tryVerify(() => view.status === Loader.Ready)
            waitForRendering(view)

            let text = null
            tryVerify(() => {
                text = findChild(view, "StatusTextMessage_chatText")
                return !!text && text.width > 0 && text.height > 8
                        && text.text.length > 0
            }, 5000, "the text view must have rendered text under the press point")

            const touch = touchEvent(text)
            touch.press(0, text, text.width / 2, text.height / 2)
            touch.commit()
            wait(1500)

            tryVerify(() => !!findMenu(view), 3000,
                      "long tap on the text must open the message context menu")

            const release = touchEvent(text)
            release.release(0, text, text.width / 2, text.height / 2)
            release.commit()
        }
    }
}
