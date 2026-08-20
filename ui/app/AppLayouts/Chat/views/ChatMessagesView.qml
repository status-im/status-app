import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ 0.1
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import SortFilterProxyModel 0.2

import StatusQ.Core.Utils as SQUtils

import utils
import shared
import shared.stores as SharedStores
import shared.views
import shared.panels
import shared.popups
import shared.status
import shared.controls
import shared.views.chat

import AppLayouts.Chat.stores
import AppLayouts.stores as AppLayoutStores

import "../controls"
import "../panels"

Item {
    id: root

    property var chatContentModule

    property RootStore rootStore
    property MessageStore messageStore
    property string channelEmoji
    property var formatBalance

    // Users related data:
    property var usersModel

    // Resolves mention pub keys to display names. Reactive to member/contact
    // name changes; "everyone" is built in.
    MentionResolver {
        id: mentionResolver

        enabled: root.visible
        sourceModel: root.usersModel
        nameRole: "preferredDisplayName"
    }

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
    property string disabledTooltipText

    property int extraLeftPadding: 0

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    signal openStickerPackPopup(string stickerPackId)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)
    signal showReplyArea(string messageId, string author)
    signal editModeChanged(bool editModeOn, string messageId)

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

    // The hint singleton outlives this view: a chat switch mid-scroll must
    // not leak the pushed hint.
    Component.onDestruction: {
        if (d.userScrolling)
            IncubationHints.popGentle()
    }

    QtObject {
        id: d
        objectName: "chatMessagesViewInternal"

        readonly property bool isMostRecentMessageInViewport: chatLogView.atNewest
        readonly property var chatDetails: chatContentModule && chatContentModule.chatDetails || null
        readonly property bool keepUnread: messageStore.keepUnread

        // Sliding model window over messageStore.messagesModel (source row 0 =
        // newest); the view only ever holds the window's rows, never the history.
        // The initial size is derived from the viewport (assuming compact rows)
        // so the placeholder cannot start on screen and fire paging on open.
        readonly property int assumedMinRowHeight: 24
        readonly property int estimatedViewportRows: Math.ceil(chatLogView.height / d.assumedMinRowHeight)
        readonly property int initialWindowSize: Math.max(20, Math.min(d.maxWindowSize,
                                                                       d.estimatedViewportRows))
        readonly property int windowChunkSize: 30
        readonly property int maxWindowSize: 140

        property int windowStart: 0
        property int windowEnd: initialWindowSize - 1

        // ---- Staged rows (PR review: no rows assembling on screen) ----
        // A slide admits its whole chunk at once, but the rows enter as cheap
        // shells whose content incubates asynchronously and holds no visual
        // space — the placeholder keeps covering the region. Only when every
        // row of the batch is built (or the safety timeout fires) does the
        // batch reveal, in one frame: one relayout, one anchor restore, and
        // the user never sees a chunk assemble row by row.
        //
        // Rows created outside a staged admit — the initial fill and live
        // incoming messages — show as soon as they load: the initial fill
        // grows above the bottom-stuck viewport, and a live message must
        // never wait for an unrelated batch.
        property var stagedShells: []
        // Rows admitted by a staged slide whose shells the engine has not
        // created yet, keyed by message id. Shell creation is asynchronous
        // whenever an ancestor is still incubating (AsynchronousIfNested), so
        // admission is captured at row insertion — synchronous with the
        // window mutation — never inferred from shell creation timing.
        property var stagedIds: new Set()
        property int stagedCount: 0
        property bool admittingStaged: false

        function syncStagedCount() {
            stagedCount = stagedShells.length + stagedIds.size
        }

        // Running average of revealed row heights, for the placeholder size.
        property real avgRowHeight: 0

        // Scrolling competes with incubation for frame time on low-end
        // devices: hold a gentle hint while the user scrolls so staged rows
        // build in small paced bites and the flick stays smooth.
        readonly property bool userScrolling: chatLogView.moving || verticalScrollBar.pressed

        onUserScrollingChanged: {
            if (userScrolling)
                IncubationHints.pushGentle()
            else
                IncubationHints.popGentle()
        }

        function admitStaged(mutator) {
            d.admittingStaged = true
            mutator()
            d.admittingStaged = false
            if (d.stagedCount > 0)
                revealTimeout.restart()
        }

        // Rows entering the window during a staged admit, captured while they
        // are inserted. Their shells may only be created later (async
        // incubation) — the ids bridge that gap.
        function captureStagedRows(first, last) {
            if (!d.admittingStaged)
                return
            for (let i = first; i <= last; ++i) {
                const id = SQUtils.ModelUtils.get(messagesWindow, i, "id")
                if (id !== undefined && id !== null)
                    d.stagedIds.add(id)
            }
            d.syncStagedCount()
        }

        // A staged row leaving the window before its shell was ever created
        // must not hold the batch open.
        function dropStagedRows(first, last) {
            if (d.stagedIds.size === 0)
                return
            let dropped = false
            for (let i = first; i <= last; ++i) {
                const id = SQUtils.ModelUtils.get(messagesWindow, i, "id")
                if (id !== undefined && id !== null && d.stagedIds.delete(id))
                    dropped = true
            }
            if (dropped) {
                d.syncStagedCount()
                d.checkStagedReady()
            }
        }

        // The shell for a captured row arrived: it joins the batch. Rows
        // never captured (initial fill, live messages) reveal on their own.
        function takeStagedId(id) {
            return d.stagedIds.delete(id)
        }

        function stageShell(shell) {
            d.stagedShells.push(shell)
            d.syncStagedCount()
        }

        function unstageShell(shell) {
            const i = d.stagedShells.indexOf(shell)
            if (i < 0)
                return
            d.stagedShells.splice(i, 1)
            d.syncStagedCount()
            // the batch may have become complete by losing its last unbuilt row
            d.checkStagedReady()
        }

        function checkStagedReady() {
            if (d.stagedCount === 0) {
                revealTimeout.stop()
                return
            }
            if (d.stagedIds.size > 0) {
                // shells still to be created: progress is expected, keep the
                // stall detector armed (see below)
                revealTimeout.restart()
                return
            }
            for (let i = 0; i < d.stagedShells.length; ++i) {
                if (!d.stagedShells[i].contentReady) {
                    // called on every row completion, so this makes the
                    // timeout a stall detector: it only fires after a full
                    // interval with NO build progress. A slow-but-progressing
                    // batch must never be flushed half-built — flushed rows
                    // hold no space, so the placeholder would keep admitting
                    // more rows and race the window into an endless
                    // build-and-fetch loop the device can never catch up with
                    revealTimeout.restart()
                    return
                }
            }
            d.revealStaged()
        }

        function clearStaging() {
            d.stagedShells = []
            d.stagedIds.clear()
            d.syncStagedCount()
            revealTimeout.stop()
        }

        // Reveals whatever is staged — normally a complete batch, on timeout
        // a partial one (better than wedging paging on a pathological row).
        function revealStaged() {
            revealTimeout.stop()
            // stragglers whose shells never got created (timeout path) fall
            // back to revealing individually on their own completion
            d.stagedIds.clear()
            const batch = d.stagedShells
            d.stagedShells = []
            d.syncStagedCount()
            let sum = 0
            let measured = 0
            for (let i = 0; i < batch.length; ++i) {
                batch[i].revealed = true
                if (batch[i].height > 0) {
                    sum += batch[i].height
                    ++measured
                }
            }
            if (measured > 0) {
                const avg = sum / measured
                d.avgRowHeight = d.avgRowHeight > 0 ? (d.avgRowHeight + avg) / 2 : avg
            }
        }

        // The chat identifier (clock -2) is the last row of every chat; the
        // backend keeps a fetch-more row (clock -1) directly above it for as
        // long as older messages can be requested. History is exhausted only
        // when the identifier is not preceded by that row. The count heuristic
        // alone never settles (fetch churn re-arms it).
        property bool historyExhausted: false

        function updateHistoryExhausted() {
            const model = root.messageStore?.messagesModel ?? null
            if (!model || model.count === 0) {
                historyExhausted = false
                return
            }
            const last = SQUtils.ModelUtils.get(model, model.count - 1, "contentType")
            const beforeLast = model.count > 1
                    ? SQUtils.ModelUtils.get(model, model.count - 2, "contentType")
                    : undefined
            historyExhausted = last === Constants.messageContentType.chatIdentifier
                    && beforeLast !== Constants.messageContentType.fetchMoreMessagesButton
        }

        // The initial size is re-derived once the view has a height; growth
        // only, shrinking would destroy rows the viewport may be showing.
        property bool windowAtInitial: true

        onInitialWindowSizeChanged: {
            if (d.windowAtInitial && d.initialWindowSize - 1 > d.windowEnd)
                d.windowEnd = d.initialWindowSize - 1
        }

        readonly property int historyCount: messageStore.messagesModel ? messageStore.messagesModel.count : 0

        // History count at the last fetch: stops the placeholder once a fetch
        // brings nothing, re-arms when history grows.
        property int lastFetchHistoryCount: -1
        readonly property bool mayFetchMoreHistory: d.historyCount !== d.lastFetchHistoryCount

        readonly property bool olderMessagesAvailable: d.historyCount > 0
                                                       && (d.windowEnd < d.historyCount - 1
                                                           || (!d.historyExhausted
                                                               && (d.mayFetchMoreHistory
                                                                   || root.rootStore.loadingHistoryMessagesInProgress)))

        function resetWindow() {
            clearStaging()
            windowStart = 0
            windowEnd = initialWindowSize - 1
            windowAtInitial = true
            lastFetchHistoryCount = -1
        }

        function slideWindowToHistory() {
            // one batch at a time: the paging timer keeps asking while the
            // placeholder shows, and the next chunk must wait for this one
            if (d.stagedCount > 0)
                return

            if (d.windowEnd < d.historyCount - 1) {
                d.windowAtInitial = false
                d.admitStaged(function() {
                    d.windowEnd = Math.min(d.historyCount - 1, d.windowEnd + d.windowChunkSize)
                    if (d.windowEnd - d.windowStart + 1 > d.maxWindowSize)
                        d.windowStart = d.windowEnd - d.maxWindowSize + 1
                })
                return
            }

            if (root.rootStore.loadingHistoryMessagesInProgress || d.historyExhausted
                    || !d.mayFetchMoreHistory)
                return

            d.lastFetchHistoryCount = d.historyCount
            messageStore.loadMoreMessages()
        }

        function slideWindowToRecent() {
            if (d.stagedCount > 0 || d.windowStart <= 0)
                return

            d.admitStaged(function() {
                d.windowStart = Math.max(0, d.windowStart - d.windowChunkSize)
                if (d.windowEnd - d.windowStart + 1 > d.maxWindowSize)
                    d.windowEnd = d.windowStart + d.maxWindowSize - 1
            })
        }

        // QSFPM only re-evaluates inserted rows; nudge the bound so the filter
        // re-checks all rows (deferred — the proxy may lag the source change).
        // Staged: the nudge can transiently admit an extra row, which must not
        // pop in half-built.
        function refilterWindow() {
            d.admitStaged(function() {
                const end = d.windowEnd
                d.windowEnd = end + 1
                d.windowEnd = end
            })
        }

        // Moves the window so that a source index sits in the middle of it and
        // can therefore be scrolled to. Only a tiny window around the target:
        // it builds and reveals fast, and the placeholders then grow the
        // window chunk by chunk through the ordinary paging path.
        function centerWindowOn(messageIndex) {
            d.windowAtInitial = false
            d.admitStaged(function() {
                d.windowStart = Math.max(0, messageIndex - 2)
                d.windowEnd = Math.min(Math.max(0, d.historyCount - 1), messageIndex + 2)
            })
        }

        function markAllMessagesReadIfMostRecentMessageIsInViewport() {
            if (Qt.application.state != Qt.ApplicationActive || !isMostRecentMessageInViewport || !chatLogView.visible || keepUnread) {
                return
            }

            if (chatDetails && chatDetails.active && (chatDetails.hasUnreadMessages || chatDetails.highlight) && !messageStore.loading) {
                chatContentModule.markAllMessagesRead()
            }
        }

        function goToMessage(messageIndex) {
            d.centerWindowOn(messageIndex)
            chatLogView.positionAtRow(messageIndex - d.windowStart)
        }

        // Returns the view to the newest message. With the window already at
        // the recent end (every sent message lands here) nothing is rebuilt —
        // a teardown would flash the paging skeleton over the user's own
        // messages. From deep in history it is a JUMP: the window collapses
        // to a recent-end screenful instead of readmitting and unrolling
        // every row in between.
        function scrollToBottom() {
            if (d.windowStart > 0) {
                d.windowAtInitial = false
                d.admitStaged(function() {
                    // end first: emptying the window before re-basing it at 0
                    // avoids transiently admitting the whole span in between
                    d.windowEnd = Math.min(Math.max(0, d.historyCount - 1),
                                           d.initialWindowSize - 1)
                    d.windowStart = 0
                })
            }
            chatLogView.positionAtNewest()
            markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        onIsMostRecentMessageInViewportChanged: markAllMessagesReadIfMostRecentMessageIsInViewport()
    }

    // Source-model inserts and removals below the window would otherwise shift
    // which messages the index window selects; keep it pinned to the same rows.
    Connections {
        target: root.messageStore?.messagesModel ?? null

        function onRowsInserted(parent, first, last) {
            if (d.windowStart > 0 && first <= d.windowStart) {
                const inserted = last - first + 1
                d.windowStart += inserted
                d.windowEnd += inserted
            }
            if (first <= d.windowEnd)
                Qt.callLater(d.refilterWindow)
            Qt.callLater(d.updateHistoryExhausted)
        }

        function onRowsRemoved(parent, first, last) {
            if (d.windowStart > 0 && first < d.windowStart) {
                const removed = Math.min(last, d.windowStart - 1) - first + 1
                d.windowStart -= removed
                d.windowEnd -= removed
            }
            if (first <= d.windowEnd)
                Qt.callLater(d.refilterWindow)
            Qt.callLater(d.updateHistoryExhausted)
        }
    }

    // Safety valve for staged batches: restarted on every row completion, so
    // it fires only after a full interval without any build progress — a
    // genuinely wedged batch, not a slow one. Whatever is built is shown;
    // the stuck rows stay hidden and appear if they ever finish.
    Timer {
        id: revealTimeout

        objectName: "batchRevealTimeout"
        interval: 1000

        onTriggered: d.revealStaged()
    }


    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive) {
                d.markAllMessagesReadIfMostRecentMessageIsInViewport()
            }
        }
    }

    Connections {
        target: root.messageStore.messageModule

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

        function onScrollToMessage(messageIndex) {
            d.goToMessage(messageIndex)
        }
    }

    Connections {
        target: root.messageStore

        function onMessageSearchOngoingChanged() {
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        function onLoadingChanged() {
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
            if (!messageStore.loading && chatLogView.stickingToNewest) {
                Qt.callLater(d.scrollToBottom)
            }
        }
    }

    Connections {
        target: !!d.chatDetails ? d.chatDetails : null

        function onActiveChanged() {
            if (active && chatLogView.stickingToNewest) {
                Qt.callLater(d.scrollToBottom)
            }

            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        function onHasUnreadMessagesChanged() {
            if (!d.chatDetails.hasUnreadMessages) {
                return
            }

            // The marker enters the view when the window slides over it.
            // HACK: we call `addNewMessagesMarker` later because messages model
            // may not be yet propagated with unread messages when this signal is emitted
            if (chatLogView.visible && (Qt.application.state != Qt.ApplicationActive || !d.isMostRecentMessageInViewport)) {
                Qt.callLater(() => messageStore.addNewMessagesMarker())
            }
        }
    }

    Item {
        id: loadingMessagesIndicator
        visible: root.rootStore.loadingHistoryMessagesInProgress
        anchors.top: parent.top
        anchors.left: parent.left
        height: visible? 20 : 0
        width: parent.width

        Loader {
            active: root.rootStore.loadingHistoryMessagesInProgress
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

    ChatMessagesFlickable {
        id: chatLogView
        visible: !messageStore.loading
        objectName: "chatLogView"
        anchors.top: loadingMessagesIndicator.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        contentBottomPadding: Theme.halfPadding

        // A staged batch keeps the placeholder up: its rows hold no space
        // until they reveal, and dropping the placeholder meanwhile would
        // collapse the region they are about to fill.
        moreUpAvailable: d.olderMessagesAvailable || d.stagedCount > 0
        moreDownAvailable: d.windowStart > 0

        // Approximates the out-of-window content so the scrollbar stays
        // roughly proportional across reveals: the rows a reveal adds are
        // taken out of the placeholder, keeping the content height steady.
        placeholderHeight: {
            const remaining = Math.max(d.historyCount - 1 - d.windowEnd, d.windowStart)
            const estimate = Math.min(remaining, 300) * (d.avgRowHeight || 48)
            return Math.max(chatLogView.height, estimate)
        }

        // Page one viewport ahead of the scroll so a batch is usually
        // revealed before its placeholder is ever seen.
        prefetchMargin: chatLogView.height

        onMoreUpRequested: d.slideWindowToHistory()
        onMoreDownRequested: d.slideWindowToRecent()

        onRowPositioned: row => {
            const item = chatLogView.itemAtRow(row)
            if (item && item.startMessageFoundAnimation)
                item.startMessageFoundAnimation()
        }

        onMovementEnded: d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        onVisibleChanged: d.markAllMessagesReadIfMostRecentMessageIsInViewport()

        placeholder: MessageRowsSkeleton {}

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

        // The view is handed only the [windowStart..windowEnd] slice. The
        // source stays detached until the initial fetch is done — attaching
        // earlier costs one incubation per row; the covering skeleton in
        // ChatContentView hides both that phase and the view's incubation.
        model: SortFilterProxyModel {
            id: messagesWindow

            sourceModel: messageStore.loading ? null : messageStore.messagesModel
            onSourceModelChanged: {
                d.resetWindow()
                d.updateHistoryExhausted()
                // whatever the paging timer did against the detached window,
                // the view opens on the newest message
                if (sourceModel)
                    Qt.callLater(chatLogView.positionAtNewest)
            }

            filters: IndexFilter {
                minimumIndex: d.windowStart
                maximumIndex: d.windowEnd
            }

            // Declared on the model itself so these connections run before the
            // Repeater's: a synchronously created shell must already find its
            // id captured.
            onRowsInserted: (parent, first, last) => d.captureStagedRows(first, last)
            onRowsAboutToBeRemoved: (parent, first, last) => d.dropStagedRows(first, last)

            onCountChanged: d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        ScrollBar.vertical: StatusScrollBar {
            id: verticalScrollBar

            visible: chatLogView.contentHeight > chatLogView.height
        }

        // Shell + inline async Loader: the Repeater only ever builds the cheap
        // shell synchronously; the actual MessageView incubates asynchronously
        // (paced by the app's incubation controller). The component must stay
        // inline — an external one would lose the model roles' context.
        delegate: Loader {
            id: shell

            // Row 0 is the newest message and belongs at the bottom; +1
            // keeps grid row 0 free as the spawn cell (see the view's docs)
            Layout.row: root.chatLogView.rowCount - index + 1
            Layout.column: 0
            // Hard-pin the cell width (as ListView did) instead of fillWidth:
            // message implicit-width echoes livelock the GridLayout otherwise.
            Layout.preferredWidth: root.chatLogView.width
            Layout.minimumWidth: root.chatLogView.width
            Layout.maximumWidth: root.chatLogView.width

            // Pinned while staged too (the layout ignores invisible items),
            // so the message lays out its text at its final width and the
            // reveal-frame polish only places pre-measured rows.
            width: root.chatLogView.width

            asynchronous: true

            // The shell being Ready only means the MessageView *instance*
            // exists — MessageView is itself a Loader whose content keeps
            // incubating (with a 50px fallback height). A row is only ready
            // once that inner content is fully built and measured; a content
            // type without a component (inner status Null) is ready as is.
            readonly property bool contentReady: status === Loader.Ready && item
                                                 && item.status !== Loader.Loading

            // Rows admitted by a staged slide hold no visual space until the
            // whole batch is ready; everything else shows as soon as it is
            // ready itself. A row that is still loading is never shown.
            property bool revealed: false
            visible: revealed && contentReady

            readonly property string messageId: model.id

            function startMessageFoundAnimation() {
                if (item)
                    item.startMessageFoundAnimation()
            }

            // Membership in a staged batch is decided by the captured row id,
            // not by creation timing: under a still-incubating ancestor the
            // shell is created asynchronously, long after the admit returned.
            Component.onCompleted: {
                if (d.takeStagedId(messageId))
                    d.stageShell(this)
                else
                    revealed = true
            }
            Component.onDestruction: d.unstageShell(this)

            onContentReadyChanged: {
                if (contentReady && !revealed)
                    d.checkStagedReady()
            }

            sourceComponent: MessageView {
                id: msgDelegate

                objectName: "chatMessageViewDelegate"

                rootStore: root.rootStore
                messageStore: root.messageStore
                channelEmoji: root.channelEmoji
                emojiPopup: root.emojiPopup
                stickersPopup: root.stickersPopup
                chatLogView: root.chatLogView
                chatContentModule: root.chatContentModule
                formatBalance: root.formatBalance
                usersModel: root.usersModel
                // covers the message body and the quoted reply, whose mentions
                // also render through this map
                mentionsMap: mentionResolver.resolveFor(model.unparsedText + " " + model.quotedMessageText)

                isChatBlocked: root.isChatBlocked
                joined: root.joined

                sendViaPersonalChatEnabled: root.sendViaPersonalChatEnabled
                messageLinkSharingEnabled: root.messageLinkSharingEnabled
                createMessageLink: (chatId, messageId) => root.messageStore.createMessageLink(chatId, messageId)
                disabledTooltipText: root.disabledTooltipText
                areTestNetworksEnabled: root.areTestNetworksEnabled
                extraLeftPadding: root.extraLeftPadding

                chatId: root.chatId
                messageId: model.id
                communityId: model.communityId
                responseToMessageWithId: model.responseToMessageWithId
                senderId: model.senderId
                senderDisplayName: model.senderDisplayName
                usesDefaultName: model.usesDefaultName
                senderOptionalName: model.senderOptionalName
                senderIsEnsVerified: model.senderEnsVerified
                senderIcon: model.senderIcon
                senderIsAdded: model.senderIsAdded
                senderTrustStatus: model.senderTrustStatus
                compressedKey: model.compressedKey
                amISender: model.amISender
                messageText: model.messageText
                unparsedText: model.unparsedText
                messageImage: model.messageImage
                album: model.albumMessageImages.split(" ")
                albumCount: model.albumImagesCount
                messageTimestamp: model.timestamp
                messageOutgoingStatus: model.outgoingStatus
                resendError: model.resendError
                messageContentType: model.contentType
                pinnedMessage: model.pinned
                messagePinnedBy: model.pinnedBy
                reactionsModel: model.reactions
                sticker: model.sticker
                stickerPack: model.stickerPack
                editModeOn: model.editMode
                onEditModeOnChanged: root.editModeChanged(editModeOn, model.id)
                isEdited: model.isEdited
                deleted: model.deleted
                deletedBy: model.deletedBy
                deletedByContactDisplayName: model.deletedByContactDisplayName
                deletedByContactIcon: model.deletedByContactIcon
                linkPreviewModel: model.linkPreviewModel
                links: model.links
                paymentRequestModel: model.paymentRequestModel
                messageAttachments: model.messageAttachments
                transactionParams: model.transactionParameters
                hasMention: model.mentioned
                quotedMessageText: model.quotedMessageParsedText
                quotedMessageUnparsedText: model.quotedMessageText
                quotedMessageFrom: model.quotedMessageFrom
                quotedMessageContentType: model.quotedMessageContentType
                quotedMessageDeleted: model.quotedMessageDeleted
                quotedMessageAuthorDetailsName: model.quotedMessageAuthorName
                quotedMessageAuthorDetailsDisplayName: model.quotedMessageAuthorDisplayName
                quotedMessageAuthorDetailsThumbnailImage: model.quotedMessageAuthorThumbnailImage
                quotedMessageAuthorDetailsEnsVerified: model.quotedMessageAuthorEnsVerified
                quotedMessageAuthorDetailsIsContact: model.quotedMessageAuthorIsContact
                quotedMessageAlbumMessageImages: model.quotedMessageAlbumMessageImages.split(" ")
                quotedMessageAlbumImagesCount: model.quotedMessageAlbumImagesCount
                bridgeName: model.bridgeName

                gapFrom: model.gapFrom
                gapTo: model.gapTo

                 // This is possible since we have all data loaded before we load qml.
                 // When we fetch messages to fulfill a gap we have to set them at once.
                 // Also one important thing here is that messages are set in descending order
                 // in terms of `timestamp` of a message, that means a message with the most
                 // recent time is added at index 0.
                prevMessageIndex: model.prevMsgIndex
                prevMessageTimestamp: model.prevMsgTimestamp
                prevMessageSenderId: model.prevMsgSenderId
                prevMessageContentType: model.prevMsgContentType
                prevMessageDeleted: model.prevMsgDeleted
                nextMessageIndex: model.nextMsgIndex
                nextMessageTimestamp: model.nextMsgTimestamp

                // Unfurling related data:
                gifUnfurlingEnabled: root.gifUnfurlingEnabled
                neverAskAboutUnfurlingAgain: root.neverAskAboutUnfurlingAgain

                // Contacts related data:
                myPublicKey: root.myPublicKey

                onOpenStickerPackPopup: stickerPackId => root.openStickerPackPopup(stickerPackId)
                onTokenPaymentRequested: root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)

                onShowReplyArea: (messageId, author) => root.showReplyArea(messageId, author)

                stickersLoaded: root.stickersLoaded

                onSendViaPersonalChatRequested: {
                    Global.sendToRecipientRequested(recipientAddress)
                }

                onVisibleChanged: {
                    if(!visible && model.editMode)
                        messageStore.setEditModeOff(model.id)
                }

                onEmojiReactionToggled: (messageId, hexcode) => {
                    root.messageStore.toggleReaction(messageId, hexcode)
                }

                // Unfurling related requests:
                onSetNeverAskAboutUnfurlingAgain: root.setNeverAskAboutUnfurlingAgain(neverAskAgain)

                onOpenGifPopupRequest: root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)

                // Contacts related requests:
                onChangeContactNicknameRequest: root.changeContactNicknameRequest(pubKey, nickname, displayName, isEdit)
                onRemoveTrustStatusRequest: root.removeTrustStatusRequest(pubKey)

                // Community access related requests:
                onSpectateCommunityRequested: (communityId) => {
                    root.spectateCommunityRequested(communityId)
                }
            }
        }
        bottomContent: {
            if (!root.isContactBlocked && root.isOneToOne && root.rootStore.oneToOneChatContact) {
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

        visible: chatLogView.visible

        // Don't show the mention anchor in 1-1 chats, because all messages count as mentions
        mentionsCount: d.chatDetails && d.chatDetails.type !== Constants.chatType.oneToOne ?
                    d.chatDetails.notificationCount : 0
        recentMessagesCount: root.messageStore.newMessagesCount
        recentMessagesButtonVisible: chatLogView.moreDownAvailable
                                     || chatLogView.contentHeight - chatLogView.contentY - chatLogView.height > 400

        onRecentMessagesButtonClicked: d.scrollToBottom()
        onMentionsButtonClicked: {
            let id = messageStore.firstUnseenMentionMessageId()
            if (id !== "") {
                messageStore.jumpToMessage(id)
                chatContentModule.markMessageRead(id)
            }
        }
    }

    StatusMessageDialog {
        property string error

        id: sendingMsgFailedPopup
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
