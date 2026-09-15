import QtQuick
import QtTest

import StatusQ 0.1
import utils

import shared.views.chat

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 Queue-only dressing: the paced drain is the ONLY caller of
 doAcquire — no dress trigger (availability signal, reveal, slide, restore,
 live insert) dresses synchronously inside a signal handler — and the drain
 dresses at most one row per slice, viewport-nearest-first, so the skeleton
 clears where the user is looking.
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

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(int messageIndex)

            function getChatId() { return moduleMock.mockChatId }
            function loadMoreMessages() {}
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

    Component {
        id: signalSpyComp

        SignalSpy {}
    }

    // Records the row index of every shell the moment it gets dressed:
    // acquiredCount increments once per doAcquire, after pooledItem is set.
    Component {
        id: dressOrderProbeComp

        Connections {
            id: probe

            property var listView
            property var dressed: ({})
            property var order: []

            // marks currently dressed rows without recording them
            function prime() {
                for (let k = 0; k < probe.listView.count; ++k) {
                    const item = probe.listView.itemAtRow(k)
                    if (item && item.pooledItem)
                        probe.dressed[String(item.messageId)] = true
                }
            }

            function onAcquiredCountChanged() {
                for (let k = 0; k < probe.listView.count; ++k) {
                    const item = probe.listView.itemAtRow(k)
                    if (!item)
                        continue
                    const id = String(item.messageId)
                    if (!item.pooledItem) {
                        // a release fires the same signal: unmark, so the
                        // row's re-dress is recorded
                        delete probe.dressed[id]
                    } else if (!probe.dressed[id]) {
                        probe.dressed[id] = true
                        probe.order.push(k)
                    }
                }
            }
        }
    }

    TestCase {
        name: "PacedDrainOrder"
        when: windowShown

        function cleanup() {
            contentModuleMock.messagesModule.loading = false
            contentModuleMockB.messagesModule.loading = false
            messagesModel.clear()
            messagesModelB.clear()
        }

        function appendMessage(i, contentType) {
            messagesModel.append(messageRoles("msg-" + i, i, Date.now() - i * 60000, contentType))
        }

        function appendMessageB(i, contentType) {
            messagesModelB.append(messageRoles("b-" + i, i, Date.now() - i * 60000, contentType))
        }

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

        // Severs the paging timer so manual window moves and released rows
        // stay where the test put them.
        function severPaging(chat) {
            chat.listView.moreUpAvailable = false
            chat.listView.moreDownAvailable = false
        }

        function topmostVisibleRow(listView) {
            let best = null
            let bestY = Number.MAX_VALUE
            for (let k = 0; k < listView.count; ++k) {
                const item = listView.itemAtRow(k)
                if (!item || !item.visible || item.height <= 0)
                    continue
                const y = item.mapToItem(listView, 0, 0).y
                if (y + item.height <= 0 || y >= listView.height)
                    continue
                if (y < bestY) {
                    bestY = y
                    best = item
                }
            }
            return best ? ({ id: String(best.messageId), y: bestY }) : null
        }

        function scrollMidHistory(chat) {
            severPaging(chat)
            for (let i = 0; i < 20 && chat.internal.windowStart === 0; ++i) {
                chat.internal.slideWindowToHistory()
                waitForQuietWindow(chat)
            }
            verify(chat.internal.windowStart > 0,
                   "the window must slide into history, at "
                   + chat.internal.windowStart + ".." + chat.internal.windowEnd)
            const mid = Math.floor(chat.listView.count / 2)
            const item = chat.listView.itemAtRow(mid)
            verify(!!item)
            chat.listView.contentY += item.mapToItem(chat.listView, 0, 0).y - 10
            waitForQuietWindow(chat)
            verify(!chat.listView.stickingToNewest)
        }

        // A live insert — the one path that used to dress synchronously in
        // the shell's Component.onCompleted — only enqueues: no dress runs in
        // the insert's own event-loop turn, the drain dresses it later.
        function test_liveInsertNeverDressesSynchronously() {
            // short chat over a fast pool: plenty of ready items, so the old
            // synchronous path WOULD have dressed on the spot
            const chat = openPooledChat(10, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            severPaging(chat)
            verify(chat.kind.readyCount > 0,
                   "precondition: the pool must have ready items")

            const spy = createTemporaryObject(signalSpyComp, root,
                                              { target: chat.internal,
                                                signalName: "acquiredCountChanged" })
            verify(spy.valid)

            insertNewest(1)

            const shell = chat.listView.itemAtRow(0)
            verify(!!shell, "the live shell must exist in the insert's turn")
            compare(String(shell.messageId), "msg-new-1")
            compare(spy.count, 0,
                    "no dress may run in the same turn as the insert")
            verify(!shell.pooledItem,
                   "the live shell must not be dressed synchronously")

            tryVerify(() => !!shell.pooledItem, 5000,
                      "the drain must dress the live shell in a later turn")
        }

        // A burst of availability events piles enqueues up, never dresses:
        // each drain slice dresses exactly one row.
        function test_availabilityBurstDressesOnePerSlice() {
            const chat = openPooledChat(30, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            severPaging(chat)

            // three waiting shells and three availability events at once
            const shells = [0, 1, 2].map(k => chat.listView.itemAtRow(k))
            for (let i = 0; i < shells.length; ++i) {
                verify(!!shells[i].pooledItem)
                shells[i].releasePooled()
            }

            const spy = createTemporaryObject(signalSpyComp, root,
                                              { target: chat.internal,
                                                signalName: "acquiredCountChanged" })
            verify(spy.valid)

            for (let i = 0; i < shells.length; ++i)
                chat.internal.enqueueDress(shells[i])
            compare(spy.count, 0,
                    "enqueueing must never dress in the same turn")
            compare(chat.internal.dressQueue.length, 3)

            chat.internal.drainDressQueue()
            compare(spy.count, 1, "one drain slice dresses exactly one row")
            compare(chat.internal.dressQueue.length, 2)

            chat.internal.drainDressQueue()
            compare(spy.count, 2, "one drain slice dresses exactly one row")
            compare(chat.internal.dressQueue.length, 1)

            tryVerify(() => shells.every(s => !!s.pooledItem), 5000,
                      "the scheduled drain must finish the queue")
        }

        // Viewport at the bottom: rows near the bottom (row 0) dress before
        // rows near the top, whatever order they were released or enqueued.
        function test_bottomViewportDressesBottomFirst() {
            const chat = openPooledChat(30, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            severPaging(chat)
            verify(chat.listView.stickingToNewest,
                   "precondition: the view sticks to the newest message")

            const top = chat.listView.count - 1
            verify(top >= 3, "the window must span enough rows")

            const probe = createTemporaryObject(dressOrderProbeComp, root,
                                                { target: chat.internal,
                                                  listView: chat.listView })
            verify(!!probe)
            probe.prime()

            // scrambled release order: two bottom rows, two top rows — the
            // availability cascade re-enqueues them, the drain must sort
            const released = [top - 1, 0, top, 1]
            for (let i = 0; i < released.length; ++i) {
                const shell = chat.listView.itemAtRow(released[i])
                verify(!!shell.pooledItem)
                shell.releasePooled()
            }

            tryVerify(() => probe.order.length === released.length, 10000,
                      "all released rows must re-dress, got "
                      + JSON.stringify(probe.order))
            compare(JSON.stringify(probe.order),
                    JSON.stringify([0, 1, top - 1, top]),
                    "bottom rows must dress before top rows")
        }

        // lets scheduled drain slices and availability cascades run; used
        // for negative assertions (nothing may dress while held)
        function settle() {
            for (let i = 0; i < 10; ++i)
                wait(20)
        }

        // Dress hold: with the hold up, every trigger enqueues
        // but nothing dresses; release drains paced, viewport-nearest-first.
        function test_holdEnqueuesAndReleaseDrainsNearestFirst() {
            const chat = openPooledChat(30, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            severPaging(chat)
            verify(chat.listView.stickingToNewest,
                   "precondition: the view sticks to the newest message")

            const top = chat.listView.count - 1
            verify(top >= 3, "the window must span enough rows")

            const probe = createTemporaryObject(dressOrderProbeComp, root,
                                                { target: chat.internal,
                                                  listView: chat.listView })
            verify(!!probe)
            probe.prime()

            chat.view.dressHold = true

            const released = [top - 1, 0, top, 1]
            for (let i = 0; i < released.length; ++i) {
                const shell = chat.listView.itemAtRow(released[i])
                verify(!!shell.pooledItem)
                shell.releasePooled()
            }

            settle()
            compare(probe.order.length, 0, "held: nothing may dress")
            compare(chat.internal.dressQueue.length, released.length,
                    "held: every trigger must enqueue, once each")

            chat.view.dressHold = false
            tryVerify(() => probe.order.length === released.length, 10000,
                      "release must drain the queue, got "
                      + JSON.stringify(probe.order))
            compare(JSON.stringify(probe.order),
                    JSON.stringify([0, 1, top - 1, top]),
                    "the released drain must dress viewport-nearest-first")
            compare(chat.internal.dressQueue.length, 0)
        }

        // Rapid on-off toggles (interrupted animations) must lose or
        // duplicate nothing and must always end fully drained.
        function test_rapidToggleEndsFullyDrained() {
            const chat = openPooledChat(30, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            severPaging(chat)

            const dressedBefore = chat.internal.acquiredCount
            const probe = createTemporaryObject(dressOrderProbeComp, root,
                                                { target: chat.internal,
                                                  listView: chat.listView })
            verify(!!probe)
            probe.prime()

            chat.view.dressHold = true
            const released = [0, 1, 2, 3]
            for (let i = 0; i < released.length; ++i) {
                const shell = chat.listView.itemAtRow(released[i])
                verify(!!shell.pooledItem)
                shell.releasePooled()
            }

            chat.view.dressHold = false
            chat.view.dressHold = true
            chat.view.dressHold = false
            chat.view.dressHold = true
            compare(chat.internal.dressQueue.length, released.length,
                    "toggling must neither lose nor duplicate queue entries")

            settle()
            compare(probe.order.length, 0, "held: nothing may dress")
            compare(chat.internal.dressQueue.length, released.length)

            chat.view.dressHold = false
            tryVerify(() => probe.order.length === released.length, 10000,
                      "release must drain the queue, got "
                      + JSON.stringify(probe.order))
            tryCompare(chat.internal, "acquiredCount", dressedBefore)
            compare(chat.internal.dressQueue.length, 0)
            for (let k = 0; k < released.length; ++k) {
                verify(!!chat.listView.itemAtRow(released[k]).pooledItem,
                       "row " + released[k] + " must end dressed")
            }
        }

        // A hold raised mid-drain stops the drain after the current slice;
        // release resumes it to completion.
        function test_holdMidDrainStopsAfterCurrentSlice() {
            const chat = openPooledChat(30, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            severPaging(chat)

            const shells = [0, 1, 2].map(k => chat.listView.itemAtRow(k))
            for (let i = 0; i < shells.length; ++i) {
                verify(!!shells[i].pooledItem)
                shells[i].releasePooled()
            }

            const spy = createTemporaryObject(signalSpyComp, root,
                                              { target: chat.internal,
                                                signalName: "acquiredCountChanged" })
            verify(spy.valid)
            compare(chat.internal.dressQueue.length, shells.length)

            chat.internal.drainDressQueue()
            compare(spy.count, 1, "one drain slice dresses exactly one row")
            compare(chat.internal.dressQueue.length, shells.length - 1)

            chat.view.dressHold = true
            settle()
            compare(spy.count, 1,
                    "held mid-drain: no further slice may dress")
            compare(chat.internal.dressQueue.length, shells.length - 1)

            chat.view.dressHold = false
            tryVerify(() => shells.every(s => !!s.pooledItem), 5000,
                      "release must resume the drain to completion")
            compare(chat.internal.dressQueue.length, 0)
        }

        // Scroll gate: fast-fling velocity holds dressing
        // like a panel switch; the queue grows, and the drain resumes by
        // itself once the velocity decays below the exit threshold.
        function test_fastScrollHoldsDressingUntilVelocityDecays() {
            const chat = openPooledChat(30, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            severPaging(chat)

            const probe = createTemporaryObject(dressOrderProbeComp, root,
                                                { target: chat.internal,
                                                  listView: chat.listView })
            verify(!!probe)
            probe.prime()

            const enter = chat.internal.fastScrollEnterVelocity
            const exit = chat.internal.fastScrollExitVelocity
            chat.internal.updateScrollGate(enter * 1.5)
            verify(chat.internal.fastScroll,
                   "fast velocity must raise the gate")

            const released = [0, 1, 2, 3]
            for (let i = 0; i < released.length; ++i) {
                const shell = chat.listView.itemAtRow(released[i])
                verify(!!shell.pooledItem)
                shell.releasePooled()
            }

            settle()
            compare(probe.order.length, 0,
                    "held by velocity: nothing may dress")
            compare(chat.internal.dressQueue.length, released.length)

            // a decaying fling still above the exit threshold keeps holding
            chat.internal.updateScrollGate(exit * 1.2)
            verify(chat.internal.fastScroll)
            // dropping below exit resumes the drain, no explicit release
            chat.internal.updateScrollGate(exit * 0.5)
            verify(!chat.internal.fastScroll)
            tryVerify(() => probe.order.length === released.length, 10000,
                      "the drain must resume on its own, got "
                      + JSON.stringify(probe.order))
            compare(chat.internal.dressQueue.length, 0)
        }

        // Oscillation between the enter and exit thresholds must not thrash
        // the gate: enter only above the high mark, exit only below the low.
        function test_scrollGateHysteresis() {
            const chat = openPooledChat(10, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            const enter = chat.internal.fastScrollEnterVelocity
            const exit = chat.internal.fastScrollExitVelocity
            verify(exit < enter, "exit threshold must sit below enter")
            const between = (enter + exit) / 2

            verify(!chat.internal.fastScroll)
            chat.internal.updateScrollGate(between)
            verify(!chat.internal.fastScroll,
                   "between thresholds: the gate must stay down")
            chat.internal.updateScrollGate(enter * 1.1)
            verify(chat.internal.fastScroll)
            chat.internal.updateScrollGate(between)
            verify(chat.internal.fastScroll,
                   "between thresholds: the gate must stay up")
            chat.internal.updateScrollGate(between)
            verify(chat.internal.fastScroll)
            chat.internal.updateScrollGate(exit * 0.5)
            verify(!chat.internal.fastScroll)
            chat.internal.updateScrollGate(between)
            verify(!chat.internal.fastScroll,
                   "between thresholds: the gate must stay down")
        }

        // The two hold inputs compose: either alone holds the drain, and
        // dressing resumes only when both have cleared.
        function test_holdInputsCompose() {
            const chat = openPooledChat(30, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            severPaging(chat)

            const probe = createTemporaryObject(dressOrderProbeComp, root,
                                                { target: chat.internal,
                                                  listView: chat.listView })
            verify(!!probe)
            probe.prime()

            chat.view.dressHold = true
            chat.internal.updateScrollGate(
                chat.internal.fastScrollEnterVelocity * 2)

            const released = [0, 1, 2]
            for (let i = 0; i < released.length; ++i) {
                const shell = chat.listView.itemAtRow(released[i])
                verify(!!shell.pooledItem)
                shell.releasePooled()
            }

            settle()
            compare(probe.order.length, 0, "both up: nothing may dress")

            chat.view.dressHold = false
            settle()
            compare(probe.order.length, 0,
                    "velocity alone must keep holding")
            compare(chat.internal.dressQueue.length, released.length)

            chat.internal.updateScrollGate(0)
            tryVerify(() => probe.order.length === released.length, 10000,
                      "both cleared: the drain must run, got "
                      + JSON.stringify(probe.order))
            compare(chat.internal.dressQueue.length, 0)
        }

        // A restored mid-history window dresses the rows nearest the restored
        // viewport position first, spreading outward.
        function test_restoreDressesNearestRestoredPositionFirst() {
            const chat = openPooledChat(300, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            scrollMidHistory(chat)
            const expected = topmostVisibleRow(chat.listView)
            verify(!!expected, "a viewport row must exist to record")

            // section flip away: the record is captured, every item released
            chat.view.visible = false
            tryCompare(chat.internal, "acquiredCount", 0)

            const probe = createTemporaryObject(dressOrderProbeComp, root,
                                                { target: chat.internal,
                                                  listView: chat.listView })
            verify(!!probe)

            chat.view.visible = true
            tryVerify(() => probe.order.length > 0
                            && probe.order.length === chat.listView.count, 20000,
                      "the restored window must dress completely, got "
                      + probe.order.length + " of " + chat.listView.count)
            waitForQuietWindow(chat)

            // the restore must still land where the record says
            const actual = topmostVisibleRow(chat.listView)
            verify(!!actual, "the restored view must show rows")
            compare(actual.id, expected.id,
                    "the top-most visible row must be restored")

            // nearest-first: the dress order walks outward from the first
            // dressed row — distances never decrease along the order
            const order = probe.order
            verify(order.length >= 3)
            const ref = order[0]
            for (let i = 1; i < order.length; ++i) {
                verify(Math.abs(order[i] - ref) >= Math.abs(order[i - 1] - ref),
                       "dress order must spread outward from the restored "
                       + "position, got " + JSON.stringify(order))
            }
            // and the reference is the restored viewport, not a window edge
            verify(ref > 0 && ref < chat.listView.count - 1,
                   "the first dressed row must sit inside the window, got "
                   + ref + " of 0.." + (chat.listView.count - 1))
        }
    }
}
