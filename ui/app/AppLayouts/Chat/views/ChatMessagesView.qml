import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups.Dialog

import QtModelsToolkit

import utils
import shared
import shared.views
import shared.panels
import shared.popups
import shared.status
import shared.controls
import shared.views.chat

import AppLayouts.Chat.stores

import "../controls"
import "../panels"

/*
  The messages of a chat, rendered by a WindowedView over a window of the
  messages model.

  It holds rows only while visible - a hidden chat hands every row back - so
  the app-wide row pool serves the view the user is looking at. Hidden, or
  handed another message store, it records where the reader was by message id
  and restores that when the chat is shown again.

  Rows come from the pool and are pointed at their message with RowBinder.
  The messages model is renamed on the way in, so every role carries the name
  of the MessageView property it feeds and the bind is a plain role-by-name
  assign. Kinds the pool does not hold - and deleted messages - are built on
  demand and bound the same way.
*/
Item {
    id: root

    property var chatContentModule

    property RootStore rootStore
    property MessageStore messageStore
    property string channelEmoji
    property var formatBalance

    // The app-wide reservoir of pre-built rows; without one every row is built
    // on demand.
    property DelegatePool rowPool: null

    // Users related data:
    property var usersModel

    // Contacts related data:
    property string myPublicKey

    property var emojiPopup
    property var stickersPopup
    property bool areTestNetworksEnabled

    property string chatId: ""
    property bool stickersLoaded: false
    property alias chatLogView: chatLogView
    property bool isContactBlocked: false
    property bool isChatBlocked: false
    property bool isOneToOne: false
    property bool joined

    property bool sendViaPersonalChatEnabled
    property bool messageLinkSharingEnabled
    property bool threadsFeatureEnabled
    property string disabledTooltipText

    property int extraLeftPadding: 0

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    signal openStickerPackPopup(string stickerPackId)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)
    signal showReplyArea(string messageId, string author)
    signal editModeChanged(bool editModeOn, string messageId)
    signal openThread(string messageId)

    // Unfurling related requests:
    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)

    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    // Contacts related requests:
    signal changeContactNicknameRequest(string pubKey, string nickname, string displayName, bool isEdit)
    signal removeTrustStatusRequest(string pubKey)
    signal dismissContactRequest(string chatId, string contactRequestId)
    signal acceptContactRequest(string chatId, string contactRequestId)

    // Community access related requests:
    signal spectateCommunityRequested(string communityId)

    // Resolves mention pub keys to display names. Reactive to member/contact
    // name changes; "everyone" is built in.
    MentionResolver {
        id: mentionResolver

        enabled: root.visible
        sourceModel: root.usersModel
        nameRole: "preferredDisplayName"
    }

    QtObject {
        id: d

        readonly property var chatDetails: root.chatContentModule && root.chatContentModule.chatDetails || null
        readonly property bool keepUnread: root.messageStore ? root.messageStore.keepUnread : false

        // The newest message is on screen: the viewport rests on the bottom
        // and the window reaches the model's start.
        readonly property bool isMostRecentMessageInViewport:
            chatLogView.atBottom && !messageWindow.moreAvailableStart

        // ---- Window sizing ------------------------------------------------
        //
        // Tall enough that a slide never trims rows the reader sees, nor puts
        // the opposite band back in reach: the viewport plus the prefetch
        // margin on both sides plus a slide, in rows of a short message. Three
        // screens at 40 px a row covers that for the half-screen margin below,
        // and the view holds the opposite edge after a slide if rows run
        // shorter still. A slide grows by a quarter of it.
        readonly property int windowSize: Math.max(40, Math.ceil(chatLogView.height * 3 / 40))
        readonly property int chunk: Math.max(10, Math.ceil(d.windowSize / 4))

        // A slide holds the window and the chunk at once - it grows before it
        // trims - so the pool has to cover both, or rows wait on it.
        readonly property int poolTarget: d.windowSize + d.chunk + 8

        onPoolTargetChanged: d.applyPoolTarget()

        function applyPoolTarget() {
            if (root.rowPool)
                root.rowPool.setTarget(d.poolKind, d.poolTarget)
        }

        // ---- Which chat is attached ----------------------------------------
        //
        // The active chat's messages while the view is visible, nothing
        // otherwise - a hidden view gives every row back to the pool. The store
        // is what identifies the chat - a model alone need not differ between
        // two of them - and its model is read from it at attach time: a
        // separately bound model can still be the previous chat's when the
        // store has already changed.
        readonly property var wantedStore: root.visible && root.messageStore
                                           && root.messageStore.messageModule
                                           ? root.messageStore : null

        onWantedStoreChanged: d.attach(d.wantedStore)

        property var attachedStore: null

        // The chat the attached rows belong to, latched at attach time: by the
        // time a switch is noticed, the store may already describe the next
        // chat.
        property string recordKey: ""

        // Where the reader was in each chat, by message id and never by row
        // number - rows renumber while a chat is not shown. {atBottom: true}
        // or {key, offset}.
        property var records: ({})

        // A recorded position waiting for the fill that brings its rows.
        property var pendingRestore: null

        function recordKeyOf(store) {
            const module = store.messageModule
            const thread = module.threadId
            return module.getChatId() + (thread ? "/" + thread : "")
        }

        function captureRecord() {
            // Nothing revealed yet (a fill still pending, or a restore in
            // flight): the previous record still describes the position.
            if (!d.recordKey || chatLogView.rowCount === 0 || chatLogView.initialLoading
                    || d.pendingRestore)
                return

            if (d.isMostRecentMessageInViewport) {
                d.records[d.recordKey] = ({ atBottom: true })
                return
            }

            // The row the viewport top falls inside: the reading position.
            let best = -1
            let bestOffset = Number.MAX_VALUE

            for (let row = 0; row < chatLogView.rowCount; ++row) {
                const offset = chatLogView.viewportOffsetToRow(row)

                if (!isNaN(offset) && offset >= 0 && offset < bestOffset) {
                    bestOffset = offset
                    best = row
                }
            }

            if (best < 0)
                return

            d.records[d.recordKey] = ({ key: chatLogView.keyAtRow(best), offset: bestOffset })
        }

        // Set while attach() swaps the source, so the resets that causes are
        // not mistaken for the backend resetting the model.
        property bool attaching: false

        function attach(store) {
            const model = store ? store.messagesModel : null

            if (d.attachedStore === store && renamedMessages.sourceModel === model)
                return

            d.captureRecord()
            d.closeLoadingBatch()
            d.forgetRequests()

            // Every row goes back first, so the window can be placed before
            // the next chat's rows arrive - they then come in one fill, at the
            // place they are wanted, instead of being built and moved.
            d.attaching = true
            renamedMessages.sourceModel = null
            d.attachedStore = store

            if (!store || !model) {
                d.recordKey = ""
                d.attaching = false
                return
            }

            d.recordKey = d.recordKeyOf(store)
            messageWindow.moveTo(d.openingStart(model, store))
            renamedMessages.sourceModel = model
            d.attaching = false

            if (store.loading)
                d.openLoadingBatch()

            // A chat opened cold - already active, already unread - gets no
            // change to react to; what it shows now is what decides.
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        function forgetRequests() {
            d.closeFetchBatch()
            d.fetchPending = false
            d.fetchForRequest = false
            d.jumpKey = ""
            d.toNewest = false
            d.pendingRestore = null
            d.deferredRecord = null
            d.historyMayHaveMore = true
        }

        // A record whose message is not in the model yet because the store is
        // still loading it - leaving a thread empties the model and refills it
        // afterwards. Resolved as the loading batch closes.
        property var deferredRecord: null

        // Where the window opens on `model` for the chat in recordKey: around
        // its recorded position, or at the newest message.
        function openingStart(model, store) {
            const record = d.records[d.recordKey]

            if (!record || record.atBottom)
                return 0

            const start = d.startAround(model, record)

            if (start >= 0)
                return start

            if (store.loading)
                d.deferredRecord = record
            else if (model.rowCount() > 0)
                delete d.records[d.recordKey]   // the message is gone

            return 0
        }

        // The window start that centres the record's message, or -1 when the
        // model does not hold it; marks the record as the one to restore.
        function startAround(model, record) {
            const index = SQUtils.ModelUtils.indexOf(model, "id", record.key)

            if (index < 0)
                return -1

            d.pendingRestore = record
            return Math.max(0, index - Math.floor(d.windowSize / 2))
        }

        // Inside the still-open loading batch, so the restored window comes in
        // the same reveal as the rows that just arrived.
        function resolveDeferredRecord() {
            const record = d.deferredRecord
            d.deferredRecord = null

            if (!record || !renamedMessages.sourceModel)
                return

            const start = d.startAround(renamedMessages.sourceModel, record)

            if (start >= 0)
                messageWindow.moveTo(start)
        }

        // The backend reset the attached model itself - entering or leaving a
        // thread refills the same model, and so does clearing the history. The
        // window still has the previous contents' bounds, which may lie past
        // the end of what is there now. Run a turn after the reset: moving the
        // window from inside it would hand the view row changes before the
        // reset itself.
        function reopenAfterReset() {
            if (!d.attachedStore || !renamedMessages.sourceModel)
                return

            d.forgetRequests()
            d.recordKey = d.recordKeyOf(d.attachedStore)
            messageWindow.moveTo(d.openingStart(renamedMessages.sourceModel, d.attachedStore))
        }

        // ---- The store loading ----------------------------------------------
        //
        // While the store loads - the first page, or the pages a search jump
        // walks through - whatever arrives is one batch, revealed once it is
        // done.
        property bool loadingBatch: false

        function openLoadingBatch() {
            if (d.loadingBatch)
                return

            d.loadingBatch = true
            chatLogView.beginBatch()
        }

        function closeLoadingBatch() {
            if (!d.loadingBatch)
                return

            d.resolveDeferredRecord()
            d.loadingBatch = false
            chatLogView.endBatch()
        }

        // ---- Paging -----------------------------------------------------------
        //
        // The top of the screen is the model's end - older messages - and the
        // bottom its start. The view's bands stand for rows the model holds
        // beyond the window, and its requests only ever grow the window.
        //
        // Older history the backend still holds is part of the top band too,
        // so its placeholder shows while a page is fetched: a request at the
        // top with the window at the model's end asks the backend, and the
        // page - arriving at the model's end, above what is shown - is the
        // answer. The chat identifier, the welcome banner, comes with the
        // page that reaches the oldest message, and ends the band: nothing is
        // ever shown above it.
        readonly property bool olderHistoryMayExist:
            !!renamedMessages.sourceModel && !d.historyEnded && d.historyMayHaveMore
            && !!root.messageStore && !root.messageStore.loading

        // The chat identifier is the model's last row.
        property bool historyEnded: false

        function updateHistoryEnded() {
            const count = renamedMessages.rowCount()

            d.historyEnded = count > 0
                    && SQUtils.ModelUtils.get(renamedMessages, count - 1, "messageContentType")
                       === Constants.messageContentType.chatIdentifier
        }

        property bool fetchPending: false
        property bool fetchForRequest: false
        property bool fetchOwnsBatch: false
        property int countAtFetch: 0

        // Cleared by a fetch that brought nothing - a backend that answers
        // without the banner must not be asked for ever - and set again by a
        // mailserver history fetch finishing, which can put older messages in
        // the database without loading them.
        property bool historyMayHaveMore: true

        function messagesCount() {
            const model = renamedMessages.sourceModel
            return model ? model.rowCount() : 0
        }

        function fetchMore(edge) {
            if (edge === WindowedView.Edge.Bottom) {
                messageWindow.growStart(d.chunk)
            } else if (messageWindow.moreAvailableEnd) {
                messageWindow.growEnd(d.chunk)
            } else if (!d.fetchPending && d.olderHistoryMayExist) {
                d.fetchHistory(true)    // answered by fetchAnswered()
                return
            }

            chatLogView.moreLoaded(edge)
        }

        // After a mailserver history fetch, with the banner already shown:
        // there is no band to ask through, so ask once directly, as a batch.
        function fetchHistoryAfterSync() {
            if (!d.historyEnded || d.fetchPending || chatLogView.busy
                    || !renamedMessages.sourceModel || root.messageStore.loading
                    || messageWindow.moreAvailableEnd)
                return

            d.fetchOwnsBatch = !d.loadingBatch

            if (d.fetchOwnsBatch)
                chatLogView.beginBatch()

            d.fetchHistory(false)
        }

        function fetchHistory(forRequest) {
            d.fetchPending = true
            d.fetchForRequest = forRequest
            d.countAtFetch = d.messagesCount()

            // may answer synchronously, when there is nothing left to fetch
            root.messageStore.loadMoreMessages()
        }

        function fetchAnswered() {
            if (!d.fetchPending)
                return

            const added = d.messagesCount() - d.countAtFetch
            const forRequest = d.fetchForRequest

            d.fetchPending = false
            d.fetchForRequest = false
            d.historyMayHaveMore = added > 0

            // The page went in at the model's end, past the window's. Admitted
            // in the same turn, as the answer; the far end gives rows back at
            // the reveal.
            if (added > 0)
                messageWindow.growEnd(added)

            if (forRequest)
                chatLogView.moreLoaded(WindowedView.Edge.Top)

            d.closeFetchBatch()
        }

        function closeFetchBatch() {
            if (!d.fetchOwnsBatch)
                return

            d.fetchOwnsBatch = false
            chatLogView.endBatch()
        }

        // ---- Jumps --------------------------------------------------------------
        //
        // A key, never a row number: moving the window renumbers every row. The
        // row is positioned inside the reveal of the batch that brings it, so
        // it appears already in place.
        property string jumpKey: ""
        property bool toNewest: false

        function moveWindowAsBatch(move) {
            const own = !d.loadingBatch

            if (own)
                chatLogView.beginBatch()

            move()

            if (own)
                chatLogView.endBatch()
        }

        function goToMessage(messageIndex) {
            const key = SQUtils.ModelUtils.get(root.messageStore.messagesModel, messageIndex, "id")

            if (key === undefined || key === null || key === "")
                return

            d.toNewest = false
            d.jumpKey = key

            if (chatLogView.rowForKey(key) < 0)
                d.moveWindowAsBatch(() => messageWindow.moveToKey(key))

            // The window already held it, or moving it changed no rows: there
            // is no batch to complete the jump in.
            if (!chatLogView.busy)
                d.applyJump()
        }

        function applyJump() {
            if (!d.jumpKey)
                return

            const row = chatLogView.rowForKey(d.jumpKey)
            d.jumpKey = ""

            if (row >= 0)
                chatLogView.positionViewAtRow(row, WindowedView.PositionMode.Center)
        }

        function scrollToBottom() {
            d.jumpKey = ""
            d.pendingRestore = null

            if (messageWindow.moreAvailableStart) {
                d.toNewest = true
                d.moveWindowAsBatch(() => messageWindow.moveTo(0))
            }

            if (!chatLogView.busy) {
                d.toNewest = false
                chatLogView.positionViewAtBeginning()
            }

            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        function onRevealed() {
            messageWindow.trim()

            // whatever this reveal positions, it runs before the check below
            Qt.callLater(d.markAllMessagesReadIfMostRecentMessageIsInViewport)

            if (d.pendingRestore) {
                const restore = d.pendingRestore
                const row = chatLogView.rowForKey(restore.key)

                d.pendingRestore = null

                if (row >= 0)
                    chatLogView.positionViewAtRowOffset(row, restore.offset)
            }

            if (d.toNewest) {
                d.toNewest = false
                chatLogView.positionViewAtBeginning()
            }

            d.applyJump()
        }

        // ---- Rows -----------------------------------------------------------------
        readonly property string poolKind: "message"

        // Every real message content type resolves to MessageView's one inner
        // message component, so one pooled kind covers them all; the rest are
        // rare by construction and built on demand.
        function isPooledContentType(contentType) {
            switch (contentType) {
            case Constants.messageContentType.messageType:
            case Constants.messageContentType.stickerType:
            case Constants.messageContentType.emojiType:
            case Constants.messageContentType.transactionType:
            case Constants.messageContentType.imageType:
            case Constants.messageContentType.audioType:
            case Constants.messageContentType.communityInviteType:
            case Constants.messageContentType.discordMessageType:
            case Constants.messageContentType.contactRequestType:
            case Constants.messageContentType.bridgeMessageType:
                return true
            default:
                return false
            }
        }

        // Per row item: its RowBinder (kept for a pooled item's whole life) and
        // the relay of its intents (only while it is dressed).
        property var binders: new Map()
        property var relays: new Map()
        property var pooledItems: new Set()

        // Rows that asked while the pool was dry, answered as items come back
        // or get built.
        property var starved: []
        property bool serving: false

        // What a row needs beyond its own message: the per-chat context the
        // inline delegate used to bind. Bound while dressed - several change
        // live - and broken again at release, so nothing in the app-wide pool
        // keeps reaching back into this view.
        readonly property var context: [
            "rootStore", "messageStore", "channelEmoji", "emojiPopup", "stickersPopup",
            "chatLogView", "chatContentModule", "formatBalance", "usersModel",
            "isChatBlocked", "joined", "sendViaPersonalChatEnabled",
            "messageLinkSharingEnabled", "threadsFeatureEnabled", "disabledTooltipText",
            "areTestNetworksEnabled", "extraLeftPadding", "gifUnfurlingEnabled",
            "neverAskAboutUnfurlingAgain", "myPublicKey", "stickersLoaded"
        ]

        function acquireRow(parent, row, modelRow, cb) {
            const pooled = !!root.rowPool && !modelRow.deleted
                           && d.isPooledContentType(modelRow.messageContentType)

            if (!pooled) {
                d.dress(messageViewComponent.createObject(null), parent, row, cb)
                return
            }

            const item = root.rowPool.acquire(d.poolKind)

            if (item) {
                d.pooledItems.add(item)
                d.dress(item, parent, row, cb)
                return
            }

            d.starved.push({ parent: parent, cb: cb })
            root.rowPool.boost(d.poolKind, d.starved.length)
        }

        function serveStarved() {
            if (d.serving || !root.rowPool)
                return

            d.serving = true

            while (d.starved.length > 0) {
                const waiting = d.starved[0]

                // The row left the window while it waited: the view no
                // longer wants it, so it takes no item.
                if (!waiting.parent || waiting.parent.retired) {
                    d.starved.shift()
                    continue
                }

                const item = root.rowPool.acquire(d.poolKind)

                if (!item)
                    break

                d.starved.shift()
                d.pooledItems.add(item)
                // the row number is read now: the window may have moved
                d.dress(item, waiting.parent, waiting.parent.row, waiting.cb)
            }

            d.serving = false
        }

        function dress(item, parent, row, cb) {
            let binder = d.binders.get(item)

            if (!binder) {
                binder = rowBinderComponent.createObject(item, { target: item })
                d.binders.set(item, binder)
            }

            for (const name of d.context)
                item[name] = d.contextBinding(name)

            item.createMessageLink = (chatId, messageId) =>
                    root.messageStore.createMessageLink(chatId, messageId)
            item.mentionsMap = Qt.binding(() => mentionResolver.resolveFor(
                                              item.unparsedText + " " + item.quotedMessageUnparsedText))
            item.objectName = "chatMessageViewDelegate"

            binder.bind(messageWindow.model, row)

            // the width before the parent: a message without one never
            // settles its layout
            item.width = Qt.binding(() => parent ? parent.width : 0)
            item.parent = parent

            // Last, after the bind: retargeting writes properties whose change
            // signals are intents, and the relay must not see them.
            d.relays.set(item, intentRelayComponent.createObject(item, { target: item }))

            cb(item)
        }

        function contextBinding(name) {
            return Qt.binding(() => root[name])
        }

        function releaseRow(item) {
            // a message leaving the window while it is being edited stops
            // being edited, as it did when its delegate was destroyed
            if (item.editModeOn && root.messageStore)
                root.messageStore.setEditModeOff(item.messageId)

            const relay = d.relays.get(item)

            if (relay) {
                relay.destroy()
                d.relays.delete(item)
            }

            const binder = d.binders.get(item)

            if (binder)
                binder.detach()

            for (const name of d.context)
                item[name] = item[name]

            item.mentionsMap = ({})
            item.width = item.width

            if (d.pooledItems.has(item)) {
                d.pooledItems.delete(item)

                if (root.rowPool) {
                    root.rowPool.release(item)
                    return
                }
            }

            d.binders.delete(item)
            item.destroy()
        }

        // ---- Reading ------------------------------------------------------------------
        function markAllMessagesReadIfMostRecentMessageIsInViewport() {
            if (Qt.application.state != Qt.ApplicationActive || !d.isMostRecentMessageInViewport
                    || !chatLogView.visible || d.keepUnread)
                return

            if (d.chatDetails && d.chatDetails.active
                    && (d.chatDetails.hasUnreadMessages || d.chatDetails.highlight)
                    && !root.messageStore.loading)
                root.chatContentModule.markAllMessagesRead()
        }

        onIsMostRecentMessageInViewportChanged: d.markAllMessagesReadIfMostRecentMessageIsInViewport()
    }

    onRowPoolChanged: d.applyPoolTarget()

    Component.onCompleted: {
        d.applyPoolTarget()

        // an initial value fires no change handler
        d.attach(d.wantedStore)
    }

    // Every role under the name of the MessageView property it feeds.
    RolesRenamingModel {
        id: renamedMessages

        sourceModel: null

        mapping: [
            RoleRename { from: "id"; to: "messageId" },
            RoleRename { from: "timestamp"; to: "messageTimestamp" },
            RoleRename { from: "outgoingStatus"; to: "messageOutgoingStatus" },
            RoleRename { from: "contentType"; to: "messageContentType" },
            RoleRename { from: "pinned"; to: "pinnedMessage" },
            RoleRename { from: "pinnedBy"; to: "messagePinnedBy" },
            RoleRename { from: "reactions"; to: "reactionsModel" },
            RoleRename { from: "editMode"; to: "editModeOn" },
            RoleRename { from: "mentioned"; to: "hasMention" },
            RoleRename { from: "senderEnsVerified"; to: "senderIsEnsVerified" },
            RoleRename { from: "transactionParameters"; to: "transactionParams" },
            RoleRename { from: "quotedMessageParsedText"; to: "quotedMessageText" },
            RoleRename { from: "quotedMessageText"; to: "quotedMessageUnparsedText" },
            RoleRename { from: "quotedMessageAuthorName"; to: "quotedMessageAuthorDetailsName" },
            RoleRename { from: "quotedMessageAuthorDisplayName"; to: "quotedMessageAuthorDetailsDisplayName" },
            RoleRename { from: "quotedMessageAuthorThumbnailImage"; to: "quotedMessageAuthorDetailsThumbnailImage" },
            RoleRename { from: "quotedMessageAuthorEnsVerified"; to: "quotedMessageAuthorDetailsEnsVerified" },
            RoleRename { from: "quotedMessageAuthorIsContact"; to: "quotedMessageAuthorDetailsIsContact" },
            RoleRename { from: "albumImagesCount"; to: "albumCount" },
            RoleRename { from: "prevMsgIndex"; to: "prevMessageIndex" },
            RoleRename { from: "prevMsgTimestamp"; to: "prevMessageTimestamp" },
            RoleRename { from: "prevMsgSenderId"; to: "prevMessageSenderId" },
            RoleRename { from: "prevMsgContentType"; to: "prevMessageContentType" },
            RoleRename { from: "prevMsgDeleted"; to: "prevMessageDeleted" },
            RoleRename { from: "nextMsgIndex"; to: "nextMessageIndex" },
            RoleRename { from: "nextMsgTimestamp"; to: "nextMessageTimestamp" }
        ]
    }

    SQUtils.IndexWindowSource {
        id: messageWindow

        sourceModel: renamedMessages
        keyRole: "messageId"
        size: d.windowSize

        // Row 0 is the newest message and the bottom of the screen: while the
        // reader is there, a message arriving is shown, and the oldest one the
        // window held falls off the top.
        followsStart: chatLogView.atBottom
    }

    // the attached chat's store swapped its model
    Connections {
        target: d.wantedStore

        function onMessagesModelChanged() {
            d.attach(d.wantedStore)
        }
    }

    Connections {
        target: root.rootStore

        function onLoadingHistoryMessagesInProgressChanged() {
            if (root.rootStore.loadingHistoryMessagesInProgress)
                return

            d.historyMayHaveMore = true
            d.fetchHistoryAfterSync()
        }
    }

    Connections {
        target: renamedMessages

        // while the outgoing rows still have their geometry
        function onModelAboutToBeReset() {
            if (!d.attaching)
                d.captureRecord()
        }

        function onModelReset() {
            d.updateHistoryEnded()

            if (!d.attaching)
                Qt.callLater(d.reopenAfterReset)
        }

        function onRowsInserted() {
            d.updateHistoryEnded()
        }

        function onRowsRemoved() {
            d.updateHistoryEnded()
        }

        function onRowsMoved() {
            d.updateHistoryEnded()
        }

        function onLayoutChanged() {
            d.updateHistoryEnded()
        }
    }

    Connections {
        target: Qt.application

        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }
    }

    Connections {
        target: root.messageStore ? root.messageStore.messageModule : null

        function onMessageSuccessfullySent() {
            d.scrollToBottom()
        }

        function onSendingMessageFailed(error) {
            sendingMsgFailedPopup.error = error
            sendingMsgFailedPopup.open()
        }

        function onReactionActionFailed(addAction, error) {
            Global.displayToastMessage(
                        addAction ? qsTr("Couldn't add reaction") : qsTr("Couldn't remove reaction"),
                        qsTr("Please try again later"),
                        "warning",
                        false,
                        Constants.ephemeralNotificationType.danger,
                        "")
        }

        function onChatThreadsLoadingFailed() {
            Global.displayToastMessage(
                        qsTr("Couldn't load threads"),
                        qsTr("Please try again later"),
                        "warning",
                        false,
                        Constants.ephemeralNotificationType.danger,
                        "")
        }

        function onThreadCreationFailed() {
            Global.displayToastMessage(
                        qsTr("Couldn't create thread"),
                        qsTr("Please try again later"),
                        "warning",
                        false,
                        Constants.ephemeralNotificationType.danger,
                        "")
        }

        function onScrollToMessage(messageIndex) {
            d.goToMessage(messageIndex)
        }

        function onMoreMessagesLoaded() {
            d.fetchAnswered()
        }
    }

    Connections {
        target: root.messageStore

        function onMessageSearchOngoingChanged() {
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        function onLoadingChanged() {
            if (!renamedMessages.sourceModel)
                return

            if (root.messageStore.loading) {
                d.openLoadingBatch()
            } else {
                d.closeLoadingBatch()
                d.markAllMessagesReadIfMostRecentMessageIsInViewport()
            }
        }
    }

    Connections {
        target: d.chatDetails

        function onActiveChanged() {
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        function onHasUnreadMessagesChanged() {
            if (!d.chatDetails.hasUnreadMessages)
                return

            // HACK: we call `addNewMessagesMarker` later because messages model
            // may not be yet propagated with unread messages when this signal is emitted
            if (chatLogView.visible && !d.isMostRecentMessageInViewport)
                Qt.callLater(() => root.messageStore.addNewMessagesMarker())
        }
    }

    Connections {
        target: root.rowPool

        function onAvailabilityChanged(kind, readyCount) {
            if (kind === d.poolKind && readyCount > 0)
                d.serveStarved()
        }
    }

    Item {
        id: loadingMessagesIndicator

        visible: !!root.rootStore && root.rootStore.loadingHistoryMessagesInProgress
        anchors.top: parent.top
        anchors.left: parent.left
        height: visible ? 20 : 0
        width: parent.width

        Loader {
            active: loadingMessagesIndicator.visible
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: Component {
                LoadingAnimation {
                    width: 18
                    height: 18
                }
            }
        }
    }

    WindowedView {
        id: chatLogView

        objectName: "chatLogView"

        anchors.top: loadingMessagesIndicator.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        model: messageWindow.model
        keyRole: "messageId"
        verticalLayoutDirection: WindowedView.VerticalLayoutDirection.BottomToTop

        // Screen edges against model ends, crossed on purpose: the top of the
        // screen is the model's end, and beyond it the history the backend
        // still holds - see Paging.
        moreAvailableTop: messageWindow.moreAvailableEnd || d.olderHistoryMayExist
        moreAvailableBottom: messageWindow.moreAvailableStart

        // stuck to the newest message - never to the bottom of a window slid
        // into history, which has newer messages beyond it
        stickToBottom: !messageWindow.moreAvailableStart

        placeholder: MessageRowsSkeleton {}
        placeholderHeight: height
        prefetchMargin: height / 2
        acquireBudget: 8
        bottomPadding: Theme.halfPadding

        acquireDelegate: d.acquireRow
        releaseDelegate: d.releaseRow

        onMoreRequested: edge => d.fetchMore(edge)
        onBatchRevealed: d.onRevealed()

        onRowPositioned: row => {
            const shell = chatLogView.itemAtRow(row)

            if (shell && shell.content)
                shell.content.startMessageFoundAnimation()
        }

        onMovementEnded: d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        onVisibleChanged: d.markAllMessagesReadIfMostRecentMessageIsInViewport()

        Binding on flickDeceleration {
            when: localAppSettings.isCustomMouseScrollingEnabled
            value: localAppSettings.scrollDeceleration
            restoreMode: Binding.RestoreBindingOrValue
        }

        Binding on maximumFlickVelocity {
            when: localAppSettings.isCustomMouseScrollingEnabled
            value: localAppSettings.scrollVelocity
            restoreMode: Binding.RestoreBindingOrValue
        }

        ScrollBar.vertical: StatusScrollBar {
            visible: chatLogView.contentHeight > chatLogView.height
        }

        // At the start of the layout direction, so at the bottom of the
        // screen, below the newest message.
        header: {
            if (!root.isContactBlocked && root.isOneToOne && root.rootStore
                    && root.rootStore.oneToOneChatContact) {
                switch (root.rootStore.oneToOneChatContact.contactRequestState) {
                case Constants.ContactRequestState.None: // no break
                case Constants.ContactRequestState.Dismissed:
                    return sendContactRequestComponent
                case Constants.ContactRequestState.Received:
                    return acceptOrDeclineContactRequestComponent
                case Constants.ContactRequestState.Sent:
                    return pendingContactRequestComponent
                default:
                    break
                }
            }
            return null
        }
    }

    ChatAnchorButtonsPanel {
        anchors.bottom: chatLogView.bottom
        anchors.bottomMargin: Theme.padding
        anchors.right: chatLogView.right
        anchors.rightMargin: Theme.padding

        // Don't show the mention anchor in 1-1 chats, because all messages count as mentions
        mentionsCount: d.chatDetails && d.chatDetails.type !== Constants.chatType.oneToOne ?
                    d.chatDetails.notificationCount : 0
        recentMessagesCount: root.messageStore ? root.messageStore.newMessagesCount : 0
        recentMessagesButtonVisible: messageWindow.moreAvailableStart
                                     || chatLogView.contentHeight - chatLogView.contentY
                                        - chatLogView.height > 400

        onRecentMessagesButtonClicked: d.scrollToBottom()
        onMentionsButtonClicked: {
            const id = root.messageStore.firstUnseenMentionMessageId()

            if (id !== "") {
                root.messageStore.jumpToMessage(id)
                root.chatContentModule.markMessageRead(id)
            }
        }
    }

    // Rows the pool does not hold, built on demand.
    Component {
        id: messageViewComponent

        MessageView {}
    }

    Component {
        id: rowBinderComponent

        RowBinder {}
    }

    // Forwards a dressed row's intents. Created after the bind and destroyed at
    // release, so a rebind's property writes never reach it.
    Component {
        id: intentRelayComponent

        Connections {
            function onOpenStickerPackPopup(stickerPackId) {
                root.openStickerPackPopup(stickerPackId)
            }

            function onTokenPaymentRequested(recipientAddress, tokenKey, rawAmount) {
                root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)
            }

            function onShowReplyArea(messageId, author) {
                root.showReplyArea(messageId, author)
            }

            function onOpenThread(messageId) {
                root.openThread(messageId)
            }

            function onEditModeOnChanged() {
                root.editModeChanged(target.editModeOn, target.messageId)
            }

            function onSendViaPersonalChatRequested(recipientAddress) {
                Global.sendToRecipientRequested(recipientAddress)
            }

            function onEmojiReactionToggled(messageId, hexcode) {
                root.messageStore.toggleReaction(messageId, hexcode)
            }

            function onSetNeverAskAboutUnfurlingAgain(neverAskAgain) {
                root.setNeverAskAboutUnfurlingAgain(neverAskAgain)
            }

            function onOpenGifPopupRequest(params, cbOnGifSelected, cbOnClose) {
                root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)
            }

            function onChangeContactNicknameRequest(pubKey, nickname, displayName, isEdit) {
                root.changeContactNicknameRequest(pubKey, nickname, displayName, isEdit)
            }

            function onRemoveTrustStatusRequest(pubKey) {
                root.removeTrustStatusRequest(pubKey)
            }

            function onSpectateCommunityRequested(communityId) {
                root.spectateCommunityRequested(communityId)
            }
        }
    }

    StatusMessageDialog {
        id: sendingMsgFailedPopup

        property string error

        text: qsTr("Failed to send message.\n" + error)
        icon: StatusMessageDialog.StandardIcon.Critical
    }

    Component {
        id: sendContactRequestComponent

        StatusButton {
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            text: qsTr("Send Contact Request")
            onClicked: {
                Global.openContactRequestPopup(root.chatId, null)
            }
        }
    }

    Component {
        id: acceptOrDeclineContactRequestComponent

        Item {
            id: contactRequestActions

            readonly property real horizontalMargin: Theme.bigPadding + Theme.halfPadding
            readonly property real verticalMargin: Theme.padding
            readonly property real naturalWidth: rejectContactRequestButton.implicitWidth +
                                                 acceptContactRequestButton.implicitWidth +
                                                 buttonsRow.spacing
            readonly property real availableWidth: Math.max(0, width - 2 * horizontalMargin)
            readonly property bool compact: availableWidth < naturalWidth
            readonly property real compactButtonWidth: Math.max(0, (availableWidth - buttonsRow.spacing) / 2)

            width: parent ? parent.width : naturalWidth + 2 * horizontalMargin
            implicitHeight: buttonsRow.implicitHeight + 2 * verticalMargin

            RowLayout {
                id: buttonsRow

                anchors.centerIn: parent
                width: Math.min(contactRequestActions.naturalWidth, contactRequestActions.availableWidth)
                spacing: Theme.padding

                StatusButton {
                    id: rejectContactRequestButton

                    Layout.fillWidth: contactRequestActions.compact
                    Layout.preferredWidth: contactRequestActions.compact ? contactRequestActions.compactButtonWidth : implicitWidth
                    Layout.maximumWidth: contactRequestActions.compact ? contactRequestActions.compactButtonWidth : implicitWidth
                    textFillWidth: contactRequestActions.compact
                    text: qsTr("Reject Contact Request")
                    type: StatusBaseButton.Type.Danger
                    onClicked: {
                        root.dismissContactRequest(root.chatId, "")
                    }
                }

                StatusButton {
                    id: acceptContactRequestButton

                    Layout.fillWidth: contactRequestActions.compact
                    Layout.preferredWidth: contactRequestActions.compact ? contactRequestActions.compactButtonWidth : implicitWidth
                    Layout.maximumWidth: contactRequestActions.compact ? contactRequestActions.compactButtonWidth : implicitWidth
                    textFillWidth: contactRequestActions.compact
                    text: qsTr("Accept Contact Request")
                    onClicked: {
                        root.acceptContactRequest(root.chatId, "")
                    }
                }
            }
        }
    }

    Component {
        id: pendingContactRequestComponent

        StatusButton {
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            enabled: false
            text: qsTr("Contact Request Pending...")
        }
    }
}
