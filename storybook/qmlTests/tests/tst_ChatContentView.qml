import QtQuick
import QtTest

import utils

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 The per-chat shell and the section's shared messages view, wired the way
 ChatColumnView wires them: the view is reparented into the active chat's
 slot and bound to its message store. The shell's skeleton covers the slot
 until the view is there and while the backend fetches; the view keeps the
 rows that arrive meanwhile staged, so nothing paints underneath it.
*/
Item {
    id: root

    width: 800
    height: 600

    ChatStores.RootStore { id: rootStoreMock }

    ListModel { id: messagesModel }

    QtObject {
        id: contentModuleMock

        property int markAllMessagesReadCalls: 0
        function markAllMessagesRead() { markAllMessagesReadCalls++ }

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool active: true
            readonly property bool highlight: false
            property bool hasUnreadMessages: false
            readonly property bool canPost: true
            readonly property bool canView: true
            readonly property bool canPostReactions: true
            readonly property string emoji: ""
        }

        readonly property var messagesModule: QtObject {
            readonly property var model: messagesModel
            property bool loading: false
            property bool keepUnread: false

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(string messageId)
            signal moreMessagesLoaded()
            signal chatThreadsLoadingFailed()
            signal threadCreationFailed()

            function getChatId() { return "chat-1" }
            function loadMoreMessages() { moreMessagesLoaded() }
            function updateKeepUnread(flag) {}
        }

        function getMyChatId() { return "chat-1" }
        function amIChatAdmin() { return false }
    }

    // A shell, and the shared view - placed into the shell's slot only when
    // `placed` says so, the way ChatColumnView places it for the active chat.
    Component {
        id: harnessComp

        Item {
            id: harness

            property bool placed: true

            readonly property alias shell: shell
            readonly property alias messagesView: messagesView

            width: 800
            height: 600

            ChatContentView {
                id: shell

                anchors.fill: parent

                rootStore: rootStoreMock
                chatContentModule: contentModuleMock
                chatId: "chat-1"
                chatType: Constants.chatType.oneToOne
            }

            Item {
                id: holder

                visible: false
            }

            ChatMessagesView {
                id: messagesView

                parent: harness.placed ? shell.messagesSlot : holder
                anchors.fill: parent

                rootStore: rootStoreMock
                messageStore: shell.messageStore
                chatContentModule: contentModuleMock
                chatId: "chat-1"
                isOneToOne: true
                usersModel: ListModel {}
                joined: true
            }
        }
    }

    TestCase {
        name: "ChatContentView"
        when: windowShown

        function cleanup() {
            contentModuleMock.messagesModule.loading = false
            contentModuleMock.markAllMessagesReadCalls = 0
            contentModuleMock.chatDetails.hasUnreadMessages = false
            messagesModel.clear()
        }

        function fillMessages(count) {
            const now = Date.now()
            const rows = []

            // newest first, as the backend model keeps them
            for (let i = 0; i < count; ++i) {
                const ts = now - i * 60000
                rows.push({
                    id: "msg-" + i,
                    timestamp: ts,
                    contentType: Constants.messageContentType.messageType,
                    senderId: "0xpeer",
                    senderDisplayName: "Peer",
                    messageText: "Message " + i,
                    unparsedText: "Message " + i,
                    deleted: false,
                    prevMsgIndex: i + 1,
                    nextMsgIndex: i - 1,
                    prevMsgTimestamp: ts - 60000,
                    nextMsgTimestamp: ts + 60000,
                    prevMsgSenderId: "0xpeer",
                    prevMsgContentType: Constants.messageContentType.messageType,
                    prevMsgDeleted: false,
                    outgoingStatus: "",
                    pinned: false,
                    pinnedBy: "",
                    reactions: "",
                    editMode: false,
                    mentioned: false,
                    senderEnsVerified: false,
                    transactionParameters: "",
                    albumImagesCount: 0,
                    quotedMessageText: "",
                    quotedMessageParsedText: "",
                    quotedMessageAuthorName: "",
                    quotedMessageAuthorDisplayName: "",
                    quotedMessageAuthorThumbnailImage: "",
                    quotedMessageAuthorEnsVerified: false,
                    quotedMessageAuthorIsContact: false
                })
            }

            messagesModel.append(rows)
        }

        // chatDetails.active is set by the backend before the view shows the
        // chat, so the view never receives activeChanged on a cold open.
        // Marking the chat read must not depend on that signal.
        function test_unreadChatOpenedColdIsMarkedRead() {
            fillMessages(10)
            contentModuleMock.chatDetails.hasUnreadMessages = true

            const harness = createTemporaryObject(harnessComp, root)
            verify(!!harness)
            verify(contentModuleMock.chatDetails.active, "the chat is active from the start")

            tryVerify(() => contentModuleMock.markAllMessagesReadCalls > 0, 10000,
                      "a cold-opened unread chat must still get marked read")
        }

        // The skeleton covers the slot until the shared view is placed in it.
        function test_skeletonCoversTheSlotUntilTheViewArrives() {
            fillMessages(10)

            const harness = createTemporaryObject(harnessComp, root, { placed: false })
            verify(!!harness)

            const skeleton = findChild(harness.shell, "chatMessagesSkeleton")
            verify(!!skeleton, "nothing in the slot yet: the skeleton is up")
            verify(skeleton.visible)

            harness.placed = true

            tryVerify(() => !findChild(harness.shell, "chatMessagesSkeleton"), 5000,
                      "the skeleton goes once the view is in the slot")
        }

        // The skeleton also covers the backend fetch, and the rows arriving
        // meanwhile stay staged under it - one batch, revealed once the fetch
        // is done.
        function test_rowsStayHiddenWhileTheFetchRuns() {
            contentModuleMock.messagesModule.loading = true

            const harness = createTemporaryObject(harnessComp, root)
            verify(!!harness)

            const skeleton = findChild(harness.shell, "chatMessagesSkeleton")
            verify(!!skeleton)
            verify(skeleton.visible, "the skeleton covers the fetch")

            fillMessages(10)

            const view = harness.messagesView.chatLogView

            tryVerify(() => view.rowCount === 10, 5000, "the rows are in")
            verify(view.busy, "and held while the fetch runs")
            compare(revealedRows(view), 0, "none of them shows")

            contentModuleMock.messagesModule.loading = false

            tryVerify(() => !view.busy && revealedRows(view) === 10, 5000,
                      "revealed together once the fetch is done")
            tryVerify(() => !findChild(harness.shell, "chatMessagesSkeleton"), 5000,
                      "and the skeleton is released")
        }

        function revealedRows(view) {
            let n = 0
            for (let row = 0; row < view.rowCount; ++row) {
                const shell = view.itemAtRow(row)
                if (shell && shell.visible)
                    ++n
            }
            return n
        }
    }
}
