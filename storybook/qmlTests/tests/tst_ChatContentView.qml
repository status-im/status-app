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
            property int fetchCalls: 0

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(string messageId)

            function getChatId() { return "chat-1" }
            function loadMoreMessages() { fetchCalls++ }
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
            contentModuleMock.messagesModule.fetchCalls = 0
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

        // The view is driven by a window proxy over the messages model; the
        // lazy-attach gate applies to the proxy's source.
        function sourceOf(listView) {
            return listView.model ? listView.model.sourceModel : null
        }

        // Full role set (every model.* the delegate reads) so MessageView
        // rows build without warnings and with realistic heights.
        function appendMessage(i, contentType) {
            messagesModel.append(messageRoles("msg-" + i, i, Date.now() - i * 60000, contentType))
        }

        // A message arriving while the chat is open: the newest row, entering
        // at the recent end of the model.
        function insertNewest(i) {
            messagesModel.insert(0, messageRoles("msg-new-" + i, -1 - i,
                                                 Date.now() + (i + 1) * 60000))
        }

        function messageRoles(id, i, ts, contentType) {
            return {
                id: id,
                communityId: "",
                compressedKey: "zQ3peer",
                prevMsgIndex: i + 1,
                nextMsgIndex: i - 1,
                prevMsgTimestamp: ts - 60000,
                nextMsgTimestamp: ts + 60000,
                prevMsgSenderId: "",
                prevMsgContentType: 1,
                prevMsgDeleted: false,
                timestamp: ts,
                responseToMessageWithId: "",
                senderId: "0xpeer",
                senderDisplayName: "Peer",
                senderOptionalName: "",
                senderIcon: "",
                senderIsAdded: true,
                senderEnsVerified: false,
                senderTrustStatus: 0,
                amISender: false,
                usesDefaultName: true,
                messageText: "Message " + i + " — the quick brown fox jumps over the lazy dog.",
                unparsedText: "Message " + i,
                messageImage: "",
                messageAttachments: "",
                albumImagesCount: 0,
                albumMessageImages: "",
                contentType: contentType === undefined ? 1 : contentType,
                sticker: "",
                stickerPack: -1,
                editMode: false,
                isEdited: false,
                outgoingStatus: "",
                resendError: "",
                mentioned: false,
                gapFrom: 0,
                gapTo: 0,
                quotedMessageText: "",
                quotedMessageParsedText: "",
                quotedMessageFrom: "",
                quotedMessageContentType: 1,
                quotedMessageDeleted: false,
                quotedMessageAuthorName: "",
                quotedMessageAuthorDisplayName: "",
                quotedMessageAuthorThumbnailImage: "",
                quotedMessageAuthorEnsVerified: false,
                quotedMessageAuthorIsContact: false,
                quotedMessageAlbumImagesCount: 0,
                quotedMessageAlbumMessageImages: "",
                reactions: "",
                pinned: false,
                pinnedBy: "",
                deleted: false,
                deletedBy: "",
                deletedByContactDisplayName: "",
                deletedByContactIcon: "",
                bridgeName: "",
                links: "",
                transactionParameters: ""
            }
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

        // Bug repro (device): the initial fetch runs with the model detached,
        // and the paging placeholder must not unstick the view meanwhile —
        // once loading finishes the view must sit at the newest message, not
        // at the top showing the placeholder skeleton.
        function test_opensAtNewestAfterLoadingFinishes() {
            contentModuleMock.messagesModule.loading = true

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            // give the paging timer time to fire against the empty window
            wait(400)

            for (let i = 0; i < 200; ++i)
                appendMessage(i)
            contentModuleMock.messagesModule.loading = false

            const listView = findChild(view, "chatLogView")
            verify(!!listView)
            tryVerify(() => listView.count > 0, 5000)
            tryVerify(() => listView.stickingToNewest, 5000,
                      "view must stay stuck to the newest message across the loading phase")
            tryVerify(() => listView.atNewest, 5000,
                      "view must open anchored on the newest message, contentY="
                      + listView.contentY + " contentHeight=" + listView.contentHeight)
        }

        // Bug repro (device): a channel whose oldest row is the chat
        // identifier has its entire history in the model — the view must not
        // keep requesting more history (fetch storm) nor advertise older
        // messages above the channel start.
        function test_noFetchStormAtChannelStart() {
            for (let i = 0; i < 10; ++i)
                appendMessage(i)
            appendMessage(10, Constants.messageContentType.chatIdentifier)

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)
            tryVerify(() => listView.count > 0, 5000)

            // whole history is in the window; let the paging timer run
            wait(500)
            compare(contentModuleMock.messagesModule.fetchCalls, 0,
                    "no history fetch may fire when the channel start is already loaded")
            verify(!listView.moreUpAvailable,
                   "no older messages may be advertised above the channel start")
        }

        // The backend keeps a fetch-more row above the chat identifier while
        // older messages can be requested — the view must page the backend
        // through it (the identifier alone is present in every chat and must
        // not read as "history exhausted").
        function test_fetchesMoreHistoryWhileChannelStartNotLoaded() {
            // few enough rows that the content stays shorter than the viewport,
            // keeping the paging placeholder visible without any scrolling
            for (let i = 0; i < 3; ++i)
                appendMessage(i)
            appendMessage(3, Constants.messageContentType.fetchMoreMessagesButton)
            appendMessage(4, Constants.messageContentType.chatIdentifier)

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)
            tryVerify(() => listView.count > 0, 5000)

            tryVerify(() => contentModuleMock.messagesModule.fetchCalls > 0, 5000,
                      "the view must page the backend while older messages can be requested")
        }

        // A sent message slides the window to the recent end; it must not
        // rebuild it — the teardown flashed the paging skeleton over the
        // user's own messages on every send.
        function test_sentMessageDoesNotRebuildTheWindow() {
            for (let i = 0; i < 200; ++i)
                appendMessage(i)

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)
            tryVerify(() => listView.count >= 20, 5000)
            tryVerify(() => listView.atNewest, 5000)

            // slide the window into history through the test seam
            const internal = findChild(view, "chatMessagesViewInternal")
            verify(!!internal)
            internal.windowStart = 30
            internal.windowStartGoal = 30
            internal.windowEnd = 60
            internal.windowEndGoal = 60
            tryVerify(() => listView.count > 0, 5000)

            const preSendCount = listView.count
            let minCount = preSendCount
            listView.countChanged.connect(() => {
                minCount = Math.min(minCount, listView.count)
            })

            contentModuleMock.messagesModule.messageSuccessfullySent()

            tryVerify(() => listView.atNewest, 5000,
                      "a sent message must land the view on the newest message")
            verify(minCount >= preSendCount,
                   "the window must not be torn down on send: count dropped to " + minCount
                   + " from " + preSendCount)
        }

        // A jump to a message deep in history collapses the window around the
        // target; the content shrink must not re-stick the view or walk the
        // window back to the recent end — the user must stay on the target.
        function test_jumpToMessageDeepInHistoryStaysOnTarget() {
            for (let i = 0; i < 300; ++i)
                appendMessage(i)

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)
            tryVerify(() => listView.count >= 20, 5000)
            tryVerify(() => listView.atNewest, 5000)

            const internal = findChild(view, "chatMessagesViewInternal")
            verify(!!internal)
            internal.goToMessage(150)

            tryVerify(() => internal.windowStart > 0, 5000,
                      "the window must move to the jump target")

            // the window must SETTLE away from the recent end: sample over a
            // second and require windowStart never to converge back to 0
            let minStart = internal.windowStart
            for (let i = 0; i < 20; ++i) {
                wait(50)
                minStart = Math.min(minStart, internal.windowStart)
            }
            verify(minStart > 0,
                   "the jump must not be cancelled by the window collapse, "
                   + "windowStart fell back to " + minStart)
            verify(!listView.stickingToNewest,
                   "the view must not stick to the newest after a jump into history")
        }

        // The window must grow towards its initial size in bounded steps —
        // building the whole initial window in one synchronous batch is what
        // froze the app on window moves.
        function test_windowGrowsInBoundedSteps() {
            for (let i = 0; i < 500; ++i)
                appendMessage(i)

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)

            // watch the window bound itself: every growth step must stay
            // within the driver's per-frame budget, no matter when the test
            // process gets to observe the item count
            const internal = findChild(view, "chatMessagesViewInternal")
            verify(!!internal)
            let maxJump = 0
            let prev = internal.windowEnd
            internal.windowEndChanged.connect(() => {
                maxJump = Math.max(maxJump, internal.windowEnd - prev)
                prev = internal.windowEnd
            })

            // the window reaches its initial size, anchored on the newest
            // message, having grown only in budgeted steps
            tryVerify(() => listView.count >= 20, 5000)
            verify(maxJump <= internal.moveBudget,
                   "window bound may only move moveBudget rows at a time, jumped " + maxJump)
            const deadline = Date.now() + 5000
            while (Date.now() < deadline && !listView.atNewest)
                wait(50)
            verify(listView.atNewest,
                   "must settle at the newest message: contentY=" + listView.contentY
                   + " bottom=" + (listView.contentHeight - listView.height)
                   + " stick=" + listView.stickingToNewest
                   + " moreDown=" + listView.moreDownAvailable
                   + " count=" + listView.count)
        }

        // Builds the view on a history of the given size and waits until it
        // shows the newest message.
        function openAtNewest(messageCount) {
            for (let i = 0; i < messageCount; ++i)
                appendMessage(i)

            const view = createTemporaryObject(contentViewComp, root)
            verify(!!view)
            tryVerify(() => view.chatMessagesLoader.status === Loader.Ready, 10000)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)
            const internal = findChild(view, "chatMessagesViewInternal")
            verify(!!internal)
            tryVerify(() => listView.count > 0, 20000)

            const chat = { view: view, listView: listView, internal: internal }
            // Paging is an independent mover of the same geometry: with the
            // whole history in the model it keeps sliding the window for as
            // long as a placeholder shows, which a measurement could not tell
            // apart from the insert under test. The window is driven through
            // the seam from here on.
            listView.moreUpAvailable = false
            listView.moreDownAvailable = false

            // the window still walks towards its goal a few rows per frame;
            // scrolling only means something once the content outgrew the
            // viewport
            waitForQuietWindow(chat)
            waitForRendered(listView, () => listView.contentHeight > listView.height * 2,
                            () => "the window must fill more than the viewport, contentHeight="
                                  + listView.contentHeight + " count=" + listView.count)
            waitForRendered(listView, () => listView.atNewest,
                            () => "the view must open on the newest message, contentY="
                                  + listView.contentY + " contentHeight=" + listView.contentHeight)
            return chat
        }

        // Layout positions and content height only catch up on a frame, so
        // conditions about them have to be waited for with rendering.
        function waitForRendered(listView, condition, message) {
            for (let i = 0; i < 600; ++i) {
                if (condition())
                    return
                wait(16)
                waitForRendering(listView)
            }
            fail(message())
        }

        // The window walks towards its goals a few rows per frame and the
        // paging timer may slide it further; a measurement is only meaningful
        // once it stands still — which takes both bounds at their goal and no
        // paging request for longer than the paging interval.
        function waitForQuietWindow(chat) {
            const internal = chat.internal
            const where = () => internal.windowStart + ".." + internal.windowEnd
                                + " goals " + internal.windowStartGoal + ".."
                                + internal.windowEndGoal
            // opening pages the window a chunk at a time while the content is
            // still shorter than the viewport, so the goals may run ahead of
            // the bounds before everything settles
            tryVerify(() => internal.windowStart === internal.windowStartGoal
                            && internal.windowEnd === internal.windowEndGoal,
                      30000, "the window must reach its goals, at " + where())

            let last = ""
            let stable = 0
            for (let i = 0; i < 400 && stable < 8; ++i) {
                wait(25)
                const now = where()
                stable = (now === last) ? stable + 1 : 0
                last = now
            }
            verify(stable >= 8, "the window must stop moving, at " + where())
            waitForRendering(chat.listView)
        }

        // The grid re-flows on polish and a freshly built MessageView settles
        // its height over a few frames; reading positions before that reads
        // the pre-insert layout.
        function waitForSettledLayout(listView) {
            let last = ""
            let stable = 0
            let placed = false
            // the grid only re-flows on a frame, so the wait has to render
            for (let i = 0; i < 600 && (!placed || stable < 3); ++i) {
                wait(16)
                waitForRendering(listView)
                const newest = listView.itemAtRow(0)
                const next = listView.itemAtRow(1)
                placed = !!newest && !!next && newest.y > next.y
                const now = listView.contentHeight + ":" + (newest ? newest.y : -1)
                          + ":" + listView.contentY
                stable = (now === last) ? stable + 1 : 0
                last = now
            }
            verify(placed, "the newest row must end up laid out below the older ones")
            verify(stable >= 3, "the layout must settle, at " + last)
        }

        // Grows the window to its cap at the recent end, through the test
        // seam: paging there row by row would take the whole test.
        function growToCap(chat) {
            chat.internal.windowEnd = chat.internal.maxWindowSize - 1
            chat.internal.windowEndGoal = chat.internal.windowEnd
            tryCompare(chat.listView, "count", chat.internal.maxWindowSize, 30000)
            waitForQuietWindow(chat)
        }

        // Records a delegate inside the viewport together with where it sits
        // on screen, once its height stopped settling.
        function trackVisibleRow(listView) {
            for (let attempt = 0; attempt < 20; ++attempt) {
                let item = null
                for (let k = 0; k < listView.count && !item; ++k) {
                    const candidate = listView.itemAtRow(k)
                    if (!candidate)
                        continue
                    const y = candidate.mapToItem(listView, 0, 0).y
                    if (y >= 100 && y <= listView.height - 100)
                        item = candidate
                }
                verify(!!item, "no delegate inside the viewport, contentY=" + listView.contentY)

                const before = item.mapToItem(listView, 0, 0).y
                waitForRendering(listView)
                const after = item.mapToItem(listView, 0, 0).y
                if (before === after)
                    return { item: item, messageId: item.messageId, y: after }
            }
            fail("the tracked row never stopped moving")
        }

        // A message arriving while the user reads back in history must not
        // move what is on screen, neither by entering at the bottom nor by
        // pushing the oldest window row out at the top.
        function test_bottomInsertWhileUnstuckKeepsViewAnchored() {
            const chat = openAtNewest(200)
            const listView = chat.listView

            listView.contentY = listView.contentHeight - listView.height - 150
            verify(!listView.stickingToNewest)
            waitForRendering(listView)

            const tracked = trackVisibleRow(listView)
            const preCount = listView.count
            const oldestBefore = listView.itemAtRow(listView.count - 1).messageId
            const windowEndBefore = chat.internal.windowEnd

            insertNewest(0)

            tryVerify(() => listView.itemAtRow(listView.count - 1).messageId !== oldestBefore,
                      20000, "the oldest window row must be evicted as the new one enters")
            tryCompare(listView, "count", preCount, 20000)
            waitForSettledLayout(listView)

            compare(tracked.item.messageId, tracked.messageId)
            fuzzyCompare(tracked.item.mapToItem(listView, 0, 0).y, tracked.y, 1)
            verify(!listView.stickingToNewest)
            compare(chat.internal.windowEnd, windowEndBefore)
        }

        // Same, with the window at its cap and slid into history: the insert
        // shifts the window bounds instead of evicting, and the rows on screen
        // must survive that round trip in place.
        function test_bottomInsertAtMaxWindowKeepsViewAnchored() {
            const chat = openAtNewest(500)
            const listView = chat.listView
            const internal = chat.internal

            growToCap(chat)

            listView.contentY = listView.height + 100
            verify(!listView.stickingToNewest)
            waitForRendering(listView)

            // slide the full window into history, overlapping the rows already
            // built: a window emptied in between would leave the view with
            // nothing to hold on to
            internal.windowStart = 30
            internal.windowStartGoal = 30
            internal.windowEnd = 30 + internal.maxWindowSize - 1
            internal.windowEndGoal = internal.windowEnd
            tryCompare(listView, "count", internal.maxWindowSize, 10000)
            waitForQuietWindow(chat)
            compare(internal.windowStart, 30)

            const tracked = trackVisibleRow(listView)
            const startBefore = internal.windowStart

            insertNewest(1)

            tryCompare(internal, "windowStart", startBefore + 1, 20000)
            waitForSettledLayout(listView)

            compare(tracked.item.messageId, tracked.messageId)
            fuzzyCompare(tracked.item.mapToItem(listView, 0, 0).y, tracked.y, 1)
            compare(listView.count, internal.maxWindowSize)
            verify(!listView.stickingToNewest)
        }

        // The same cap, pinned to the recent end: no bound shift, the oldest
        // window row is evicted instead.
        function test_bottomInsertAtCapRecentEndKeepsViewAnchored() {
            const chat = openAtNewest(500)
            const listView = chat.listView
            const internal = chat.internal

            growToCap(chat)

            listView.contentY = listView.height + 100
            verify(!listView.stickingToNewest)
            waitForRendering(listView)

            const tracked = trackVisibleRow(listView)
            const oldestBefore = listView.itemAtRow(listView.count - 1).messageId

            insertNewest(2)

            tryVerify(() => listView.itemAtRow(listView.count - 1).messageId !== oldestBefore,
                      20000, "the oldest window row must be evicted as the new one enters")
            tryCompare(listView, "count", internal.maxWindowSize, 20000)
            waitForSettledLayout(listView)

            compare(tracked.item.messageId, tracked.messageId)
            fuzzyCompare(tracked.item.mapToItem(listView, 0, 0).y, tracked.y, 1)
            compare(internal.windowStart, 0)
            verify(!listView.stickingToNewest)
        }
    }
}
