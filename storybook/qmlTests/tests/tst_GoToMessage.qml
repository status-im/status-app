import QtQuick
import QtTest

import StatusQ 0.1
import StatusQ.Core.Utils as SQUtils
import utils

import shared.views.chat

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 goTo (issue 0023): the single jump primitive behind a reply-quote click, a
 pinned message, a search hit and the first-unseen landing.

 A loaded target teleports straight to it; an unfetched one fires the
 around-message fetch and teleports when its page lands, skeleton until the
 rows dress. Either way the viewport is pinned to the target CENTRED, which
 is what makes the flickable report a positioned row and run the
 message-found highlight.

 The jump is pinned by MESSAGE ID throughout. The dense model's dummy keys
 are positional (`dummy:<rank>`) and every one of them is renamed by a
 backfill, so anything pinned on a key the model happened to hold at an index
 stops naming a row the moment history grows at the old end.

 As in tst_DenseWindow the middleware is stood in for by a ListModel
 presenting the dense model's contract; test/nim/dense_model_contract_test.nim
 is what keeps the two in step.
*/
Item {
    id: root

    width: 800
    height: 600

    ChatStores.RootStore { id: rootStoreMock }

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

            property int aroundCalls: 0
            property string lastAroundId: ""
            property int rankFetchCalls: 0
            property int indexLookups: 0

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(int messageIndex)
            signal scrollToMessageId(string messageId)
            signal messagesWindowLoaded(string anchorId, int anchorIndex, string error)

            function getChatId() { return moduleMock.mockChatId }
            function loadMoreMessages() {}
            function updateKeepUnread(flag) {}

            // What the real module does on a jump request: the dense build
            // emits the id straight through, no index and no page hunt.
            function jumpToMessage(messageId) { scrollToMessageId(messageId) }

            function loadMessagesAroundMessage(messageId) {
                aroundCalls++
                lastAroundId = messageId
            }
            function loadMessagesAtRank(rank) { rankFetchCalls++ }
            function setDenseWindow(first, last, margin) {}

            // The real view answers this from the dense store's islands - the
            // loaded rows only - so a dummy answers -1. The stub has no island
            // bookkeeping and walks the model instead; only the contract is
            // shared.
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
            readonly property alias messageStore: shellA.messageStore

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

    SignalSpy {
        id: toastSpy
        target: Global
        signalName: "displayToastMessage"
    }

    TestCase {
        name: "GoToMessage"
        when: windowShown

        function cleanup() {
            contentModuleMock.messagesModule.loading = false
            contentModuleMock.messagesModule.aroundCalls = 0
            contentModuleMock.messagesModule.lastAroundId = ""
            contentModuleMock.messagesModule.rankFetchCalls = 0
            contentModuleMock.messagesModule.indexLookups = 0
            toastSpy.clear()
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
        // fetched, everything older is a hole. A dummy's key is positional in
        // the real model, so it is here too: `dummy-<rank>`, rank counted
        // from the oldest end.
        function buildDense(total, loadedCount) {
            denseSource.clear()
            for (let i = 0; i < total; ++i) {
                if (i < loadedCount)
                    denseSource.append(loadedRoles("msg-" + i, "msg-" + i,
                                                   Date.now() - i * 60000, 1))
                else
                    denseSource.append(dummyRoles("dummy-" + (total - 1 - i)))
            }
        }

        // An around-message page arriving: dataChanged in place, never
        // insert/remove, and the filled rows take their message ids.
        function fillPageAround(index, half) {
            const first = Math.max(0, index - half)
            const last = Math.min(denseSource.count - 1, index + half)
            for (let i = first; i <= last; ++i) {
                denseSource.set(i, loadedRoles("msg-" + i, "msg-" + i,
                                               Date.now() - i * 60000, 1))
            }
        }

        // History growing at the OLDEST end. Model indices of everything
        // already there are unchanged, but every rank shifts - so every dummy
        // in the model is renamed, which is exactly what a pin on a dummy key
        // cannot survive.
        function backfillOlder(count) {
            const total = denseSource.count + count
            for (let i = 0; i < count; ++i)
                denseSource.append(dummyRoles("dummy-" + (count - 1 - i)))
            for (let i = 0; i < denseSource.count; ++i) {
                const row = denseSource.get(i)
                if (row.loaded === true)
                    continue
                const renamed = dummyRoles("dummy-" + (total - 1 - i))
                denseSource.set(i, renamed)
            }
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

            const spy = createTemporaryObject(positionRecorderComp, root,
                                              { listView: listView })
            verify(!!spy)

            return { pool: pool, view: view, listView: listView,
                     internal: internal, kind: kind, spy: spy }
        }

        function settle(chat) {
            tryVerify(() => chat.internal.stagedCount === 0, 30000,
                      "staged rows must all reveal")
            waitForRendering(chat.listView)
        }

        // Where the view is, in terms that survive paging: the window keeps
        // sliding mid-history, but the flickable's anchor holds the same
        // message at the same offset while it does. Window bounds are not a
        // usable "did the view move" reference here; this is.
        function topmostVisibleRow(listView) {
            for (let i = listView.count - 1; i >= 0; --i) {
                const item = listView.itemAtRow(i)
                if (!item || !item.visible || item.height <= 0)
                    continue
                const y = item.mapToItem(listView.contentItem, 0, 0).y
                if (y + item.height > listView.contentY)
                    return { key: String(item.rowKey),
                             offset: y - listView.contentY }
            }
            return null
        }

        function builtCount(chat) {
            return chat.internal.acquiredCount + chat.kind.readyCount
        }

        // A half-built pool caps the window so tightly that paging never
        // settles mid-history: it slides older, the viewport ends up at the
        // recent edge, and it slides back.
        function waitForFullPool(chat) {
            tryVerify(() => builtCount(chat) >= chat.kind.target, 60000,
                      "the pool must reach its target, built "
                      + builtCount(chat) + " of " + chat.kind.target)
        }

        // Paging keeps widening the window after an open or a teleport; a
        // test that needs to know no batch is coming has to wait it out.
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

        // The row the viewport was pinned to, by the key of the item the
        // flickable reported positioned. That report is what runs the
        // message-found highlight (onRowPositioned ->
        // startMessageFoundAnimation), so asserting on it asserts the
        // highlight ran on the right row.
        function positionedKey(chat) {
            if (chat.spy.hits === 0)
                return "<none>"
            return chat.spy.keys[chat.spy.keys.length - 1]
        }

        function jump(chat, messageId) {
            // exactly what a reply-quote click and a pinned-message click
            // reach: the store's primitive, nothing view-specific
            chat.view.messageStore.jumpToMessage(messageId)
        }

        // ---- a loaded target: no fetch, straight there ----

        function test_jumpToLoadedRowTeleportsWithoutFetching() {
            const chat = openDenseChat(2000, 400)
            settle(chat)

            jump(chat, "msg-300")

            compare(contentModuleMock.messagesModule.aroundCalls, 0,
                    "a loaded row must not be fetched")
            settle(chat)
            tryVerify(() => chat.spy.hits > 0, 20000,
                      "the target row must be positioned")
            compare(positionedKey(chat), "msg-300")
            verify(chat.internal.windowStart <= 300
                   && chat.internal.windowEnd >= 300,
                   "the window must hold the target, at "
                   + chat.internal.windowStart + ".." + chat.internal.windowEnd)
            verify(chat.internal.windowStart > 0,
                   "the window must have left the newest end")
        }

        // A jump onto the row the window is ALREADY centred on changes no
        // bounds at all: no rows are admitted, no batch is ever staged, and
        // the paging that would eventually produce one is quiet. Nothing but
        // the pin's own application can position the view - which is the
        // point, because a jump that silently does nothing is the failure
        // mode this guards.
        function test_jumpOntoTheWindowsOwnCentrePositionsWithoutABatch() {
            const chat = openDenseChat(2000, 400)
            waitForQuietWindow(chat)

            // the index a teleport would compute the current bounds for:
            // teleportToMessage centres the span it already has
            const internal = chat.internal
            const span = internal.windowEnd - internal.windowStart + 1
            const target = internal.windowEnd - Math.floor(span / 2)
            verify(target >= internal.windowStart && target <= internal.windowEnd)

            const startBefore = internal.windowStart
            const endBefore = internal.windowEnd
            const before = chat.spy.hits

            jump(chat, "msg-" + target)

            compare(contentModuleMock.messagesModule.aroundCalls, 0)
            compare(internal.windowStart, startBefore,
                    "the window must not move for this to prove anything")
            compare(internal.windowEnd, endBefore)
            compare(internal.stagedCount, 0, "nothing may be admitted")

            tryVerify(() => chat.spy.hits > before, 10000,
                      "the pin must land with no batch to ride")
            compare(positionedKey(chat), "msg-" + target)
        }

        // ---- a target in a hole: fetch, fill, teleport, highlight ----

        function test_jumpIntoAHoleFetchesThenTeleports() {
            const chat = openDenseChat(2000, 120)
            settle(chat)

            const before = chat.internal.windowStart
            jump(chat, "msg-1500")

            compare(contentModuleMock.messagesModule.aroundCalls, 1,
                    "an unfetched target must fire the around-message fetch")
            compare(contentModuleMock.messagesModule.lastAroundId, "msg-1500")
            compare(chat.internal.pendingGoToId, "msg-1500")
            compare(chat.internal.windowStart, before,
                    "nothing may move before the page lands")
            compare(chat.spy.hits, 0)

            // the page arrives: applied to the model first, then announced
            fillPageAround(1500, 20)
            contentModuleMock.messagesModule.messagesWindowLoaded(
                        "msg-1500", 1500, "")

            compare(chat.internal.pendingGoToId, "",
                    "the jump must be settled by its own page")
            settle(chat)
            tryVerify(() => chat.spy.hits > 0, 20000,
                      "the target must be positioned once its page dressed")
            compare(positionedKey(chat), "msg-1500")
            verify(chat.internal.windowStart <= 1500
                   && chat.internal.windowEnd >= 1500,
                   "the window must hold the target, at "
                   + chat.internal.windowStart + ".." + chat.internal.windowEnd)
        }

        // ---- the dummy-key trap ----
        // The reported anchor index is whatever the fetch computed, and a
        // backfill landing meanwhile makes it name a different row - here a
        // dummy, whose key the same backfill renames. A jump that pinned on
        // the key at that index would be left naming nothing and fall back to
        // the bottom of the chat.
        function test_jumpPinsOnTheMessageIdNotAShiftingDummyKey() {
            const chat = openDenseChat(2000, 120)
            settle(chat)

            jump(chat, "msg-1500")
            compare(contentModuleMock.messagesModule.aroundCalls, 1)

            fillPageAround(1500, 20)
            // stale by ten rows: the anchor rank was computed before the
            // history grew, and index 1490 is a dummy here
            verify(denseSource.get(1450).loaded !== true,
                   "the stale anchor must land on a dummy for this to bite")
            contentModuleMock.messagesModule.messagesWindowLoaded(
                        "msg-1500", 1450, "")
            // the same turn: every dummy in the model is renamed
            backfillOlder(50)

            settle(chat)
            tryVerify(() => chat.spy.hits > 0, 20000,
                      "the target must still be positioned after the backfill")
            compare(positionedKey(chat), "msg-1500")
            verify(!chat.listView.stickingToNewest,
                   "a lost pin falls back to the newest message - it must not")
        }

        // ---- superseded ----

        function test_supersededJumpIgnoresTheFirstPage() {
            const chat = openDenseChat(2000, 120)
            settle(chat)

            jump(chat, "msg-1500")
            jump(chat, "msg-800")

            compare(contentModuleMock.messagesModule.aroundCalls, 2)
            compare(contentModuleMock.messagesModule.lastAroundId, "msg-800")
            compare(chat.internal.pendingGoToId, "msg-800",
                    "only the newest target is still wanted")

            // the superseded page answers: assimilated by the model, but it
            // moves nothing here
            fillPageAround(1500, 20)
            contentModuleMock.messagesModule.messagesWindowLoaded(
                        "msg-1500", 1500, "")
            compare(chat.internal.pendingGoToId, "msg-800")
            compare(chat.spy.hits, 0,
                    "a superseded page must not position anything")

            fillPageAround(800, 20)
            contentModuleMock.messagesModule.messagesWindowLoaded(
                        "msg-800", 800, "")
            settle(chat)
            tryVerify(() => chat.spy.hits > 0, 20000)
            compare(positionedKey(chat), "msg-800")
        }

        // ---- a jump that cannot land ----

        function test_failedJumpLeavesTheViewInPlace() {
            const chat = openDenseChat(2000, 400)
            waitForFullPool(chat)
            settle(chat)

            // somewhere other than the bottom first: staying put is only an
            // assertion worth making from a position the fallback would
            // change
            const hits0 = chat.spy.hits
            jump(chat, "msg-300")
            tryVerify(() => chat.spy.hits > hits0, 20000)
            settle(chat)
            verify(!chat.listView.stickingToNewest)

            const where = topmostVisibleRow(chat.listView)
            verify(!!where)
            const hitsBefore = chat.spy.hits

            jump(chat, "msg-1500")
            contentModuleMock.messagesModule.messagesWindowLoaded(
                        "msg-1500", -1, "record not found")

            compare(chat.internal.pendingGoToId, "")
            compare(chat.internal.goToFailureCount, 1)
            compare(chat.internal.lastGoToFailure, "msg-1500")
            compare(toastSpy.count, 1, "the user must be told")

            const now = topmostVisibleRow(chat.listView)
            verify(!!now)
            compare(now.key, where.key, "the view must not move")
            verify(Math.abs(now.offset - where.offset) <= 1)
            verify(!chat.listView.stickingToNewest,
                   "a failed jump must not fall back to the bottom")
            compare(chat.spy.hits, hitsBefore, "nothing may be positioned")
        }

        // The page lands clean but the target is not in it: deleted between
        // the click and the fetch. Same graceful stop, no arbitrary landing.
        function test_jumpToADeletedTargetFailsInPlace() {
            const chat = openDenseChat(2000, 400)
            waitForFullPool(chat)
            settle(chat)

            const hits0 = chat.spy.hits
            jump(chat, "msg-300")
            tryVerify(() => chat.spy.hits > hits0, 20000)
            settle(chat)

            const where = topmostVisibleRow(chat.listView)
            verify(!!where)
            const hitsBefore = chat.spy.hits

            jump(chat, "msg-1500")
            // the page around it arrives - without it
            fillPageAround(1490, 5)
            contentModuleMock.messagesModule.messagesWindowLoaded(
                        "msg-1500", 1500, "")

            compare(chat.internal.goToFailureCount, 1)
            compare(chat.internal.lastGoToFailure, "msg-1500")
            const now = topmostVisibleRow(chat.listView)
            verify(!!now)
            compare(now.key, where.key, "the view must not move")
            verify(Math.abs(now.offset - where.offset) <= 1)
            verify(!chat.listView.stickingToNewest)
            compare(chat.spy.hits, hitsBefore)
        }

        // ---- a chat switch cancels ----

        function test_chatSwitchCancelsAJumpInFlight() {
            const chat = openDenseChat(2000, 120)
            settle(chat)

            jump(chat, "msg-1500")
            compare(chat.internal.pendingGoToId, "msg-1500")

            // leaving the section releases the whole window through the same
            // path a chat switch takes
            chat.view.visible = false
            compare(chat.internal.pendingGoToId, "",
                    "a jump must not outlive the chat that asked for it")

            // the page for the abandoned jump answers into the void
            contentModuleMock.messagesModule.messagesWindowLoaded(
                        "msg-1500", 1500, "")
            compare(chat.internal.goToFailureCount, 0)
            compare(chat.spy.hits, 0)
        }

        // ---- the marker landing ----
        // The first-unseen landing arrives on the same signal as every
        // explicit jump, so it inherits the in-session rule: a window record
        // restoring must not be yanked away by it.
        function test_windowRecordBeatsAMarkerJump() {
            const chat = openDenseChat(2000, 400)
            waitForFullPool(chat)
            settle(chat)

            const hits0 = chat.spy.hits
            jump(chat, "msg-300")
            tryVerify(() => chat.spy.hits > hits0, 20000)
            settle(chat)

            chat.view.visible = false
            contentModuleMock.messagesModule.aroundCalls = 0
            chat.view.visible = true
            verify(!!chat.internal.pendingRestore,
                   "the record restore must be in flight for this to bite")

            contentModuleMock.messagesModule.scrollToMessageId("msg-1500")

            compare(contentModuleMock.messagesModule.aroundCalls, 0,
                    "the marker must not outrank the record")
            compare(chat.internal.pendingGoToId, "")
        }

        // ---- the window record's lookup ----
        // Opening a chat with a window record resolves the record's anchor
        // through the model, which answers from its loaded rows. Walking the
        // source from QML instead costs one QVariant round trip per row of
        // the whole history.
        function test_windowRecordLookupGoesThroughTheModel() {
            const chat = openDenseChat(2000, 400)
            settle(chat)

            jump(chat, "msg-300")
            settle(chat)
            tryVerify(() => chat.spy.hits > 0, 20000)

            const before = contentModuleMock.messagesModule.indexLookups
            // leave and come back: the record is captured on the way out and
            // resolved on the way in
            chat.view.visible = false
            contentModuleMock.messagesModule.indexLookups = 0
            chat.view.visible = true
            tryVerify(() => contentModuleMock.messagesModule.indexLookups > 0,
                      20000, "the record must be resolved through the model")
            verify(before >= 0)
        }

        // What openWindow used to pay to resolve a window record's anchor,
        // and what it pays now. The worst case is what matters: an anchor the
        // model no longer holds (a deleted row, a cleared history) walks
        // every row before answering -1, and that is the case openWindow hits
        // on exactly the opens where the record is stale.
        function test_measureRecordLookupCost() {
            const sizes = [10000, 100000]
            const report = []
            for (let s = 0; s < sizes.length; ++s) {
                const rows = sizes[s]
                buildDense(rows, 500)

                // a hit near the newest end - the common case, and cheap
                // either way because the walk stops there
                let t0 = Date.now()
                compare(SQUtils.ModelUtils.indexOf(denseSource, "key", "msg-499"),
                        499)
                const hitMs = Date.now() - t0

                // the full walk: no row answers, so every one is visited
                t0 = Date.now()
                compare(SQUtils.ModelUtils.indexOf(denseSource, "key", "gone"), -1)
                const missMs = Date.now() - t0

                // what the model answers instead: the loaded rows only,
                // whatever the history count
                t0 = Date.now()
                for (let i = 0; i < 100; ++i)
                    contentModuleMock.messagesModule.indexOfMessageId("gone")
                const askMs = (Date.now() - t0) / 100

                report.push(rows + ": walk-hit=" + hitMs + "ms walk-miss="
                            + missMs + "ms stub-lookup=" + askMs + "ms")
            }
            console.info("[GOTO LOOKUP] " + report.join(" | "))
            verify(report.length === sizes.length)
        }
    }

    Component {
        id: positionRecorderComp

        Item {
            id: rec

            visible: false

            property var listView: null
            property var keys: []
            property int hits: 0

            Connections {
                target: rec.listView

                // resolved here and not later: the window keeps paging after
                // a jump, so the same proxy row soon names another message
                function onRowPositioned(row) {
                    const item = rec.listView.itemAtRow(row)
                    const keys = rec.keys
                    keys.push(item ? String(item.rowKey) : "<gone>")
                    rec.keys = keys
                    rec.hits++
                }
            }
        }
    }
}
