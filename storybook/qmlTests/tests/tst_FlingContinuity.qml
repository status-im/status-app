import QtQuick
import QtTest

import StatusQ 0.1
import utils

import shared.views.chat

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 Scroll freeze: content geometry never mutates while the
 message view is in motion — window slides, atomic reveals and placeholder
 resizes all wait for rest, so nothing cancels an active flick or jumps the
 scrollbar. Fetches stay free (eager prefetch), and a settle that
 out-scrolled the window teleports through the window-record restore path.
*/
Item {
    id: root

    width: 800
    height: 600

    ChatStores.RootStore { id: rootStoreMock }

    ListModel { id: messagesModel }
    ListModel { id: messagesModelB }

    component ContentModuleMock: QtObject {
        id: moduleMock

        property string mockChatId: "chat-1"
        property var mockModel

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
            readonly property var model: moduleMock.mockModel
            property bool loading: false
            property bool keepUnread: false

            property int loadMoreCalls: 0

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(int messageIndex)

            function getChatId() { return moduleMock.mockChatId }
            function loadMoreMessages() { loadMoreCalls++ }
            function updateKeepUnread(flag) {}
        }

        function getMyChatId() { return moduleMock.mockChatId }
        function amIChatAdmin() { return false }
    }

    ContentModuleMock {
        id: contentModuleMock

        mockChatId: "chat-1"
        mockModel: messagesModel
    }

    ContentModuleMock {
        id: contentModuleMockB

        mockChatId: "chat-2"
        mockModel: messagesModelB
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
            property bool dressHold: false
            property int activeIndex: 0

            readonly property Item activeShell: {
                if (activeIndex === 0)
                    return shellA
                if (activeIndex === 1)
                    return shellB
                return null
            }

            readonly property ChatStores.MessageStore fallbackMessageStore: ChatStores.MessageStore {
                messageModule: null
            }

            ChatContentView {
                id: shellA
                anchors.fill: parent
                visible: harness.activeIndex === 0
                rootStore: rootStoreMock
                chatContentModule: contentModuleMock
                chatId: "chat-1"
                chatType: Constants.chatType.oneToOne
            }

            ChatContentView {
                id: shellB
                anchors.fill: parent
                visible: harness.activeIndex === 1
                rootStore: rootStoreMock
                chatContentModule: contentModuleMockB
                chatId: "chat-2"
                chatType: Constants.chatType.oneToOne
            }

            Item {
                id: parkingHolder
                anchors.fill: parent
                visible: false
            }

            ChatMessagesView {
                parent: harness.activeShell ? harness.activeShell.messagesSlot
                                            : parkingHolder
                anchors.fill: parent

                rowPool: harness.rowPool
                dressHold: harness.dressHold
                rootStore: rootStoreMock
                messageStore: harness.activeShell ? harness.activeShell.messageStore
                                                  : harness.fallbackMessageStore
                chatContentModule: harness.activeShell ? harness.activeShell.chatContentModule
                                                       : null
                chatId: harness.activeShell ? harness.activeShell.chatId : ""
                isOneToOne: true
                usersModel: ListModel {}
                joined: true
            }
        }
    }

    TestCase {
        name: "FlingContinuity"
        when: windowShown

        function cleanup() {
            contentModuleMock.messagesModule.loading = false
            contentModuleMockB.messagesModule.loading = false
            contentModuleMock.messagesModule.loadMoreCalls = 0
            contentModuleMockB.messagesModule.loadMoreCalls = 0
            messagesModel.clear()
            messagesModelB.clear()
        }

        function appendMessage(i, contentType) {
            messagesModel.append(messageRoles("msg-" + i, i, Date.now() - i * 60000, contentType))
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

        function openPooledChat(messageCount, poolIntervalMs) {
            for (let i = 0; i < messageCount; ++i)
                appendMessage(i)

            const pool = createTemporaryObject(poolComp, root,
                                               { backgroundIntervalMs: poolIntervalMs })
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

        // The row whose top currently sits at (or just below) the viewport
        // top: the smallest non-negative viewport offset.
        function rowIndexAtViewportTop(listView) {
            let best = -1
            let bestOffset = Number.MAX_VALUE
            for (let i = 0; i < listView.count; ++i) {
                const off = listView.viewportOffsetToRow(i)
                if (isNaN(off) || off < -2)
                    continue
                if (off < bestOffset) {
                    bestOffset = off
                    best = i
                }
            }
            return best
        }

        function sourceIndexOfRow(listView, internal, i) {
            return internal.windowStart + i
        }

        // ---- Regression gate: repeated flings up through history ----
        // The freeze invariant, observed from the physics side: across six
        // full flings no flick is cancelled, contentY never touches the top
        // clamp, content geometry (height, row positions) never changes
        // mid-motion — and the window still advances, so the freeze does not
        // starve paging.
        function test_flingContinuityAcrossRepeatedFlings() {
            const chat = openPooledChat(800, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            listView.maximumFlickVelocity = 4000
            listView.flickDeceleration = 1500

            listView.contentY = listView.contentHeight - listView.height
            waitForRendering(listView)

            const startWindowEnd = internal.windowEnd

            let flickCancels = 0
            let topTouches = 0
            let contentHeightChanges = 0
            let downwardJumps = 0
            let maxTrackedContentShift = 0
            let maxTrackedScreenJump = 0

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
                let lastScreenY = tracked.y - listView.contentY

                const startCy = listView.contentY
                let travel = 0
                listView.flick(0, 3000)
                // a real fast fling raises the velocity dress gate; offscreen
                // flick() never updates verticalVelocity, so drive it directly
                internal.updateScrollGate(listView.height * 2)
                tryVerify(() => listView.flickingVertically, 1000,
                          "round " + round + " flick must start")

                let lastCy = listView.contentY
                let lastCh = listView.contentHeight
                let lastTickMs = Date.now()
                for (let t = 0; t < 400; ++t) {
                    wait(16)
                    if (!listView.flickingVertically)
                        break
                    const nowMs = Date.now()
                    const cy = listView.contentY
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
                        const sy = tracked.y - cy
                        // one frame of fling motion, at the measured tick
                        // length (offscreen ticks jitter well past 16ms)
                        const naturalMotion = 3000 * (nowMs - lastTickMs) / 1000
                        const excess = Math.abs(sy - lastScreenY) - naturalMotion
                        if (excess > maxTrackedScreenJump)
                            maxTrackedScreenJump = excess
                        lastScreenY = sy
                    }
                    travel = startCy - cy
                    lastCy = cy
                    lastCh = ch
                    lastTickMs = nowMs
                }
                if (travel < 1500 && listView.contentY > 1)
                    flickCancels++

                internal.updateScrollGate(0)
                tryVerify(() => !listView.moving, 5000)
                // mid-history the paging timer keeps nibbling at the window
                // (the pool caps it below viewport + both prefetch margins),
                // so wait for the staged reveal, not for total quiet — the
                // freeze gates every mutation during the next fling anyway
                tryVerify(() => internal.stagedCount === 0, 30000,
                          "round " + round + " settle batch must reveal")
                waitForRendering(listView)
            }

            console.info("[FLING] flickCancels=" + flickCancels
                         + " topTouches=" + topTouches
                         + " contentHeightChanges=" + contentHeightChanges
                         + " downwardJumps=" + downwardJumps
                         + " maxTrackedContentShift=" + maxTrackedContentShift.toFixed(0)
                         + " maxTrackedScreenJumpExcess=" + maxTrackedScreenJump.toFixed(0)
                         + " window " + startWindowEnd + " -> " + internal.windowEnd)

            compare(flickCancels, 0)
            compare(topTouches, 0)
            compare(contentHeightChanges, 0)
            compare(downwardJumps, 0)
            verify(maxTrackedContentShift <= 2,
                   "rows must hold their content position mid-motion, shifted "
                   + maxTrackedContentShift)
            // content shift 0 already proves rows only move with the scroll;
            // the excess over the fling's own per-tick motion is sampling
            // jitter, bounded loosely (baseline reveals jumped rows by
            // hundreds to thousands of px)
            verify(maxTrackedScreenJump <= 150,
                   "a row's screen move per tick must stay within a frame of "
                   + "fling motion, excess " + maxTrackedScreenJump)
            verify(internal.windowEnd > startWindowEnd + 30,
                   "the window must advance across the fling sequence, still at "
                   + internal.windowEnd)
        }

        // ---- Teleport slide: settle at the placeholder's far edge ----
        // A deep-scroll to the very top of the placeholder settles with the
        // window at the oldest loaded row — row-exact at the edge — and the
        // viewport pinned there through the atomic reveal.
        function test_teleportLandsAtOldestLoadedRowAtFarEdge() {
            const chat = openPooledChat(400, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            // park deep inside the placeholder, then let the fling run out
            // against the top clamp: the motion-end settle happens exactly at
            // the placeholder's far edge
            listView.maximumFlickVelocity = 4000
            listView.flickDeceleration = 1500
            listView.contentY = 150
            listView.flick(0, 2000)
            tryVerify(() => listView.moving, 1000)
            tryVerify(() => !listView.moving, 10000)
            verify(listView.contentY <= 1, "the fling must run out at the top clamp")

            tryVerify(() => internal.windowEnd === 399, 5000,
                      "the teleport must land at the oldest loaded row, at "
                      + internal.windowEnd)
            tryVerify(() => internal.stagedCount === 0, 30000,
                      "the teleport batch must reveal")
            // let the at-rest paging tail run its no-op fetch and drop the
            // exhausted top placeholder; the pin must survive that collapse
            wait(600)
            compare(internal.windowEnd, 399)

            const idx = listView.count - 1
            const item = listView.itemAtRow(idx)
            verify(!!item && item.visible, "the oldest loaded row must be shown")
            compare(String(item.messageId), "msg-399")
            const offset = listView.viewportOffsetToRow(idx)
            verify(!isNaN(offset))
            verify(Math.abs(offset) <= 5,
                   "the viewport must stay pinned to the teleport target, offset "
                   + offset)
        }

        // ---- Teleport slide: mid-placeholder settle ----
        // A settle deep inside the placeholder (but short of its far edge)
        // lands within estimate error of depth ÷ avgRowHeight, and the
        // reveal pins the viewport so it does not visibly jump.
        function test_teleportMidPlaceholderLandsWithinEstimate() {
            const chat = openPooledChat(800, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            const avg = internal.avgRowHeight > 0 ? internal.avgRowHeight : 48
            const depthTarget = 90 * avg
            verify(internal.topPlaceholderHeight > depthTarget,
                   "the placeholder must be deeper than the target depth")
            listView.contentY = internal.topPlaceholderHeight - depthTarget
            listView.flick(0, 300)
            tryVerify(() => listView.moving, 1000)

            const windowEndBefore = internal.windowEnd
            const depth = listView.viewportDepthIntoTopPlaceholder()
            verify(depth > 0, "the viewport must sit inside the placeholder")
            const expected = windowEndBefore + Math.round(depth / avg)
            verify(expected < 799 - 30, "the target must stay short of the far edge")
            listView.cancelFlick()
            tryVerify(() => !listView.moving, 5000)

            tryVerify(() => internal.stagedCount === 0, 30000,
                      "the teleport batch must reveal")
            waitForRendering(listView)

            const topIdx = rowIndexAtViewportTop(listView)
            verify(topIdx >= 0, "a row must sit at the viewport top after reveal")
            const landedTop = sourceIndexOfRow(listView, internal, topIdx)
            verify(Math.abs(landedTop - expected) <= 3,
                   "the viewport must be pinned at the estimated row: expected "
                   + expected + ", showing " + landedTop)
        }

        // ---- Assimilation stays free, geometry stays frozen ----
        // History rows arriving mid-motion must not move contentHeight or
        // contentY; the placeholder absorbs them at rest.
        function test_assimilationFrozenWhileMoving() {
            const chat = openPooledChat(300, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            listView.contentY = listView.contentHeight - listView.height
            waitForRendering(listView)

            listView.flick(0, 1200)
            tryVerify(() => listView.moving, 1000)

            const chBefore = listView.contentHeight
            const topBefore = internal.topPlaceholderHeight
            for (let i = 300; i < 360; ++i)
                appendMessage(i)

            let contentHeightChanges = 0
            let downwardJumps = 0
            let lastCy = listView.contentY
            for (let t = 0; t < 400; ++t) {
                wait(16)
                if (!listView.moving)
                    break
                if (Math.abs(listView.contentHeight - chBefore) > 0.5)
                    contentHeightChanges++
                if (listView.contentY - lastCy > 0.5)
                    downwardJumps++
                lastCy = listView.contentY
                compare(internal.topPlaceholderHeight, topBefore)
            }
            compare(contentHeightChanges, 0)
            compare(downwardJumps, 0)

            tryVerify(() => !listView.moving, 10000)
            tryVerify(() => internal.topPlaceholderHeight > topBefore, 5000,
                      "the placeholder must absorb the new history at rest")
        }

        // ---- Eager history prefetch ----
        // Scrolling deep into the placeholder fires loadMoreMessages before
        // the settle, and the in-flight guard blocks repeats until the fetch
        // actually grows the history.
        function test_prefetchFiresDuringPlaceholderScroll() {
            const chat = openPooledChat(60, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            contentModuleMock.messagesModule.loadMoreCalls = 0

            listView.maximumFlickVelocity = 4000
            listView.flickDeceleration = 1500
            listView.contentY = listView.contentHeight - listView.height
            waitForRendering(listView)

            listView.flick(0, 3000)
            tryVerify(() => listView.moving, 1000)

            let firedWhileMoving = false
            for (let t = 0; t < 400; ++t) {
                wait(16)
                if (contentModuleMock.messagesModule.loadMoreCalls > 0) {
                    firedWhileMoving = listView.moving
                    break
                }
                if (!listView.moving)
                    break
            }
            verify(firedWhileMoving,
                   "the fetch must fire while still scrolling, before the settle")
            compare(contentModuleMock.messagesModule.loadMoreCalls, 1)

            // the mock fetch brings nothing: with the history count unchanged
            // no further request may fire — not during the rest of the
            // motion, not at settle, not from the at-rest paging tail
            tryVerify(() => !listView.moving, 10000)
            tryVerify(() => internal.stagedCount === 0, 30000)
            wait(600)
            compare(contentModuleMock.messagesModule.loadMoreCalls, 1)
        }

        // ---- Per-side placeholder heights ----
        // After up-slides the bottom placeholder reflects windowStart — the
        // rows actually below the window — never the top's remaining
        // estimate (the coupled height that caused the slide ping-pong).
        function test_perSidePlaceholderHeights() {
            const chat = openPooledChat(800, 0)
            const listView = chat.listView
            const internal = chat.internal
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            // park the viewport in the upper half of the window rows, then
            // drive up-slides directly until one trades the recent end
            listView.contentY = internal.topPlaceholderHeight + 100
            waitForRendering(listView)
            for (let i = 0; i < 10 && internal.windowStart === 0; ++i) {
                internal.slideWindowToHistory()
                tryVerify(() => internal.stagedCount === 0, 20000,
                          "slide " + i + " must reveal")
            }
            verify(internal.windowStart > 0,
                   "up-slides must start trading the recent end")

            // sampled in one turn: window bounds and the latched heights are
            // kept consistent within an event dispatch
            const windowStart = internal.windowStart
            const windowEnd = internal.windowEnd
            const bottomHeight = internal.bottomPlaceholderHeight
            const topHeight = internal.topPlaceholderHeight
            const avg = internal.avgRowHeight > 0 ? internal.avgRowHeight : 48
            const expectedBottom = Math.max(listView.height,
                                            Math.min(windowStart, 300) * avg)
            fuzzyCompare(bottomHeight, expectedBottom, 1)
            const expectedTop = Math.max(listView.height,
                                         Math.min(800 - 1 - windowEnd, 300) * avg)
            fuzzyCompare(topHeight, expectedTop, 1)
            verify(bottomHeight < topHeight,
                   "the bottom placeholder must not inherit the top's estimate")
        }
    }
}
