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

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool active: true
            readonly property bool hasUnreadMessages: false
            readonly property bool canPost: true
            readonly property bool canView: true
            readonly property bool canPostReactions: true
            readonly property string emoji: ""
        }

        readonly property var messagesModule: QtObject {
            readonly property var model: messagesModel
            property bool loading: false

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
            messagesModel.clear()
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
            tryVerify(() => !skeleton.visible)
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
            tryVerify(() => !skeleton.visible)
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
            verify(!skeleton.visible)
        }

        // While the host section is still incubating behind its skeleton
        // (this view effectively invisible), the model must stay detached
        // even after the inner loader is Ready — the message tail would
        // otherwise build inside the time-sliced incubation window. It
        // attaches on first show and stays attached afterwards.
        function test_modelWaitsForFirstShow() {
            for (let i = 0; i < 30; ++i)
                messagesModel.insert(0, { id: "msg-" + i })

            const view = createTemporaryObject(contentViewComp, root,
                                               { visible: false })
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)
            wait(50)
            compare(listView.count, 0,
                    "rows must not build while the view has never been shown")

            view.visible = true
            tryVerify(() => listView.model === messagesModel, 5000,
                      "model must attach on first show")

            // latched: hiding the chat again must not detach the model
            view.visible = false
            verify(listView.model === messagesModel,
                   "model must stay attached once shown")
        }

        // While the initial fetch populates the model row by row, the list
        // must not build (and then shift/destroy) a delegate per insertion —
        // rows only reach the view once loading is done.
        function test_noMessageRowsBuiltWhileDataLoading() {
            contentModuleMock.messagesModule.loading = true

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)

            for (let i = 0; i < 30; ++i)
                messagesModel.insert(0, { id: "msg-" + i })
            waitForRendering(listView)

            compare(listView.count, 0,
                    "rows must not reach the list view while the initial fetch is running")

            messagesModel.clear()
            contentModuleMock.messagesModule.loading = false
            tryVerify(() => listView.model === messagesModel)
        }
    }
}
