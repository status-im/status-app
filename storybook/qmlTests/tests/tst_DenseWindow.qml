import QtQuick
import QtTest

import StatusQ 0.1
import utils

import shared.views.chat

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 Dense window (issue 0022): the message window runs over a model whose row
 count is the chat's whole stored-message count, so an index is an absolute
 history position. Unfetched rows are dummies showing skeleton until their
 roles arrive; placeholders span the real row counts on each side; a settle
 maps the viewport position straight to an index and teleports there, hole or
 not; the scrollbar drives the same path.

 The harness links no middleware, so the dense model is stood in for by a
 ListModel presenting the same contract: a fixed row count equal to the total,
 a `loaded` role, a `key` every row has, fills applied as dataChanged (never
 insert/remove) and inserts/removals only at the ends. It deviates in one
 way, deliberately: a dummy's key here is stable rather than positional, so a
 test can name a dummy row across a backfill.
*/
Item {
    id: root

    width: 800
    height: 600

    ChatStores.RootStore { id: rootStoreMock }

    // The legacy model the store still exposes; the dense model is what the
    // window runs over.
    ListModel { id: legacyModel }
    ListModel { id: denseSource }

    component ContentModuleMock: QtObject {
        id: moduleMock

        property string mockChatId: "chat-1"

        function markAllMessagesRead() {}

        readonly property var chatDetails: QtObject {
            readonly property string id: moduleMock.mockChatId
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
            readonly property var model: legacyModel
            readonly property var denseModel: denseSource
            property bool loading: false
            property bool keepUnread: false

            property int loadMoreCalls: 0
            property int aroundCalls: 0
            property string lastAroundId: ""
            property int indexLookups: 0
            property int rankFetchCalls: 0
            property int lastRankFetched: -1
            property int lastWindowFirst: -1
            property int lastWindowLast: -1
            property int lastWindowMargin: -1

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(int messageIndex)
            signal messagesWindowLoaded(string anchorId, int anchorIndex, string error)
            signal scrollToMessageId(string messageId)

            function getChatId() { return moduleMock.mockChatId }
            function loadMoreMessages() { loadMoreCalls++ }
            function updateKeepUnread(flag) {}
            function loadMessagesAroundMessage(messageId) {
                aroundCalls++
                lastAroundId = messageId
            }
            function jumpToMessage(messageId) {
                scrollToMessageId(messageId)
            }
            // What the real view answers from the dense store's islands: the
            // loaded rows only. The stub walks the model because it has no
            // island bookkeeping, but the contract is the same - a dummy
            // answers -1.
            function indexOfMessageId(messageId) {
                indexLookups++
                if (!messageId)
                    return -1
                for (let i = 0; i < denseSource.count; ++i) {
                    const row = denseSource.get(i)
                    if (row.loaded === true && row.key === messageId)
                        return i
                }
                return -1
            }
            function loadMessagesAtRank(rank) {
                rankFetchCalls++
                lastRankFetched = rank
            }
            function setDenseWindow(first, last, margin) {
                lastWindowFirst = first
                lastWindowLast = last
                lastWindowMargin = margin
            }
        }

        function getMyChatId() { return moduleMock.mockChatId }
        function amIChatAdmin() { return false }
    }

    ContentModuleMock {
        id: contentModuleMock
        mockChatId: "chat-1"
    }

    Component {
        id: poolComp

        DelegatePool {
            DelegatePoolKind {
                objectName: "messageKind"
                kind: "message"
                target: 0

                delegate: Component {
                    MessageView {}
                }
            }
        }
    }

    Component {
        id: sectionComp

        Item {
            id: harness

            width: 800
            height: 600

            property DelegatePool rowPool: null

            ChatContentView {
                id: shellA
                anchors.fill: parent
                rootStore: rootStoreMock
                chatContentModule: contentModuleMock
                chatId: "chat-1"
                chatType: Constants.chatType.oneToOne
            }

            ChatMessagesView {
                parent: shellA.messagesSlot
                anchors.fill: parent

                rowPool: harness.rowPool
                rootStore: rootStoreMock
                messageStore: shellA.messageStore
                chatContentModule: contentModuleMock
                chatId: "chat-1"
                isOneToOne: true
                usersModel: ListModel {}
                joined: true
            }
        }
    }

    TestCase {
        name: "DenseWindow"
        when: windowShown

        function cleanup() {
            contentModuleMock.messagesModule.loading = false
            contentModuleMock.messagesModule.loadMoreCalls = 0
            contentModuleMock.messagesModule.aroundCalls = 0
            contentModuleMock.messagesModule.lastAroundId = ""
            contentModuleMock.messagesModule.indexLookups = 0
            contentModuleMock.messagesModule.rankFetchCalls = 0
            contentModuleMock.messagesModule.lastRankFetched = -1
            contentModuleMock.messagesModule.lastWindowFirst = -1
            legacyModel.clear()
            denseSource.clear()
        }

        // ---- the dense-model stub ----

        function dummyRoles(key) {
            const roles = loadedRoles(key, "", 0, 1)
            roles.loaded = false
            return roles
        }

        function loadedRoles(key, id, ts, contentType) {
            return {
                key: key,
                loaded: true,
                id: id,
                communityId: "",
                compressedKey: "zQ3peer",
                prevMsgIndex: -1,
                nextMsgIndex: -1,
                prevMsgTimestamp: 0,
                nextMsgTimestamp: 0,
                prevMsgSenderId: "",
                prevMsgContentType: 1,
                prevMsgDeleted: false,
                timestamp: ts,
                responseToMessageWithId: "",
                senderId: id === "" ? "" : "0xpeer",
                senderDisplayName: id === "" ? "" : "Peer",
                senderOptionalName: "",
                senderIcon: "",
                senderIsAdded: true,
                senderEnsVerified: false,
                senderTrustStatus: 0,
                amISender: false,
                usesDefaultName: true,
                messageText: id === "" ? "" : (id + " — the quick brown fox jumps over the lazy dog."),
                unparsedText: id,
                messageImage: "",
                messageAttachments: "",
                albumImagesCount: 0,
                albumMessageImages: "",
                contentType: contentType,
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

        // Index 0 is the newest message; the newest `loadedCount` rows are
        // fetched, everything older is a hole.
        function buildDense(total, loadedCount) {
            denseSource.clear()
            for (let i = 0; i < total; ++i) {
                if (i < loadedCount)
                    denseSource.append(loadedRoles("msg-" + i, "msg-" + i,
                                                  Date.now() - i * 60000, 1))
                else
                    denseSource.append(dummyRoles("dummy-" + i))
            }
        }

        // A page arriving: dataChanged in place, never insert/remove.
        function fillRows(first, count) {
            for (let i = first; i < first + count; ++i) {
                const key = denseSource.get(i).key
                const roles = loadedRoles(key, "msg-at-" + key,
                                          Date.now() - i * 60000, 1)
                denseSource.set(i, roles)
            }
        }

        function keysOf(internal, listView) {
            const keys = []
            for (let i = 0; i < listView.count; ++i) {
                const item = listView.itemAtRow(i)
                keys.push(item ? item.rowKey : "<none>")
            }
            return keys
        }

        // ---- harness ----

        function openDenseChat(total, loadedCount) {
            buildDense(total, loadedCount)

            const pool = createTemporaryObject(poolComp, root,
                                               { backgroundIntervalMs: 0 })
            verify(!!pool)
            const view = createTemporaryObject(sectionComp, root, { rowPool: pool })
            verify(!!view)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)
            const internal = findChild(view, "chatMessagesViewInternal")
            verify(!!internal)
            const kind = findChild(pool, "messageKind")
            verify(!!kind)

            tryVerify(() => listView.count > 0, 20000)
            tryVerify(() => !internal.initialFillActive, 20000,
                      "the initial batch must reveal")
            verify(internal.denseMode, "the window must run over the dense model")

            return { pool: pool, kind: kind, view: view,
                     listView: listView, internal: internal }
        }

        function builtCount(chat) {
            return chat.internal.acquiredCount + chat.kind.readyCount
        }

        function waitForFullPool(chat) {
            tryVerify(() => builtCount(chat) >= chat.kind.target, 60000,
                      "the pool must reach its target, built "
                      + builtCount(chat) + " of " + chat.kind.target)
        }

        function waitForQuietWindow(chat) {
            const internal = chat.internal
            tryVerify(() => internal.stagedCount === 0, 30000,
                      "staged rows must all reveal")
            let last = ""
            let stable = 0
            for (let i = 0; i < 400 && stable < 8; ++i) {
                wait(25)
                const now = internal.windowStart + ".." + internal.windowEnd
                stable = (now === last) ? stable + 1 : 0
                last = now
            }
            verify(stable >= 8, "the window must stop moving, at " + last)
            waitForRendering(chat.listView)
        }

        // ---- the fling gate, over the dense model ----
        // The 0013 invariant must survive everything the dense model adds:
        // holes in the window, dummy rows resizing as they fill, and settles
        // that teleport into unfetched history. Across six flings no flick is
        // cancelled, content geometry never moves mid-motion, and the window
        // still advances.
        function test_flingContinuityOverHoles() {
            const chat = openDenseChat(4000, 120)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            // hard enough to out-run the window every time: at this
            // deceleration the fling covers ~12,000px, a hundred-odd rows,
            // so every settle lands deep inside unfetched history
            listView.maximumFlickVelocity = 6000
            listView.flickDeceleration = 1500
            listView.contentY = listView.contentHeight - listView.height
            waitForRendering(listView)

            const startWindowEnd = internal.windowEnd

            let flickCancels = 0
            let topTouches = 0
            let contentHeightChanges = 0
            let downwardJumps = 0
            let maxTrackedContentShift = 0
            let teleports = 0
            let sampledRounds = 0

            for (let round = 0; round < 6; ++round) {
                let tracked = null
                for (let i = 0; i < listView.count; ++i) {
                    const it = listView.itemAtRow(i)
                    if (it && it.visible && it.height > 0) {
                        tracked = it
                        break
                    }
                }
                verify(!!tracked, "round " + round + " needs a visible row to track")
                let lastContentPos = tracked.y

                const startCy = listView.contentY
                const endBefore = internal.windowEnd
                let travel = 0
                listView.flick(0, 5000)
                internal.updateScrollGate(listView.height * 2)
                tryVerify(() => listView.flickingVertically, 1000,
                          "round " + round + " flick must start")

                let lastCy = listView.contentY
                let lastCh = listView.contentHeight
                // whether the sampler ever caught the flick in flight: under
                // load a single wait() can outlast the whole fling, and a
                // sampler that saw nothing must not vote on whether it was
                // cancelled
                let sawFlicking = false
                for (let t = 0; t < 400; ++t) {
                    wait(16)
                    const flicking = listView.flickingVertically
                    const cy = listView.contentY
                    if (!flicking)
                        break
                    sawFlicking = true
                    const ch = listView.contentHeight
                    if (Math.abs(ch - lastCh) > 0.5)
                        contentHeightChanges++
                    if (cy - lastCy > 0.5)
                        downwardJumps++
                    if (cy <= 1)
                        topTouches++
                    if (!tracked.retired) {
                        const shift = Math.abs(tracked.y - lastContentPos)
                        if (shift > maxTrackedContentShift)
                            maxTrackedContentShift = shift
                        lastContentPos = tracked.y
                    }
                    travel = startCy - cy
                    lastCy = cy
                    lastCh = ch
                }
                if (sawFlicking)
                    ++sampledRounds
                if (sawFlicking && travel < 4000 && listView.contentY > 1)
                    flickCancels++

                internal.updateScrollGate(0)
                tryVerify(() => !listView.moving, 5000)
                tryVerify(() => internal.stagedCount === 0, 30000,
                          "round " + round + " settle batch must reveal")
                waitForRendering(listView)
                // a slide can only ever grow the window by one chunk; more
                // than that in one settle is the teleport
                if (internal.windowEnd - endBefore > internal.windowChunkSize)
                    teleports++

                // the page for the rank the settle landed on arrives, so the
                // next fling starts from a window that is dressing
                fillRows(internal.windowStart,
                         internal.windowEnd - internal.windowStart + 1)
                contentModuleMock.messagesModule.messagesWindowLoaded(
                            "", internal.windowEnd, "")
                tryVerify(() => internal.stagedCount === 0, 30000)
            }

            console.info("[DENSE FLING] flickCancels=" + flickCancels
                         + " topTouches=" + topTouches
                         + " contentHeightChanges=" + contentHeightChanges
                         + " downwardJumps=" + downwardJumps
                         + " maxTrackedContentShift=" + maxTrackedContentShift.toFixed(0)
                         + " teleports=" + teleports
                         + " sampledRounds=" + sampledRounds
                         + " window " + startWindowEnd + " -> " + internal.windowEnd)

            verify(sampledRounds >= 4,
                   "the sampler must have caught most flings in flight, saw "
                   + sampledRounds + " of 6")
            compare(flickCancels, 0)
            compare(topTouches, 0)
            compare(contentHeightChanges, 0)
            compare(downwardJumps, 0)
            verify(maxTrackedContentShift <= 2,
                   "rows must hold their content position mid-motion, shifted "
                   + maxTrackedContentShift)
            verify(teleports > 0, "the sequence must include a teleport")
            verify(internal.windowEnd > startWindowEnd + 30,
                   "the window must advance across the fling sequence, still at "
                   + internal.windowEnd)
        }

        // ---- placeholders span the real counts ----

        function test_placeholderHeightsFollowRealCounts() {
            const chat = openDenseChat(2000, 2000)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            const avg = internal.avgRowHeight > 0 ? internal.avgRowHeight : 48
            const rowsAbove = 2000 - 1 - internal.windowEnd
            // no 300-row cap: the placeholder stands for every row above the
            // window, which is what makes the scrollbar honest
            verify(rowsAbove > 300, "the history must exceed the old cap")
            fuzzyCompare(internal.topPlaceholderHeight, rowsAbove * avg, 1)

            // and each side reflects its own span, not the other's: with the
            // window still at the recent end there is nothing below it
            compare(internal.windowStart, 0)
            compare(internal.bottomPlaceholderHeight, 0)

            // slide until rows sit below the window, then the bottom
            // placeholder stands for exactly those
            for (let i = 0; i < 12 && internal.windowStart === 0; ++i) {
                internal.slideWindowToHistory()
                tryVerify(() => internal.stagedCount === 0, 20000,
                          "slide " + i + " must reveal")
            }
            verify(internal.windowStart > 0)
            const avgNow = internal.avgRowHeight > 0 ? internal.avgRowHeight : 48
            fuzzyCompare(internal.bottomPlaceholderHeight,
                         Math.max(listView.height, internal.windowStart * avgNow), 1)
            fuzzyCompare(internal.topPlaceholderHeight,
                         (2000 - 1 - internal.windowEnd) * avgNow, 1)
        }

        // ---- dummy rows: skeleton, then a paced dress on fill ----

        function test_dummyShowsSkeletonAndDressesThroughTheQueue() {
            const chat = openDenseChat(400, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            // every row in the window is a dummy: skeleton, no pooled item,
            // and real space held so the fill cannot move anything
            let dummies = 0
            for (let i = 0; i < listView.count; ++i) {
                const item = listView.itemAtRow(i)
                if (!item)
                    continue
                verify(!item.rowLoaded, "row " + i + " must be a dummy")
                verify(item.showsSkeleton, "row " + i + " must show skeleton")
                compare(item.pooledItem, null)
                verify(item.height > 0, "a dummy must hold a row of space")
                ++dummies
            }
            verify(dummies > 0)
            compare(internal.acquiredCount, 0,
                    "a window of dummies must hold no pooled items")

            const windowStart = internal.windowStart
            const windowEnd = internal.windowEnd
            const filled = windowEnd - windowStart + 1
            fillRows(windowStart, filled)

            // the fill must not have dressed anything inside the dataChanged
            // handler: it goes through the paced queue like every other dress
            compare(internal.acquiredCount, 0,
                    "no row may dress synchronously with the fill")
            let held = 0
            for (let i = 0; i < listView.count; ++i) {
                const item = listView.itemAtRow(i)
                if (item && item.rowLoaded && item.showsSkeleton)
                    ++held
            }
            verify(held > 0, "a filled row must hold its skeleton until dressed")

            tryVerify(() => internal.acquiredCount >= filled, 30000,
                      "the queue must dress the filled rows, at "
                      + internal.acquiredCount + " of " + filled)
            tryVerify(() => {
                for (let i = 0; i < listView.count; ++i) {
                    const item = listView.itemAtRow(i)
                    if (item && item.showsSkeleton)
                        return false
                }
                return true
            }, 30000, "every filled row must drop its skeleton once dressed")
        }

        // ---- index-shift invariant ----

        // A hole filling below the window (newer rows) is dataChanged over a
        // fixed row count: nothing shifts at all.
        function test_fillBelowWindowKeepsContent() {
            const chat = openDenseChat(600, 600)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            // drive the window off the recent end so there are rows below it
            for (let i = 0; i < 12 && internal.windowStart === 0; ++i) {
                internal.slideWindowToHistory()
                tryVerify(() => internal.stagedCount === 0, 20000,
                          "slide " + i + " must reveal")
            }
            verify(internal.windowStart > 0, "the window must leave the recent end")

            const before = keysOf(internal, listView)
            const start = internal.windowStart
            const end = internal.windowEnd
            fillRows(0, Math.min(20, start))
            waitForRendering(listView)

            compare(internal.windowStart, start)
            compare(internal.windowEnd, end)
            compare(keysOf(internal, listView).join(","), before.join(","))
        }

        // Backfill at the older end (higher indices) grows the row count
        // without touching the window's own rows.
        function test_backfillAboveWindowKeepsContent() {
            const chat = openDenseChat(600, 600)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            // off the recent end first: a window still pinned at index 0 is
            // shifted by nothing, so it could not tell a correct backfill
            // from one that wrongly moved the bounds
            for (let i = 0; i < 12 && internal.windowStart === 0; ++i) {
                internal.slideWindowToHistory()
                tryVerify(() => internal.stagedCount === 0, 20000,
                          "slide " + i + " must reveal")
            }
            verify(internal.windowStart > 0, "the window must leave the recent end")

            const before = keysOf(internal, listView)
            const start = internal.windowStart
            const end = internal.windowEnd
            for (let i = 600; i < 640; ++i)
                denseSource.append(dummyRoles("dummy-" + i))
            waitForRendering(listView)

            compare(internal.windowStart, start)
            compare(internal.windowEnd, end)
            compare(keysOf(internal, listView).join(","), before.join(","))
            compare(internal.historyCount, 640)
        }

        // A live message at the newest end shifts every index below it. The
        // window's bounds must move with it, in the same turn, so its content
        // is exactly the rows it held before.
        function test_liveInsertShiftsBoundsNotContent() {
            const chat = openDenseChat(600, 600)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            for (let i = 0; i < 12 && internal.windowStart === 0; ++i) {
                internal.slideWindowToHistory()
                tryVerify(() => internal.stagedCount === 0, 20000,
                          "slide " + i + " must reveal")
            }
            verify(internal.windowStart > 0, "the window must leave the recent end")

            const before = keysOf(internal, listView)
            const start = internal.windowStart
            const end = internal.windowEnd

            denseSource.insert(0, loadedRoles("live-1", "live-1", Date.now(), 1))

            // same turn as the model change: no wait before reading the bounds
            compare(internal.windowStart, start + 1)
            compare(internal.windowEnd, end + 1)
            waitForRendering(listView)
            compare(keysOf(internal, listView).join(","), before.join(","))
        }

        // A removal below the window shifts the other way, again without
        // changing which messages the window holds.
        function test_removalBelowWindowShiftsBoundsNotContent() {
            const chat = openDenseChat(600, 600)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            for (let i = 0; i < 12 && internal.windowStart === 0; ++i) {
                internal.slideWindowToHistory()
                tryVerify(() => internal.stagedCount === 0, 20000,
                          "slide " + i + " must reveal")
            }
            verify(internal.windowStart > 1, "the window must leave the recent end")

            const before = keysOf(internal, listView)
            const start = internal.windowStart
            const end = internal.windowEnd

            denseSource.remove(0, 1)

            compare(internal.windowStart, start - 1)
            compare(internal.windowEnd, end - 1)
            waitForRendering(listView)
            compare(keysOf(internal, listView).join(","), before.join(","))
        }

        // A fill INSIDE the window changes content — that is what a fill is —
        // but only the rows it names, and only through the roles arriving:
        // the window's bounds and the rest of its keys are untouched.
        function test_fillInsideWindowChangesOnlyItsRows() {
            const chat = openDenseChat(400, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            const start = internal.windowStart
            const end = internal.windowEnd
            const before = keysOf(internal, listView)
            verify(end - start >= 4, "the window must be wide enough to fill part of")

            fillRows(start, 2)
            waitForRendering(listView)

            compare(internal.windowStart, start)
            compare(internal.windowEnd, end)
            compare(keysOf(internal, listView).join(","), before.join(","))

            let loaded = 0
            for (let i = 0; i < listView.count; ++i) {
                const item = listView.itemAtRow(i)
                if (item && item.rowLoaded)
                    ++loaded
            }
            compare(loaded, 2, "only the filled rows may become loaded")
        }

        // ---- rank-exact teleport into a hole ----

        function test_teleportIntoHoleAdmitsDummiesAndFetchesTheRank() {
            const chat = openDenseChat(2000, 60)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            contentModuleMock.messagesModule.rankFetchCalls = 0

            // park deep inside the placeholder and settle there
            const span = internal.topPlaceholderHeight
            const rowsAbove = 2000 - 1 - internal.windowEnd
            const depth = span * 0.5
            listView.contentY = span - depth
            listView.flick(0, 300)
            tryVerify(() => listView.moving, 1000)
            const expected = internal.windowEnd
                           + Math.round(listView.viewportDepthIntoTopPlaceholder()
                                        / span * rowsAbove)
            listView.cancelFlick()
            tryVerify(() => !listView.moving, 5000)

            tryVerify(() => internal.windowEnd === expected, 10000,
                      "the teleport must land at the mapped index, expected "
                      + expected + " landed " + internal.windowEnd)
            tryVerify(() => internal.stagedCount === 0, 30000,
                      "the teleport batch must reveal")

            // the landing is inside a hole: dummies, skeleton, and the page
            // for that rank requested exactly once
            const item = listView.itemAtRow(listView.count - 1)
            verify(!!item)
            verify(!item.rowLoaded, "the landing row must still be a dummy")
            verify(item.showsSkeleton, "a dummy landing must show skeleton")
            compare(contentModuleMock.messagesModule.rankFetchCalls, 1)
            compare(contentModuleMock.messagesModule.lastRankFetched,
                    2000 - 1 - expected)

            // and the page dresses when it arrives
            fillRows(internal.windowStart,
                     internal.windowEnd - internal.windowStart + 1)
            contentModuleMock.messagesModule.messagesWindowLoaded("", expected, "")
            tryVerify(() => internal.acquiredCount > 0, 30000,
                      "the filled rows must dress")
        }

        // ---- the scrollbar names a history position ----

        // Dragging the scrollbar scrubs placeholder space and the release
        // settles: at either extreme the landing is the extreme row itself.
        function test_scrollbarRoundTripsAtTheExtremes() {
            const chat = openDenseChat(1500, 1500)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            // the freeze must cover the drag: no window move while pressed
            listView.externallyMoving = true
            const endBefore = internal.windowEnd
            listView.contentY = 0
            wait(400)
            compare(internal.windowEnd, endBefore,
                    "the window must not move while the scrollbar is held")

            // release: the settle teleports to the oldest row
            listView.externallyMoving = false
            tryVerify(() => internal.windowEnd === 1499, 10000,
                      "the release must land on the oldest row, at "
                      + internal.windowEnd)
            tryVerify(() => internal.stagedCount === 0, 30000)
            waitForRendering(listView)
            const oldest = listView.itemAtRow(listView.count - 1)
            verify(!!oldest)
            compare(oldest.rowKey, "msg-1499")

            // and back down to the newest
            listView.externallyMoving = true
            listView.contentY = listView.contentHeight - listView.height
            wait(400)
            listView.externallyMoving = false
            tryVerify(() => internal.windowStart === 0, 15000,
                      "the release must land back on the newest row, at "
                      + internal.windowStart)
        }

        // The scrollbar's own drag is what the freeze must cover: the
        // Flickable reports no motion at all while it is held, so the view
        // has to declare it.
        function test_scrollbarPressCountsAsMotion() {
            const chat = openDenseChat(1500, 1500)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            const scrollBar = findChild(chat.view, "chatLogScrollBar")
            verify(!!scrollBar, "the message view must expose its scrollbar")
            verify(scrollBar.visible)

            compare(listView.externallyMoving, false)
            compare(internal.viewMoving, false)

            // the native macOS scrollbar style reads a transition duration
            // off a style item that offscreen never creates
            ignoreWarning(new RegExp("Unable to assign \\[undefined\\] to int"))
            mousePress(scrollBar, scrollBar.width / 2, scrollBar.height - 4)
            verify(scrollBar.pressed, "the press must reach the scrollbar")
            compare(listView.externallyMoving, true)
            compare(internal.viewMoving, true)
            compare(listView.moving, false,
                    "the Flickable itself sees no motion — that is the point")

            mouseRelease(scrollBar, scrollBar.width / 2, scrollBar.height - 4)
            compare(listView.externallyMoving, false)
            compare(internal.viewMoving, false)
        }

        // ---- the row-height estimate settles ----

        // Tops the sample up to the point where the estimate is allowed to
        // hold, without moving it: every row fed here is exactly the height
        // the estimate already says rows are.
        function establishRowHeight(internal) {
            verify(internal.rowHeightSampleCount > 0,
                   "the reveals that already happened must have fed the sample")
            for (let i = 0; i < 200
                 && internal.rowHeightSampleCount < internal.rowHeightSettleCount; ++i)
                internal.observeRowHeights(internal.avgRowHeight * 8, 8)
            verify(internal.rowHeightSampleCount >= internal.rowHeightSettleCount,
                   "the sample must reach the settle count")
        }

        // Batch means wander either side of the truth — message heights
        // differ, batch to batch — and the estimate must not follow them.
        // Dense mode multiplies it by the rows outside the window, thousands
        // of them, so a per-batch re-average turned a two-pixel drift into a
        // several-thousand-pixel content-height change on every reveal.
        function test_rowHeightEstimateHoldsUnderVaryingBatches() {
            const chat = openDenseChat(4000, 4000)
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            establishRowHeight(internal)

            const base = internal.avgRowHeight
            verify(base > 0)
            const basePlaceholder = internal.topPlaceholderHeight
            verify(4000 - 1 - internal.windowEnd > 3000,
                   "the placeholder must stand for thousands of rows")
            verify(basePlaceholder > 100000,
                   "and so must be worth thousands of pixels, is "
                   + basePlaceholder)

            const wobble = [0.85, 1.14, 0.9, 1.12, 0.88, 1.15, 0.93, 1.08,
                            0.86, 1.11, 0.95, 1.05, 0.87, 1.13, 0.91, 1.09,
                            0.89, 1.1, 0.94, 1.06]
            let worstEstimate = 0
            let worstGeometry = 0
            for (let i = 0; i < wobble.length; ++i) {
                internal.observeRowHeights(base * wobble[i] * 20, 20)
                worstEstimate = Math.max(
                            worstEstimate,
                            Math.abs(internal.avgRowHeight - base) / base)
                worstGeometry = Math.max(
                            worstGeometry,
                            Math.abs(internal.topPlaceholderHeight - basePlaceholder))
            }

            verify(worstEstimate < 0.02,
                   "the estimate must hold across wobbling batches, drifted "
                   + (worstEstimate * 100).toFixed(1) + "%")
            verify(worstGeometry < 1,
                   "and the geometry it feeds must not move, moved "
                   + worstGeometry.toFixed(0) + "px")
        }

        // The escape hatch: an estimate that could never move again would be
        // a constant, and a chat of one-line rows scrolled into an
        // image-heavy stretch would size its placeholders from the wrong
        // shape forever. Sustained contrary evidence moves it, in bounded
        // steps, and it stops once it agrees with what it measured.
        function test_rowHeightEstimateRelatchesOnADifferentShape() {
            const chat = openDenseChat(4000, 4000)
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            establishRowHeight(internal)

            const base = internal.avgRowHeight
            const tall = base * 3

            let rows = 0
            for (let i = 0; i < 60 && internal.avgRowHeight < base * 1.5; ++i) {
                internal.observeRowHeights(tall * 20, 20)
                rows += 20
            }
            verify(internal.avgRowHeight >= base * 1.5,
                   "a sustained different shape must re-estimate, still at "
                   + internal.avgRowHeight + " from " + base)
            verify(rows <= 400,
                   "and within a few batches, took " + rows + " rows")

            for (let i = 0; i < 300 && internal.avgRowHeight < tall * 0.9; ++i)
                internal.observeRowHeights(tall * 20, 20)
            verify(internal.avgRowHeight >= tall * 0.9,
                   "the estimate must converge on the evidence, reached "
                   + internal.avgRowHeight + " of " + tall)

            const settled = internal.avgRowHeight
            for (let i = 0; i < 20; ++i)
                internal.observeRowHeights(tall * 20, 20)
            fuzzyCompare(internal.avgRowHeight, settled, 0.001)
        }

        // A different chat is a different row shape, so the estimate must be
        // re-established from its rows rather than argued down from the last
        // chat's over hundreds of samples.
        function test_rowHeightEstimateIsForgottenPerChat() {
            const chat = openDenseChat(600, 600)
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            establishRowHeight(internal)

            const base = internal.avgRowHeight
            verify(internal.rowHeightSampleCount >= internal.rowHeightSettleCount)

            contentModuleMock.mockChatId = "chat-2"
            internal.openWindow()

            compare(internal.rowHeightSampleCount, 0,
                    "a chat switch must drop the previous chat's evidence")

            // one batch of the new chat's shape is enough to re-estimate,
            // where the settled sample would have needed a hundred rows
            internal.observeRowHeights(base * 3 * 8, 8)
            verify(internal.avgRowHeight >= base * 2.5,
                   "the new chat's first batch must establish the estimate, at "
                   + internal.avgRowHeight + " from " + base)

            contentModuleMock.mockChatId = "chat-1"
        }

        // The defect as the user saw it: skeleton rows on screen resizing as
        // batches landed, and the view lurching with them. With the estimate
        // held, a landing batch changes neither the space a dummy holds nor
        // where anything on screen sits. The view stays on the newest
        // message, so the bottom row is pinned and every dummy above it
        // carries the drift of all the rows below — the lever the user was
        // watching.
        function test_dummyRowsHoldTheirPlaceAsBatchesLand() {
            const chat = openDenseChat(4000, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            establishRowHeight(internal)

            let lowest = null
            let highest = null
            for (let i = 0; i < listView.count; ++i) {
                const item = listView.itemAtRow(i)
                if (!item || !item.visible || item.height <= 0)
                    continue
                verify(item.showsSkeleton, "row " + i + " must be a dummy")
                const top = item.mapToItem(listView, 0, 0).y
                if (top < 0 || top + item.height > listView.height)
                    continue
                lowest = lowest || item
                highest = item
            }
            verify(!!highest && highest !== lowest,
                   "the viewport must show a column of dummies")

            const dummySpace = internal.dummyRowHeight
            const dummyHeight = highest.height
            const highestScene = highest.mapToItem(root, 0, 0).y
            const lowestScene = lowest.mapToItem(root, 0, 0).y

            const wobble = [0.85, 1.14, 0.88, 1.12, 0.9, 1.15, 0.87, 1.1,
                            0.92, 1.08, 0.86, 1.13]
            let worstShift = 0
            for (let i = 0; i < wobble.length; ++i) {
                internal.observeRowHeights(dummySpace * wobble[i] * 20, 20)
                waitForRendering(listView)
                compare(highest.height, dummyHeight,
                        "a dummy must not resize on batch " + i)
                worstShift = Math.max(
                            worstShift,
                            Math.abs(highest.mapToItem(root, 0, 0).y - highestScene))
                worstShift = Math.max(
                            worstShift,
                            Math.abs(lowest.mapToItem(root, 0, 0).y - lowestScene))
            }
            compare(internal.dummyRowHeight, dummySpace)
            verify(worstShift <= 1,
                   "nothing on screen may move as batches land, moved "
                   + worstShift.toFixed(1) + "px")
        }

        // The row whose top edge sits closest to the viewport top, and how
        // far from it — the position the view holds content by.
        function rowAtViewportTop(listView) {
            let best = null
            let bestOffset = 0
            let bestDistance = Number.MAX_VALUE
            for (let i = 0; i < listView.count; ++i) {
                const item = listView.itemAtRow(i)
                if (!item || !item.visible || item.height <= 0)
                    continue
                const offset = item.mapToItem(listView, 0, 0).y
                if (Math.abs(offset) < bestDistance) {
                    bestDistance = Math.abs(offset)
                    bestOffset = offset
                    best = item
                }
            }
            return { key: best ? best.rowKey : "", offset: bestOffset }
        }

        // The other half of the span decision (issue 0022 removed the 300-row
        // cap so the scrollbar could be proportionally honest, and it stays
        // removed). A re-latch is rare, but it rescales a placeholder that
        // stands for thousands of rows — hundreds of thousands of pixels of
        // content height at once. That must not reach the viewport: the view
        // holds content by the row at its top edge, so the whole delta is
        // absorbed by the position it re-applies, and the row the user was
        // reading stays where it was.
        function test_aRelatchDoesNotMoveTheRowUnderTheViewportTop() {
            const chat = openDenseChat(4000, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            establishRowHeight(internal)

            // off the newest message, so the view is held by its anchor
            // rather than pinned to the content bottom
            listView.contentY -= 200
            waitForRendering(listView)
            verify(!listView.stickingToNewest,
                   "the view must be off the newest message")

            const base = internal.avgRowHeight
            const beforePlaceholder = internal.topPlaceholderHeight
            const before = rowAtViewportTop(listView)
            verify(!!before.key, "a row must sit at the viewport top")

            // one overwhelming batch of a different shape: a re-latch, the
            // only event that still moves the estimate once it has settled
            internal.observeRowHeights(base * 4 * 512, 512)
            waitForRendering(listView)

            verify(internal.avgRowHeight > base * 2,
                   "the batch must force a re-latch, estimate at "
                   + internal.avgRowHeight + " from " + base)
            verify(internal.topPlaceholderHeight - beforePlaceholder > 100000,
                   "and rescale the placeholder by hundreds of thousands of "
                   + "pixels, moved "
                   + (internal.topPlaceholderHeight - beforePlaceholder).toFixed(0))

            const after = rowAtViewportTop(listView)
            compare(after.key, before.key,
                    "the same row must still be under the viewport top")
            verify(Math.abs(after.offset - before.offset) <= 2,
                   "and at the same offset, moved "
                   + (after.offset - before.offset).toFixed(1) + "px")
        }

        // ---- the backend is told which rows to keep ----

        function test_windowIsPublishedToTheModel() {
            const chat = openDenseChat(600, 600)
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            tryVerify(() => contentModuleMock.messagesModule.lastWindowLast
                            === internal.windowEnd, 5000,
                      "the dense window must be published, last published "
                      + contentModuleMock.messagesModule.lastWindowLast
                      + " window ends at " + internal.windowEnd)
            compare(contentModuleMock.messagesModule.lastWindowFirst,
                    internal.windowStart)
            verify(contentModuleMock.messagesModule.lastWindowMargin > 0)
        }
    }
}
