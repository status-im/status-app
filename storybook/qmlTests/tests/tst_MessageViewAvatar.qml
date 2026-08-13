import QtQuick
import QtTest

import utils

import shared.views.chat

import AppLayouts.Chat.stores as ChatStores

/*
 Perf guard: the avatar stack (identicon, rounded image, opacity mask,
 shader effect) is one of the heaviest parts of a message row. It must
 incubate asynchronously behind a fixed-size skeleton circle so row
 creation does not pay for it, without shifting the row layout.
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
            messageText: "avatar test message"
            unparsedText: "avatar test message"
            messageTimestamp: Date.now()
            messageContentType: Constants.messageContentType.messageType
            amISender: false
            joined: true
        }
    }

    TestCase {
        name: "MessageViewAvatar"
        when: windowShown

        function avatarLoader(view) {
            const avatar = findChild(view, "messageProfileImage")
            verify(!!avatar)
            return avatar
        }

        function test_avatarIncubatesAsynchronously() {
            const view = createTemporaryObject(messageViewComp, root)
            verify(!!view)

            // synchronously after creation: row exists, avatar content does
            // not — the skeleton covers it at full avatar size
            const avatar = avatarLoader(view)
            verify(avatar.status !== Loader.Ready,
                   "avatar must not be built synchronously with the row")

            const skeleton = findChild(view, "avatarLoadingSkeleton")
            verify(!!skeleton)
            verify(skeleton.visible)
            verify(skeleton.width > 0)

            // the avatar arrives asynchronously; skeleton goes away and the
            // reserved geometry does not change
            const widthWhileLoading = avatar.width
            tryVerify(() => avatar.status === Loader.Ready, 5000)
            tryVerify(() => !skeleton.visible)
            compare(avatar.width, widthWhileLoading,
                    "avatar geometry must be reserved while incubating")
            verify(avatar.width > 0)
        }

        // Async incubation parents the partially-built avatar into the scene
        // before it is complete — it must stay invisible behind the skeleton
        // until Ready instead of painting piece by piece.
        function test_avatarHiddenWhileIncubating() {
            const view = createTemporaryObject(messageViewComp, root)
            verify(!!view)

            const avatar = avatarLoader(view)

            let sawVisiblePartial = false
            while (avatar.status !== Loader.Ready) {
                for (let i = 0; i < avatar.children.length; ++i) {
                    const child = avatar.children[i]
                    if (child.objectName !== "avatarLoadingSkeleton"
                            && child.visible)
                        sawVisiblePartial = true
                }
                wait(1)
            }
            verify(!sawVisiblePartial,
                   "incubating avatar content must not be visible under the skeleton")

            // once ready the content shows
            tryVerify(() => avatar.children.length > 1)
            let visibleContent = false
            for (let i = 0; i < avatar.children.length; ++i) {
                const child = avatar.children[i]
                if (child.objectName !== "avatarLoadingSkeleton" && child.visible)
                    visibleContent = true
            }
            verify(visibleContent, "avatar content must be visible once ready")
        }
    }
}
