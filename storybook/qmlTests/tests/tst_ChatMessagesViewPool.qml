import QtQuick
import QtQuick.Controls
import QtTest
import Storybook.Testing

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ

import SortFilterProxyModel

import utils

import shared.views.chat

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 ChatMessagesView over the app-wide row pool: rows are pooled MessageViews
 pointed at their message by RowBinder, a hidden view hands them all back, a
 chat switch restores where the reader was, and the pool running dry delays
 rows instead of losing them.

 No `pragma ComponentBehavior: Bound` here: the pool builds its delegate with
 no creation context.
*/
Item {
    id: root

    readonly property ChatTextAppearance textAppearance: MessageTextAppearance {
        theme: root.Theme
    }
    readonly property ChatTextAppearance previewAppearance: ReplyTextAppearance {
        theme: root.Theme
    }

    width: 800
    height: 600

    ChatStores.RootStore { id: rootStoreMock }
    AppStateDriver { id: appState }

    ListModel { id: messagesA }
    ListModel { id: messagesB }

    // A chat whose model the backend resets in place, the way entering or
    // leaving a thread refills the same messages model.
    ListModel { id: mainRows }
    ListModel { id: threadRows }
    ListModel { id: refilledRows }

    SortFilterProxyModel {
        id: resettingModel

        sourceModel: mainRows
    }

    component ModuleMock: QtObject {
        id: moduleMock

        property string mockChatId
        property var mockModel

        // rows a history fetch adds at the model's end, oldest last
        property int historyLeft: 0
        property int fetchCalls: 0

        // a fetch answered only on answer(), the way the backend's is
        property bool answerLater: false
        property bool answerOwed: false

        function answer() {
            answerOwed = false
            messagesModule.deliverPage()
        }

        property int markAllMessagesReadCalls: 0
        function markAllMessagesRead() { markAllMessagesReadCalls++ }
        function markMessageRead(id) {}

        readonly property var chatDetails: QtObject {
            readonly property string id: moduleMock.mockChatId
            readonly property int type: Constants.chatType.communityChat
            property bool active: true
            readonly property bool highlight: false
            property bool hasUnreadMessages: false
            readonly property bool canPost: true
            readonly property bool canView: true
            readonly property bool canPostReactions: true
            readonly property string emoji: ""
            readonly property int notificationCount: 0
        }

        readonly property var messagesModule: QtObject {
            readonly property var model: moduleMock.mockModel
            property bool loading: false
            property bool keepUnread: false
            property string threadId: ""

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(int messageIndex)
            signal moreMessagesLoaded()
            signal chatThreadsLoadingFailed()
            signal threadCreationFailed()

            function getChatId() { return moduleMock.mockChatId }
            function updateKeepUnread(flag) {}

            // the messages this chat was asked to stop editing
            property var editModeOffCalls: []
            function setEditModeOff(messageId) { editModeOffCalls.push(messageId) }

            // Like the backend: a page lands at the model's end, then the
            // answer; nothing left answers at once. The chat identifier (the
            // welcome banner) comes last, with the page that reaches the
            // oldest message.
            function loadMoreMessages() {
                moduleMock.fetchCalls++

                if (moduleMock.answerLater)
                    moduleMock.answerOwed = true
                else
                    deliverPage()
            }

            function deliverPage() {
                const model = moduleMock.mockModel
                const count = Math.min(10, moduleMock.historyLeft)
                moduleMock.historyLeft -= count

                const exhausted = moduleMock.historyLeft === 0
                const hasBanner = model.count > 0 && model.get(model.count - 1).contentType
                                === Constants.messageContentType.chatIdentifier

                // the chat reset in place shows a proxy, never paged
                const pageable = typeof model.append === "function"

                if (pageable && (count > 0 || (exhausted && !hasBanner))) {
                    if (hasBanner)
                        model.remove(model.count - 1)

                    const first = model.count
                    for (let i = 0; i < count; ++i)
                        model.append(makeMessage(moduleMock.mockChatId, first + i))

                    if (exhausted)
                        model.append(makeMessage(moduleMock.mockChatId, 9999,
                                                 Constants.messageContentType.chatIdentifier))
                }

                moreMessagesLoaded()
            }
        }

        function getMyChatId() { return mockChatId }
        function amIChatAdmin() { return false }
    }

    ModuleMock { id: moduleA; mockChatId: "a"; mockModel: messagesA }
    ModuleMock { id: moduleB; mockChatId: "b"; mockModel: messagesB }
    ModuleMock { id: moduleT; mockChatId: "t"; mockModel: resettingModel }

    ChatStores.MessageStore { id: storeA; messageModule: moduleA.messagesModule }
    ChatStores.MessageStore { id: storeB; messageModule: moduleB.messagesModule }
    ChatStores.MessageStore { id: storeT; messageModule: moduleT.messagesModule }

    // Row i of a chat, newest first as the backend keeps them. Varied text, so
    // rows differ in height.
    function makeMessage(chat, i, contentType) {
        const ts = 1760000000000 - i * 60000
        const words = []

        for (let w = 0; w < 3 + (i * 7) % 30; ++w)
            words.push("word" + w)

        return {
            id: chat + "-" + i,
            timestamp: ts,
            contentType: contentType ?? Constants.messageContentType.messageType,
            senderId: "0xpeer" + (i % 3),
            senderDisplayName: "Peer " + (i % 3),
            unparsedText: words.join(" "),
            deleted: false,
            prevMsgIndex: i + 1,
            nextMsgIndex: i - 1,
            prevMsgTimestamp: ts - 60000,
            nextMsgTimestamp: ts + 60000,
            prevMsgSenderId: "0xpeer" + ((i + 1) % 3),
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
            quotedMessageAuthorName: "",
            quotedMessageAuthorDisplayName: "",
            quotedMessageAuthorThumbnailImage: "",
            quotedMessageAuthorEnsVerified: false,
            quotedMessageAuthorIsContact: false
        }
    }

    function fill(model, chat, count) {
        model.clear()
        const rows = []
        for (let i = 0; i < count; ++i)
            rows.push(makeMessage(chat, i))
        model.append(rows)
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
        id: signalSpyComp

        SignalSpy {}
    }

    Component {
        id: viewComp

        ChatMessagesView {
            textAppearance: root.textAppearance
            previewAppearance: root.previewAppearance
            width: root.width
            height: root.height

            rootStore: rootStoreMock
            messageStore: storeA
            chatContentModule: moduleA
            chatId: "a"
            usersModel: ListModel {}
            joined: true
        }
    }

    TestCase {
        name: "ChatMessagesViewPool"
        when: windowShown

        property var pool: null

        function init() {
            appState.setActive(true)
            fill(messagesA, "a", 200)
            fill(messagesB, "b", 200)
            moduleA.historyLeft = 0
            moduleA.fetchCalls = 0
            moduleA.answerLater = false
            moduleA.answerOwed = false
            moduleA.messagesModule.loading = false
            moduleB.messagesModule.loading = false
            moduleA.chatDetails.hasUnreadMessages = false
            moduleB.chatDetails.hasUnreadMessages = false
            moduleA.chatDetails.active = true
            moduleA.messagesModule.threadId = ""
            moduleA.messagesModule.keepUnread = false
            moduleA.messagesModule.editModeOffCalls = []
            moduleB.messagesModule.editModeOffCalls = []
        }

        function cleanup() {
            appState.setActive(true)
        }

        function readyCount() {
            return pool.readyCount("message")
        }

        // A pool built up front, the way the app's is built from login on -
        // past any target the view raises it to, so nothing is still being
        // built while a test counts what is ready.
        function prewarmedPool() {
            pool = createTemporaryObject(poolComp, root)
            pool.setTarget("message", 100)
            pool.boost("message", 100)
            tryVerify(() => readyCount() >= 100, 60000, "the pool is built")
            return pool
        }

        function openView(props) {
            const view = createTemporaryObject(viewComp, root,
                                               Object.assign({ rowPool: pool }, props || {}))
            verify(!!view)
            settle(view)
            return view
        }

        function settle(view) {
            tryVerify(() => view.chatLogView.rowCount > 0 && !view.chatLogView.busy, 20000,
                      "the window revealed")
        }

        function rowItems(view) {
            const out = []
            for (let row = 0; row < view.chatLogView.rowCount; ++row) {
                const shell = view.chatLogView.itemAtRow(row)
                if (shell && shell.content)
                    out.push({ shell: shell, content: shell.content })
            }
            return out
        }

        function messageIdAtViewportTop(view) {
            const lv = view.chatLogView
            let best = -1
            let bestOffset = Number.MAX_VALUE

            for (let row = 0; row < lv.rowCount; ++row) {
                const offset = lv.viewportOffsetToRow(row)
                if (!isNaN(offset) && offset >= 0 && offset < bestOffset) {
                    bestOffset = offset
                    best = row
                }
            }

            return best < 0 ? null : { key: lv.keyAtRow(best), offset: bestOffset }
        }

        // Once history has run out, the model keeps changing - new messages,
        // the new-messages marker moved, the chat identifier re-inserted -
        // none of which means older history exists again. The band must stay
        // gone, rather than come back above the chat's very first message.
        function test_aNewMessageDoesNotBringTheHistoryBandBack() {
            prewarmedPool()
            fill(messagesA, "a", 8)
            moduleA.historyLeft = 0

            const view = openView()
            const lv = view.chatLogView

            tryVerify(() => !lv.moreAvailableTop && !lv.busy, 5000, "history ran out")
            const fetches = moduleA.fetchCalls

            messagesA.insert(0, makeMessage("a", -1))
            tryVerify(() => lv.rowForKey("a--1") >= 0 && !lv.busy, 5000, "the new message is shown")

            verify(!lv.moreAvailableTop, "and the band did not come back")
            compare(moduleA.fetchCalls, fetches, "nor was history asked for again")
        }

        // A mailserver history fetch finishing may have put older messages in
        // the database, but only asking tells. The view must ask without
        // raising the band: up front of an answer it would show above the
        // chat's first message - and stay there while the top edge is held.
        function test_aFinishedHistorySyncAsksWithoutRaisingTheBand() {
            prewarmedPool()
            fill(messagesA, "a", 8)
            moduleA.historyLeft = 0

            const view = openView()
            const lv = view.chatLogView

            tryVerify(() => !lv.moreAvailableTop && !lv.busy, 5000, "history ran out")
            const fetches = moduleA.fetchCalls

            // a sync with nothing older behind it
            rootStoreMock.loadingHistoryMessagesInProgress = true
            rootStoreMock.loadingHistoryMessagesInProgress = false

            compare(moduleA.fetchCalls, fetches + 1, "the backend was asked")
            verify(!lv.moreAvailableTop, "and, with nothing more, the band never showed")

            // a sync that did bring older messages
            moduleA.historyLeft = 10
            rootStoreMock.loadingHistoryMessagesInProgress = true
            rootStoreMock.loadingHistoryMessagesInProgress = false

            compare(messagesA.count, 19, "the older page arrived, under the banner")
            tryVerify(() => !lv.busy && lv.rowForKey("a-17") >= 0, 5000,
                      "and is shown, under what was the oldest message")
            verify(!lv.moreAvailableTop, "with no band above the chat's first message")
        }

        // ---- rows from the pool ----------------------------------------------

        function test_rowsComeFromThePool() {
            prewarmedPool()
            const ready = readyCount()

            const view = openView()
            const rows = rowItems(view)

            verify(rows.length > 0)
            compare(readyCount(), ready - rows.length, "every row took a pooled item")

            for (const r of rows) {
                compare(r.content.parent, r.shell, "the item is on screen, in its row")
                compare(r.content.objectName, "chatMessageViewDelegate")
                compare(r.content.textAppearance, root.textAppearance)
                compare(r.content.previewAppearance, root.previewAppearance)
            }

            // the item shows the message of its row
            const first = rows[0]
            compare(first.content.messageId, view.chatLogView.keyAtRow(0))

            // and each row is as tall as its message, so none overlap
            for (const r of rows) {
                verify(r.content.height > 50, "a message row is not the placeholder height")
                compare(r.content.height, r.content.item.implicitHeight)
            }
        }

        function test_aHiddenViewHandsEveryRowBack() {
            prewarmedPool()
            const ready = readyCount()

            const view = openView()
            verify(readyCount() < ready)

            view.visible = false
            tryCompare(view.chatLogView, "rowCount", 0, 5000)
            compare(readyCount(), ready, "every item is back in the pool")

            view.visible = true
            settle(view)
            verify(readyCount() < ready, "shown again, it takes them again")
        }

        function test_rareKindsAreBuiltOnDemand() {
            prewarmedPool()
            messagesA.set(0, { contentType: Constants.messageContentType.chatIdentifier })
            const ready = readyCount()

            const view = openView()
            const rows = rowItems(view)

            compare(readyCount(), ready - (rows.length - 1),
                    "the identifier row took no pooled item")
        }

        function chatTextItems(item, out) {
            out = out || []
            for (const child of item.children) {
                if (typeof child.selectAll === "function" && child.segments !== undefined)
                    out.push(child)
                chatTextItems(child, out)
            }
            return out
        }

        // A row parked and reused for identical text (setSegments returns
        // early then) comes back without the old selection.
        function test_reusedRowWithIdenticalTextKeepsNoSelection() {
            for (let i = 0; i < messagesA.count; ++i)
                messagesA.setProperty(i, "unparsedText", "ok")
            prewarmedPool()
            const view = openView()
            const original = rowItems(view).map(row => row.content)
            for (const content of original)
                for (const text of chatTextItems(content))
                    text.selectAll()
            verify(original.some(content => chatTextItems(content).some(t => t.selectedText === "ok")))

            view.visible = false
            tryCompare(view.chatLogView, "rowCount", 0, 5000)
            view.visible = true
            settle(view)

            const rows = rowItems(view)
            verify(rows.some(row => original.indexOf(row.content) >= 0), "a pooled row was reused")
            for (const row of rows)
                for (const text of chatTextItems(row.content))
                    compare(text.selectedText, "")
        }

        function test_reusedRowsReceiveTheCurrentAppearances() {
            prewarmedPool()
            const view = openView()
            const original = rowItems(view).map(row => row.content)
            view.visible = false
            tryCompare(view.chatLogView, "rowCount", 0, 5000)
            // The app-owned instances remain valid after the view releases its rows.
            for (const item of original) {
                compare(item.textAppearance, root.textAppearance)
                compare(item.previewAppearance, root.previewAppearance)
            }
            view.textAppearance = root.previewAppearance
            view.previewAppearance = root.textAppearance
            view.visible = true
            settle(view)
            const rows = rowItems(view)
            verify(rows.some(row => original.indexOf(row.content) >= 0), "a pooled row was reused")
            for (const row of rows) {
                compare(row.content.textAppearance, root.previewAppearance)
                compare(row.content.previewAppearance, root.textAppearance)
            }
        }

        // Fewer items ready than the window wants: the rows wait for the pool
        // to build more, and are all shown once it has.
        function test_aDryPoolDelaysRowsRatherThanLosingThem() {
            pool = createTemporaryObject(poolComp, root)
            verify(readyCount() === 0, "nothing built yet")

            const view = openView()

            for (const r of rowItems(view))
                compare(r.content.parent, r.shell)

            compare(rowItems(view).length, view.chatLogView.rowCount, "every row has its item")
        }

        // ---- position ---------------------------------------------------------

        function test_aChatSwitchRestoresTheReadingPosition() {
            prewarmedPool()
            const view = openView()
            const lv = view.chatLogView

            // read somewhere above the newest message
            lv.contentY = Math.max(0, lv.contentHeight - lv.height * 2.5)
            waitForRendering(lv, 100)
            const before = messageIdAtViewportTop(view)
            verify(!!before)

            view.messageStore = storeB
            view.chatContentModule = moduleB
            settle(view)
            verify(lv.keyAtRow(0).startsWith("b-"), "chat b is shown")

            view.messageStore = storeA
            view.chatContentModule = moduleA
            settle(view)

            tryVerify(() => {
                const after = messageIdAtViewportTop(view)
                return !!after && after.key === before.key
                        && Math.abs(after.offset - before.offset) < 1
            }, 5000, "back where the reader was in chat a")
        }

        // The model resets in place: the window must not keep bounds that lie
        // past the end of what is there now, and coming back finds the reader
        // where they were.
        function test_aResetInPlaceReopensTheWindow() {
            prewarmedPool()
            fill(mainRows, "t", 200)
            fill(threadRows, "th", 5)
            resettingModel.sourceModel = mainRows
            moduleT.messagesModule.threadId = ""

            const view = openView({ messageStore: storeT, chatContentModule: moduleT, chatId: "t" })
            const lv = view.chatLogView

            moduleT.messagesModule.scrollToMessage(150)
            tryVerify(() => !lv.busy && lv.rowForKey("t-150") >= 0, 10000, "deep in history")
            waitForRendering(lv, 100)
            const before = messageIdAtViewportTop(view)
            verify(!!before)

            // into a thread: five rows, far fewer than the window's start
            moduleT.messagesModule.threadId = "thread-1"
            resettingModel.sourceModel = threadRows

            tryVerify(() => lv.rowCount === 5 && !lv.busy, 10000, "the thread's rows show")
            verify(lv.rowForKey("th-0") >= 0)

            // and back out
            moduleT.messagesModule.threadId = ""
            resettingModel.sourceModel = mainRows

            tryVerify(() => {
                if (lv.busy)
                    return false
                const after = messageIdAtViewportTop(view)
                return !!after && after.key === before.key
                        && Math.abs(after.offset - before.offset) < 1
            }, 10000, "back where the reader was in the chat")
        }

        // Leaving a thread the way the backend does it: the store loads, the
        // model resets empty, the chat's messages arrive, the store is done.
        // The record cannot be found at the reset - it must wait for the rows.
        function test_aResetThatRefillsWhileLoadingStillRestores() {
            prewarmedPool()
            fill(mainRows, "t", 200)
            fill(threadRows, "th", 5)

            // Empty, but with its roles known - like the backend's model. A
            // ListModel that never held a row has none, and its first rows
            // would reset the renaming proxy above it, which the backend's
            // model never does.
            fill(refilledRows, "t", 1)
            refilledRows.clear()

            resettingModel.sourceModel = mainRows
            moduleT.messagesModule.threadId = ""

            const view = openView({ messageStore: storeT, chatContentModule: moduleT, chatId: "t" })
            const lv = view.chatLogView

            moduleT.messagesModule.scrollToMessage(150)
            tryVerify(() => !lv.busy && lv.rowForKey("t-150") >= 0, 10000, "deep in history")
            waitForRendering(lv, 100)
            const before = messageIdAtViewportTop(view)
            verify(!!before)

            moduleT.messagesModule.threadId = "thread-1"
            resettingModel.sourceModel = threadRows
            tryVerify(() => lv.rowCount === 5 && !lv.busy, 10000, "in the thread")

            // out: loading, an empty model, then the rows, then done
            moduleT.messagesModule.loading = true
            moduleT.messagesModule.threadId = ""
            resettingModel.sourceModel = refilledRows
            waitForRendering(lv, 100)       // the re-placement after the reset has run
            fill(refilledRows, "t", 200)
            moduleT.messagesModule.loading = false

            tryVerify(() => {
                if (lv.busy)
                    return false
                const after = messageIdAtViewportTop(view)
                return !!after && after.key === before.key
                        && Math.abs(after.offset - before.offset) < 1
            }, 10000, "back where the reader was in the chat")
        }

        function test_aJumpLandsOnItsTarget() {
            prewarmedPool()
            const view = openView()
            const lv = view.chatLogView

            moduleA.messagesModule.scrollToMessage(150)

            tryVerify(() => {
                if (lv.busy)
                    return false
                const row = lv.rowForKey("a-150")
                if (row < 0)
                    return false
                const offset = lv.viewportOffsetToRow(row)
                return !isNaN(offset) && offset <= 0 && offset > -lv.height
            }, 10000, "message 150 is on screen")

            verify(!view.chatLogView.atBottom || lv.rowForKey("a-0") < 0,
                   "away from the newest messages")
        }

        function test_sendingReturnsToTheNewestMessage() {
            prewarmedPool()
            const view = openView()
            const lv = view.chatLogView

            moduleA.messagesModule.scrollToMessage(150)
            tryVerify(() => !lv.busy && lv.rowForKey("a-150") >= 0, 10000)

            moduleA.messagesModule.messageSuccessfullySent()

            tryVerify(() => !lv.busy && lv.rowForKey("a-0") >= 0 && lv.atBottom, 10000,
                      "the newest message is on screen")
        }

        // ---- reading ----------------------------------------------------------

        // Reads chat a a little above its newest message - closer than half a
        // window, so the window reopens reaching the newest message - and
        // returns the view where it was read.
        function readAboveTheNewestMessage(view) {
            const lv = view.chatLogView

            lv.contentY = Math.max(lv.originY, lv.contentHeight - lv.height * 1.5)
            waitForRendering(lv, 100)
            verify(!lv.atBottom, "reading above the newest message")

            const at = messageIdAtViewportTop(view)
            verify(!!at)
            return at
        }

        function verifyBackAbove(view, at) {
            const lv = view.chatLogView

            tryVerify(() => {
                const now = messageIdAtViewportTop(view)
                return !lv.busy && !!now && now.key === at.key
                        && Math.abs(now.offset - at.offset) < 1
            }, 5000, "back where the reader was")

            verify(!lv.moreAvailableBottom, "with the window reaching the newest message")
            verify(!lv.atBottom, "which is below the reader")
        }

        // Away from a chat read above its newest message, unread messages
        // arrive in it. Back, the reader is where they were, above them: the
        // chat stays unread until they get to the bottom. On the way the view
        // is empty, then revealed at the bottom just before the position is
        // restored - neither is the reader at the newest message.
        function test_comingBackAboveUnreadMessagesLeavesThemUnread() {
            prewarmedPool()
            const view = openView()
            const at = readAboveTheNewestMessage(view)

            view.chatContentModule = moduleB
            view.messageStore = storeB
            settle(view)

            moduleA.chatDetails.hasUnreadMessages = true
            const marked = moduleA.markAllMessagesReadCalls

            // ChatColumnView's order: the module is bound before the store
            view.chatContentModule = moduleA
            view.messageStore = storeA
            settle(view)
            verifyBackAbove(view, at)

            waitForRendering(view.chatLogView, 100)
            compare(moduleA.markAllMessagesReadCalls, marked, "chat a is still unread")
        }

        // The same, the view hidden meanwhile - another section shown - rather
        // than handed another chat.
        function test_showingTheViewAgainAboveUnreadMessagesLeavesThemUnread() {
            prewarmedPool()
            const view = openView()
            const at = readAboveTheNewestMessage(view)

            view.visible = false
            tryCompare(view.chatLogView, "rowCount", 0, 5000)

            moduleA.chatDetails.hasUnreadMessages = true
            const marked = moduleA.markAllMessagesReadCalls

            view.visible = true
            settle(view)
            verifyBackAbove(view, at)

            waitForRendering(view.chatLogView, 100)
            compare(moduleA.markAllMessagesReadCalls, marked, "chat a is still unread")
        }

        // Left at the newest message, the reader comes back to it: what
        // arrived meanwhile is read.
        function test_comingBackToTheNewestMessageReadsWhatArrived() {
            prewarmedPool()
            const view = openView()
            const lv = view.chatLogView
            verify(lv.atBottom, "at the newest message")

            view.chatContentModule = moduleB
            view.messageStore = storeB
            settle(view)

            moduleA.chatDetails.hasUnreadMessages = true
            const marked = moduleA.markAllMessagesReadCalls

            view.chatContentModule = moduleA
            view.messageStore = storeA
            settle(view)

            verify(lv.atBottom, "back at the newest message")
            tryVerify(() => moduleA.markAllMessagesReadCalls > marked, 5000,
                      "chat a is read")
        }

        function test_arrivingUnreadMessages_data() {
            return [
                { tag: "selected-chat", thread: false, active: true, hidden: false, keepUnread: false, read: true },
                { tag: "selected-thread", thread: true, active: true, hidden: false, keepUnread: false, read: true },
                { tag: "thread-panel", thread: true, active: false, hidden: false, keepUnread: false, read: true },
                { tag: "inactive-chat", thread: false, active: false, hidden: false, keepUnread: false, read: false },
                { tag: "hidden-thread", thread: true, active: false, hidden: true, keepUnread: false, read: false },
                { tag: "keep-thread-unread", thread: true, active: false, hidden: false, keepUnread: true, read: false },
                { tag: "thread-reading-history", thread: true, active: false, above: true, read: false },
                { tag: "thread-in-background", thread: true, active: false, background: true, read: false }
            ]
        }

        function test_arrivingUnreadMessages(data) {
            prewarmedPool()
            moduleA.chatDetails.active = data.active
            moduleA.messagesModule.threadId = data.thread ? "thread-a" : ""
            moduleA.messagesModule.keepUnread = !!data.keepUnread
            const view = openView({ isThreadView: data.thread })
            verify(view.chatLogView.atBottom)
            compare(view.messageStore.keepUnread, !!data.keepUnread)

            // The reply is already rendered when its unread summary arrives.
            messagesA.insert(0, makeMessage("a", -1))
            settle(view)
            waitForRendering(view.chatLogView, 100)
            if (data.above)
                readAboveTheNewestMessage(view)
            if (data.background)
                appState.setActive(false)
            view.visible = !data.hidden
            const marked = moduleA.markAllMessagesReadCalls
            moduleA.chatDetails.hasUnreadMessages = true

            if (data.read) {
                tryVerify(() => moduleA.markAllMessagesReadCalls > marked, 3000,
                          "the visible reply must be marked read without scrolling")
            } else {
                // Process the queued read check before asserting no read was requested.
                let readCheckProcessed = false
                Qt.callLater(() => readCheckProcessed = true)
                tryVerify(() => readCheckProcessed)
                compare(moduleA.markAllMessagesReadCalls, marked)
            }
        }

        // ---- editing ----------------------------------------------------------------

        // A message being edited in the chat left stays edited: the edit is
        // the chat input's, which keeps it to come back to. Its row going back
        // to the pool ends nothing, in either chat.
        function test_leavingAChatWhileEditingKeepsTheEdit() {
            prewarmedPool()
            const view = openView()

            const key = view.chatLogView.keyAtRow(0)
            messagesA.setProperty(0, "editMode", true)
            tryVerify(() => rowItems(view).some(r => r.content.messageId === key
                                                      && r.content.editModeOn),
                      5000, "the newest message is being edited")

            view.chatContentModule = moduleB
            view.messageStore = storeB
            settle(view)

            compare(moduleA.messagesModule.editModeOffCalls, [], "chat a ended no edit")
            compare(moduleB.messagesModule.editModeOffCalls, [], "nor did chat b")
            verify(messagesA.get(0).editMode, "the message is still being edited")
        }

        // Back in the chat, the edited message's row shows it marked - but
        // the edit is already the input's: the row must not start it again,
        // which would load the message's text over what was typed.
        function test_aRowComingBackEditedDoesNotStartTheEditAgain() {
            prewarmedPool()
            const view = openView()

            const key = view.chatLogView.keyAtRow(0)
            messagesA.setProperty(0, "editMode", true)
            tryVerify(() => rowItems(view).some(r => r.content.messageId === key
                                                      && r.content.editModeOn), 5000)

            view.chatContentModule = moduleB
            view.messageStore = storeB
            settle(view)

            const spy = createTemporaryObject(signalSpyComp, root,
                                              { target: view, signalName: "editModeChanged" })

            view.chatContentModule = moduleA
            view.messageStore = storeA
            settle(view)

            verify(rowItems(view).some(r => r.content.messageId === key && r.content.editModeOn),
                   "the message shows marked")
            compare(spy.count, 0, "and the edit was not started again")
        }

        // ---- history --------------------------------------------------------------

        // Reading up to the top of what is loaded fetches older history, page
        // by page, until the backend has no more. The band at the top stands
        // for that history while there is some, and goes with the banner: it
        // never stands above the chat's first message.
        function test_pagingFetchesHistoryUntilThereIsNoMore() {
            prewarmedPool()
            fill(messagesA, "a", 20)
            moduleA.historyLeft = 25

            const view = openView()
            const lv = view.chatLogView

            for (let i = 0; i < 40 && moduleA.historyLeft > 0; ++i) {
                verify(lv.moreAvailableTop, "the band stands for the history still to come")
                lv.contentY = lv.originY
                tryVerify(() => !lv.busy, 5000)
                waitForRendering(lv, 100)
            }

            compare(messagesA.count, 46, "every page of history was fetched, then the banner")
            tryVerify(() => !lv.busy, 5000)
            verify(!lv.moreAvailableTop)
            verify(lv.rowForKey("a-44") >= 0, "the oldest message is reachable")
            compare(lv.keyAtRow(lv.rowCount - 1), "a-9999", "with the banner above it")
        }

        // The band's placeholder shows while a page is being fetched, and the
        // page takes its place, above the reader.
        function test_theTopBandLoadsWhileAPageIsFetched() {
            prewarmedPool()
            fill(messagesA, "a", 40)
            moduleA.historyLeft = 200
            moduleA.answerLater = true

            const view = openView()
            const lv = view.chatLogView
            tryVerify(() => !lv.busy, 5000)
            verify(lv.moreAvailableTop)

            // just past the band - one viewport tall - and within its reach
            lv.contentY = lv.originY + lv.height + 100
            const top = messageIdAtViewportTop(view)
            verify(!!top)

            tryVerify(() => moduleA.answerOwed, 5000, "a page was asked for")
            verify(lv.loadingTop, "and the band shows it loading")

            moduleA.answer()
            tryVerify(() => !lv.busy && lv.rowForKey("a-49") >= 0, 5000, "the page arrived")
            const after = messageIdAtViewportTop(view)
            compare(after.key, top.key, "above the reader, who stayed where they were")
            verify(Math.abs(after.offset - top.offset) < 1)
        }

        // A short chat: the first page of older history is requested while the
        // reader is still close to the newest message, closer than the page is
        // tall. It must land above them, not throw them to the newest message.
        function test_theFirstPageOfAShortChatLandsAboveTheReader() {
            prewarmedPool()
            fill(messagesA, "a", 20)
            moduleA.historyLeft = 100
            moduleA.answerLater = true

            const view = openView()
            const lv = view.chatLogView
            tryVerify(() => !lv.busy && lv.atBottom, 5000, "opened at the newest message")
            waitForRendering(lv, 100)

            // scrolled up, the way a wheel does, until the page is asked for
            for (let i = 0; i < 40 && !moduleA.answerOwed; ++i) {
                lv.contentY = Math.max(lv.originY, lv.contentY - 60)
                waitForRendering(lv, 100)
            }
            verify(moduleA.answerOwed, "the first page was asked for")

            const top = messageIdAtViewportTop(view)
            verify(!!top)

            moduleA.answer()
            tryVerify(() => !lv.busy && lv.rowForKey("a-29") >= 0, 5000, "the page arrived")
            waitForRendering(lv, 100)

            verify(!lv.atBottom, "not thrown to the newest message")
            const after = messageIdAtViewportTop(view)
            compare(after.key, top.key, "the reader is still on their message")
            verify(Math.abs(after.offset - top.offset) < 1)
        }

        // Reaching the top fetches pages only until they have filled the reach
        // above the reader, who stays where they were - not a chain of fetches
        // running to the chat's first message.
        function test_reachingTheTopFetchesOnlyWhatIsInReach() {
            prewarmedPool()
            fill(messagesA, "a", 40)
            moduleA.historyLeft = 200

            const view = openView()
            const lv = view.chatLogView
            tryVerify(() => !lv.busy, 5000)
            waitForRendering(lv, 100)

            const fetches = moduleA.fetchCalls
            lv.contentY = lv.originY + lv.height + 100
            const top = messageIdAtViewportTop(view)
            verify(!!top)

            tryVerify(() => moduleA.fetchCalls > fetches && !lv.busy, 5000, "history fetched")
            for (let i = 0; i < 10; ++i)
                waitForRendering(lv, 100)
            const settled = moduleA.fetchCalls
            for (let i = 0; i < 10; ++i)
                waitForRendering(lv, 100)

            compare(moduleA.fetchCalls, settled, "the fetching stopped")
            verify(moduleA.fetchCalls - fetches <= 2, "after a page or two")
            verify(lv.moreAvailableTop, "with history still to come")
            const after = messageIdAtViewportTop(view)
            compare(after.key, top.key, "above the reader, who stayed where they were")
            verify(Math.abs(after.offset - top.offset) < 1)
        }

        // Dragging the scroll bar handle to the top must not fetch on the
        // way: each page would move the content under the handle, and the
        // drag, still at the top, would keep fetching to the chat's start.
        // The release asks, once.
        function test_aHeldScrollBarFetchesOnlyOnRelease() {
            prewarmedPool()
            fill(messagesA, "a", 20)
            moduleA.historyLeft = 100

            const view = openView()
            const lv = view.chatLogView
            tryVerify(() => !lv.busy, 5000)
            waitForRendering(lv, 100)

            const bar = lv.ScrollBar.vertical
            verify(!!bar && bar.visible)
            const x = bar.width / 2
            const fetches = moduleA.fetchCalls

            mousePress(bar, x, bar.height - 4)
            verify(bar.pressed, "the handle is held")

            for (let i = 9; i >= 0; --i) {
                mouseMove(bar, x, bar.height * i / 10)
                waitForRendering(lv, 100)
            }

            compare(moduleA.fetchCalls, fetches, "nothing fetched while the handle is held")

            mouseRelease(bar, x, 0)
            tryVerify(() => moduleA.fetchCalls === fetches + 1, 5000, "the release fetches")
            tryVerify(() => !lv.busy, 5000)
        }
    }
}
