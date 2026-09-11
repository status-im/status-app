import QtQuick
import QtTest

import StatusQ 0.1
import utils

import shared.views.chat

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 Dressed-window gate: with a row pool attached, the message
 view's shells stop building content and start acquiring it. In-window ⇔
 holds a pooled item: after warm-up, paging creates zero MessageViews; the
 initial fill reveals once, atomically; a live message never waits on a dry
 pool; the window cap follows the pool as it fills.
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

        property int markAllMessagesReadCalls: 0
        function markAllMessagesRead() { markAllMessagesReadCalls++ }

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
            property int fetchCalls: 0

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(string messageId)

            function getChatId() { return moduleMock.mockChatId }
            function loadMoreMessages() { fetchCalls++ }
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

    // Section harness wired as ChatColumnView wires production: per-chat
    // shells plus ONE shared messages view reparented into the active
    // chat's slot; a switch swaps the model bindings, never the view.
    Component {
        id: sectionComp

        Item {
            id: harness

            width: 800
            height: 600

            property DelegatePool rowPool: null
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
        name: "ChatMessagesViewPool"
        when: windowShown

        function cleanup() {
            contentModuleMock.messagesModule.loading = false
            contentModuleMock.messagesModule.fetchCalls = 0
            contentModuleMockB.messagesModule.loading = false
            contentModuleMockB.messagesModule.fetchCalls = 0
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

        // Mounts the chat over a fresh pool and waits until the view shows
        // the newest message with its initial batch revealed.
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

        function visibleRowCount(listView) {
            let n = 0
            for (let k = 0; k < listView.count; ++k) {
                const item = listView.itemAtRow(k)
                if (item && item.visible && item.height > 0)
                    ++n
            }
            return n
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

        // Items the pool has built so far: every one is either dressed on a
        // shell of this window or parked ready — the pool alone creates, so
        // this is the MessageView census.
        function builtCount(chat) {
            return chat.internal.acquiredCount + chat.kind.readyCount
        }

        // Waits until the pool has nothing left to build: every built item is
        // either dressed on a shell or parked ready.
        function waitForFullPool(chat) {
            tryVerify(() => builtCount(chat) >= chat.kind.target, 60000,
                      "the pool must reach its target, built "
                      + builtCount(chat) + " of " + chat.kind.target
                      + " (acquired " + chat.internal.acquiredCount
                      + " ready " + chat.kind.readyCount
                      + " boosted " + chat.pool.boosted
                      + " staged " + chat.internal.stagedCount
                      + " initial " + chat.internal.initialFillActive
                      + " win " + chat.internal.windowStart + ".." + chat.internal.windowEnd
                      + " count " + chat.listView.count
                      + " starved " + chat.internal.starvedCount
                      + " moreUp " + chat.listView.moreUpAvailable + ")")
        }

        // The heart of the issue: after warm-up, paging through history and
        // back creates ZERO MessageView instances — only shells churn, the
        // content is acquired and rebound.
        function test_pagingCreatesNoMessageViewsAfterWarmup() {
            const chat = openPooledChat(300, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            // the paging timer is an independent mover of the same window; the
            // slides are driven through the seam from here on
            chat.listView.moreUpAvailable = false
            chat.listView.moreDownAvailable = false
            waitForQuietWindow(chat)

            const built = builtCount(chat)
            const starved = chat.internal.starvedCount
            verify(built > 0, "the pool must have built the row items")

            // every real message row is dressed from the pool, none inline
            for (let k = 0; k < chat.listView.count; ++k)
                verify(chat.listView.itemAtRow(k).pooled,
                       "row " + k + " must hold a pooled item")

            for (let i = 0; i < 4; ++i) {
                const endBefore = chat.internal.windowEnd
                chat.internal.slideWindowToHistory()
                tryVerify(() => chat.internal.windowEnd > endBefore, 5000,
                          "the slide must move the window into history")
                waitForQuietWindow(chat)
            }
            for (let i = 0; i < 2; ++i) {
                const startBefore = chat.internal.windowStart
                chat.internal.slideWindowToRecent()
                tryVerify(() => chat.internal.windowStart < startBefore, 5000,
                          "the slide must move the window back")
                waitForQuietWindow(chat)
            }

            compare(builtCount(chat), built,
                    "paging must not create message views")
            compare(chat.internal.starvedCount, starved,
                    "a warm slide must never find the pool dry "
                    + "(release-before-acquire broke)")
        }

        // Release-before-acquire, observed on the pool itself: sliding a
        // window that exhausts the pool must push items back before taking
        // any — from a dry pool the first availability change can only be a
        // release.
        function test_slideReleasesBeforeAcquiring() {
            const chat = openPooledChat(300, 0)
            waitForFullPool(chat)

            chat.listView.moreUpAvailable = false
            chat.listView.moreDownAvailable = false
            waitForQuietWindow(chat)

            // drain the pool into the window so the slide starts dry
            for (let i = 0; i < 10 && chat.kind.readyCount > 0; ++i) {
                chat.internal.slideWindowToHistory()
                waitForQuietWindow(chat)
            }
            compare(chat.kind.readyCount, 0, "the window must absorb the whole pool")

            const spy = createTemporaryObject(signalSpyComp, root,
                                              { target: chat.pool,
                                                signalName: "availabilityChanged" })
            verify(spy.valid)

            chat.internal.slideWindowToHistory()
            verify(spy.count > 0, "the slide must move items through the pool")
            compare(spy.signalArguments[0][1], 1,
                    "the first pool transition of a dry slide must be a release")

            waitForQuietWindow(chat)
            compare(chat.kind.readyCount, 0)
        }

        Component {
            id: signalSpyComp

            SignalSpy {}
        }

        // First open: the skeleton holds while the pool dresses the opening
        // window, then one atomic reveal — never a partially-dressed screen.
        function test_initialFillRevealsAtomically() {
            for (let i = 0; i < 200; ++i)
                appendMessage(i)

            const pool = createTemporaryObject(poolComp, root,
                                               { backgroundIntervalMs: 400 })
            verify(!!pool)
            const view = createTemporaryObject(sectionComp, root, { rowPool: pool })
            verify(!!view)

            const listView = findChild(view, "chatLogView")
            verify(!!listView)
            const internal = findChild(view, "chatMessagesViewInternal")
            verify(!!internal)

            // sample the visible-row count through the whole fill: it must
            // stay at zero until it jumps to a viewport-worth in one step
            let firstVisible = -1
            for (let i = 0; i < 4000 && firstVisible < 0; ++i) {
                const now = visibleRowCount(listView)
                if (now > 0)
                    firstVisible = now
                else
                    wait(4)
            }
            verify(firstVisible > 0, "the initial fill must reveal")
            verify(firstVisible >= internal.initialRevealTarget,
                   "the reveal must be atomic and viewport-sized: first "
                   + "visible count was " + firstVisible + ", expected at least "
                   + internal.initialRevealTarget)
            verify(!internal.initialFillActive)
        }

        // A live message arriving with the pool dry shows immediately: the
        // window's far end hands over its item — nothing waits on a build.
        function test_liveMessageWithDryPoolShowsImmediately() {
            // a short chat over a frozen pool: the boosted initial fill
            // builds exactly the dressed rows, then the pool goes dry
            const chat = openPooledChat(10, 600000)
            waitForQuietWindow(chat)
            drainPool(chat)
            compare(chat.kind.readyCount, 0, "precondition: the pool is dry")

            const oldestBefore = chat.listView.itemAtRow(chat.listView.count - 1).messageId
            const countBefore = chat.listView.count

            insertNewest(1)

            tryVerify(() => {
                const newest = chat.listView.itemAtRow(0)
                return !!newest && newest.visible && newest.height > 0
                        && newest.messageId === "msg-new-1"
            }, 5000, "the live message must show without waiting on the pool")

            tryVerify(() => chat.listView.itemAtRow(chat.listView.count - 1).messageId
                            !== oldestBefore, 5000,
                      "the far-end row must hand its item to the live message")
            tryCompare(chat.listView, "count", countBefore, 5000)
        }

        // Parks any leftover ready items out of reach so a dry-pool scenario
        // is exact; the frozen background pace keeps it dry.
        property var drained: []

        function drainPool(chat) {
            let item = null
            while ((item = chat.pool.acquire("message")))
                drained.push(item)
        }

        // The explicit far-end trim: when the window bounds have slack (no
        // row gets evicted by the index shift), the dry-pool live message
        // trims the far end by one to free its item.
        function test_liveMessageTrimsSlackWindow() {
            const chat = openPooledChat(10, 600000)
            waitForQuietWindow(chat)
            drainPool(chat)
            compare(chat.kind.readyCount, 0, "precondition: the pool is dry")

            // bounds beyond the occupied rows: an insert now evicts nothing
            const occupiedEnd = chat.internal.windowEnd
            chat.internal.windowEnd = occupiedEnd + 5

            const countBefore = chat.listView.count
            insertNewest(2)

            tryVerify(() => {
                const newest = chat.listView.itemAtRow(0)
                return !!newest && newest.visible && newest.height > 0
                        && newest.messageId === "msg-new-2"
            }, 5000, "the live message must show without waiting on the pool")
            tryVerify(() => chat.internal.windowEnd <= occupiedEnd, 5000,
                      "the far end must be trimmed to free an item, windowEnd="
                      + chat.internal.windowEnd)
            tryCompare(chat.listView, "count", countBefore, 5000)
        }

        // The dressed-window invariant while the pool fills: the window opens
        // narrow, widens with the pool, and at no instant holds more rows
        // than the pool has built.
        function test_windowCapFollowsPoolFill() {
            // moderate background pace: the pool keeps building on its own
            // while the window widens after it; the invariant is checked at
            // every sample on the way to a full pool. No gradualness gate —
            // the demand boost is allowed to compress the fill.
            const chat = openPooledChat(300, 200)

            const opening = chat.listView.count
            verify(opening > 0)
            const deadline = Date.now() + 60000
            while (Date.now() < deadline && builtCount(chat) < chat.kind.target) {
                verify(chat.listView.count <= Math.max(1, builtCount(chat)),
                       "the window held more rows than the pool has built: "
                       + chat.listView.count + " > " + builtCount(chat)
                       + " (acquired " + chat.internal.acquiredCount
                       + " ready " + chat.kind.readyCount
                       + " win " + chat.internal.windowStart + ".." + chat.internal.windowEnd
                       + " staged " + chat.internal.stagedCount
                       + " starved " + chat.internal.starvedCount + ")")
                wait(50)
            }
            waitForFullPool(chat)

            tryVerify(() => chat.listView.count > opening, 30000,
                      "the window must widen as the pool fills")
            verify(chat.listView.count <= Math.max(1, builtCount(chat)))
        }

        // Chat switch: the shared view swaps models — the old
        // window's items return to the pool and the new chat's rows
        // re-acquire them. Nothing is created, nothing leaks: the built
        // census is identical after every switch, in both directions.
        function test_chatSwitchReusesPooledItems() {
            for (let i = 0; i < 200; ++i)
                appendMessageB(i)
            const chat = openPooledChat(200, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)
            const built = builtCount(chat)

            chat.view.activeIndex = 1
            tryVerify(() => chat.listView.count > 0
                            && String(chat.listView.itemAtRow(0).messageId).startsWith("b-"),
                      20000, "the shared view must show the new chat's rows")
            waitForQuietWindow(chat)

            for (let k = 0; k < chat.listView.count; ++k)
                verify(chat.listView.itemAtRow(k).pooled,
                       "row " + k + " must hold a pooled item after the switch")
            tryVerify(() => builtCount(chat) === built, 10000,
                      "the switch must reuse the pool: built " + builtCount(chat)
                      + " vs " + built + " before it")

            chat.view.activeIndex = 0
            tryVerify(() => chat.listView.count > 0
                            && String(chat.listView.itemAtRow(0).messageId).startsWith("msg-"),
                      20000, "switching back must show the first chat again")
            waitForQuietWindow(chat)
            tryVerify(() => builtCount(chat) === built, 10000,
                      "switching back must reuse the pool: built " + builtCount(chat)
                      + " vs " + built + " before it")
        }

        // Switching chats must never paint the previous chat's rows in the
        // new chat, and the new rows enter as one staged batch: the visible
        // count jumps from zero to a viewport-worth in a single step.
        function test_chatSwitchRevealsAtomicallyWithoutOldRows() {
            for (let i = 0; i < 200; ++i)
                appendMessageB(i)
            const chat = openPooledChat(200, 0)
            waitForFullPool(chat)
            waitForQuietWindow(chat)

            chat.view.activeIndex = 1

            // from the swap on, a previous-chat row may never be seen again
            // and the first nonzero visible count is already a full batch
            let firstVisible = -1
            for (let i = 0; i < 4000 && firstVisible < 0; ++i) {
                let visible = 0
                for (let k = 0; k < chat.listView.count; ++k) {
                    const item = chat.listView.itemAtRow(k)
                    if (!item || !item.visible || item.height <= 0)
                        continue
                    verify(String(item.messageId).startsWith("b-"),
                           "a previous-chat row is visible after the switch: "
                           + item.messageId)
                    ++visible
                }
                if (visible > 0)
                    firstVisible = visible
                else
                    wait(4)
            }
            verify(firstVisible > 0, "the switch must reveal the new chat"
                   + " (count " + chat.listView.count
                   + " staged " + chat.internal.stagedCount
                   + " initial " + chat.internal.initialFillActive
                   + " win " + chat.internal.windowStart + ".." + chat.internal.windowEnd
                   + " acquired " + chat.internal.acquiredCount
                   + " ready " + chat.kind.readyCount
                   + " starved " + chat.internal.starvedCount + ")")
            verify(firstVisible >= Math.min(chat.internal.initialRevealTarget,
                                            messagesModelB.count),
                   "the reveal must be atomic and viewport-sized: first visible "
                   + "count was " + firstVisible + ", expected at least "
                   + chat.internal.initialRevealTarget)
        }
    }
}
