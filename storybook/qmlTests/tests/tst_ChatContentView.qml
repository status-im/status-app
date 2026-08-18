import QtQuick
import QtTest

import utils

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 Perf guard: switching chats must be instant. The heavy part of a chat —
 the messages view — must incubate asynchronously behind a skeleton while
 the shell (header, input) stays responsive. Building ChatMessagesView
 synchronously was the main remaining block of the switch freeze.
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

            function getChatId() { return "chat-1" }
            function loadMoreMessages() {}
            function updateKeepUnread(flag) {}
        }

        function getMyChatId() { return "chat-1" }
        function amIChatAdmin() { return false }
    }

    Component {
        id: contentViewComp

        ChatContentView {
            width: 800
            height: 600

            rootStore: rootStoreMock
            chatContentModule: contentModuleMock
            chatId: "chat-1"
            chatType: Constants.chatType.oneToOne
            usersModel: ListModel {}
            joined: true
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

        // chatDetails.active is set by the backend (onMadeActive) before the
        // asynchronously incubated ChatMessagesView exists, so the view never
        // receives activeChanged on a cold open. Marking the chat read must
        // not depend on that signal — the state-driven triggers
        // (visibleChanged/countChanged) have to cover the late-built view.
        function test_unreadChatMarkedReadWhenViewIncubatesLate() {
            contentModuleMock.chatDetails.hasUnreadMessages = true

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)

            // the bug precondition: the chat is already active while the
            // messages view is still incubating
            verify(contentModuleMock.chatDetails.active)
            verify(view.chatMessagesLoader.status !== Loader.Ready,
                   "view must still be incubating when active is already set")

            tryVerify(() => contentModuleMock.markAllMessagesReadCalls > 0, 10000,
                      "a cold-opened unread chat must still get marked read")
        }

        function test_messagesViewIncubatesAsynchronously() {
            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)

            // synchronously after creation the messages view must not be
            // built yet — the skeleton covers the area
            verify(view.chatMessagesLoader.status !== Loader.Ready,
                   "messages view must not be built synchronously with the chat shell")

            const skeleton = findChild(view, "chatMessagesSkeleton")
            verify(!!skeleton)
            verify(skeleton.visible)

            // the messages view arrives asynchronously and replaces the
            // skeleton
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)
            verify(!!view.chatMessagesLoader.item)
            tryVerify(() => !findChild(view, "chatMessagesSkeleton"), 5000,
                      "skeleton must be destroyed once the messages view is ready")
        }

        // The single skeleton covers BOTH phases: view construction and the
        // backend messages fetch (there is no separate in-view skeleton).
        function test_skeletonCoversDataLoadingPhase() {
            contentModuleMock.messagesModule.loading = true

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)

            const skeleton = findChild(view, "chatMessagesSkeleton")
            verify(!!skeleton)

            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)
            verify(skeleton.visible,
                   "skeleton must stay up while messages are still being fetched")

            contentModuleMock.messagesModule.loading = false
            tryVerify(() => !findChild(view, "chatMessagesSkeleton"), 5000,
                      "skeleton must be released once the fetch is done")
        }

        // The skeleton is not an overlay: whatever it covers must not paint
        // underneath it — the real view stays invisible until it is ready
        // AND its data is loaded.
        function test_messagesViewHiddenWhileSkeletonShown() {
            contentModuleMock.messagesModule.loading = true

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)

            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            const skeleton = findChild(view, "chatMessagesSkeleton")
            verify(!!skeleton)
            verify(skeleton.visible)
            verify(!view.chatMessagesLoader.item.visible,
                   "messages view must be invisible while the skeleton shows")

            contentModuleMock.messagesModule.loading = false
            tryVerify(() => view.chatMessagesLoader.item.visible)
            tryVerify(() => !findChild(view, "chatMessagesSkeleton"), 5000,
                      "skeleton must be released once the view is shown")
        }
    }
}
