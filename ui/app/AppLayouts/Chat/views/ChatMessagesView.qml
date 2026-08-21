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

import QtModelsToolkit
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

    // Row pool (ADR 0007): app-owned reservoir of pre-built MessageViews the
    // shells acquire row content from instead of building it. Null hosts
    // (popups, storybook pages) build rows inline as before.
    property DelegatePool rowPool: null
    onRowPoolChanged: d.applyPoolTarget()

    // Dress hold (ADR 0007): raised while a view transition runs. Dress
    // triggers keep enqueuing; the drain waits and restarts on release.
    property bool dressHold: false
    Component.onCompleted: {
        d.applyPoolTarget()
        d.updatePlaceholderHeights()
        d.viewCompleted = true
    }

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

    // The hint singleton and the pool outlive this view: a chat switch
    // mid-scroll must not leak the pushed hint or a pending demand boost.
    Component.onDestruction: {
        if (d.userScrolling)
            IncubationHints.popGentle()
        if (rowPool)
            rowPool.clearBoost(d.rowPoolKind)
    }

    QtObject {
        id: d
        objectName: "chatMessagesViewInternal"

        readonly property bool isMostRecentMessageInViewport: chatLogView.atNewest
        readonly property var chatDetails: chatContentModule && chatContentModule.chatDetails || null
        readonly property bool keepUnread: messageStore.keepUnread

        // ---- Dense model (issue 0022) ----
        // The dense model's row count IS the chat's stored-message count, so
        // an index is an absolute history position and the rows the window
        // has not fetched yet are dummies. It exists only under
        // FLAG_DENSE_MESSAGE_MODEL_ENABLED; without it the window runs over
        // the legacy model, which holds only what was paged in, and every
        // dense-only path below is skipped.
        readonly property bool denseMode: !!root.messageStore?.denseMessagesModel

        readonly property var windowSource: d.denseMode
                                          ? root.messageStore.denseMessagesModel
                                          : (root.messageStore?.messagesModel ?? null)

        // Sliding model window over messageStore.messagesModel (source row 0 =
        // newest); the view only ever holds the window's rows, never the history.
        // The initial size is derived from the viewport (assuming compact rows)
        // so the placeholder cannot start on screen and fire paging on open.
        readonly property int assumedMinRowHeight: 24
        readonly property int estimatedViewportRows: Math.ceil(chatLogView.height / d.assumedMinRowHeight)
        readonly property int initialWindowSize: Math.max(20, Math.min(d.maxWindowSize,
                                                                       d.estimatedViewportRows))
        // One fetch = one window chunk: the chunk IS the middleware's page size
        // (MESSAGES_PER_PAGE, forwarded by the store), so a slide never outruns
        // what a single page delivers. The literal covers only the instant
        // before the message module has attached and reported it.
        readonly property int windowChunkSize: {
            if (messageStore.messagesPerPage > 0)
                return messageStore.messagesPerPage
            return 30
        }
        // Fallback cap, pool-less hosts only: with a pool the cap is defined
        // by what the pool can dress (see poolHeadroom below).
        readonly property int maxWindowSize: 140

        property int windowStart: 0
        property int windowEnd: initialWindowSize - 1

        // The index-shift invariant, in one place. Row 0 is the newest
        // message, so the only changes that move the window's rows are the
        // ones below it — inserts and removals at lower (newer) indices; a
        // backfill arriving at the older end never moves it, and neither
        // does a hole fill, which is dataChanged over a fixed row count.
        // A window still pinned at the newest end (windowStart 0) is the one
        // exception: it deliberately follows the newest message rather than
        // shifting away from it.
        // Bounds are written narrow-first — the same release-before-acquire
        // ordering every slide uses, so the transient state can never
        // over-subscribe the pool.
        function applyIndexShift(first, last, inserted) {
            if (d.windowStart <= 0)
                return
            if (inserted) {
                if (first > d.windowStart)
                    return
                const delta = last - first + 1
                d.windowStart += delta
                d.windowEnd += delta
                return
            }
            if (first >= d.windowStart)
                return
            const removed = Math.min(last, d.windowStart - 1) - first + 1
            d.windowEnd -= removed
            d.windowStart -= removed
        }

        // The empty window an undressed view holds. NEVER windowEnd = -1:
        // the IndexFilter wraps negative indices from the model's end, so
        // [0..-1] admits the entire history instead of nothing.
        function closeWindow() {
            windowStart = 1
            windowEnd = 0
        }

        // ---- Window record (ADR 0007): the durable per-chat name of a
        // viewing position, captured on switch-away and restored on return.
        // {atBottom} or {oldestRowId, span, offset}: named by message id and
        // measured from the window's own content top, never indices or
        // absolute contentY — both rot while the chat is inactive.
        property var windowRecords: ({})

        // The chat the current window belongs to. Latched from the store at
        // attach: root.chatId may still hold the previous chat while the
        // bindings of a switch settle.
        property string recordKey: ""

        // A restore in flight: the window is rebuilding as one staged batch
        // whose reveal applies the recorded position. Until it does, every
        // automatic repositioning (the marker scroll, bottom-follows) is
        // ignored — within a session the record wins over the marker.
        property var pendingRestore: null

        function captureWindowRecord() {
            if (!d.recordKey)
                return
            // an entry that never revealed (or is still restoring) holds no
            // position of its own — keep the previous record
            if (d.initialFillActive || d.pendingRestore)
                return
            if (chatLogView.stickingToNewest || chatLogView.atNewest) {
                d.windowRecords[d.recordKey] = ({ atBottom: true })
                return
            }
            for (let i = chatLogView.count - 1; i >= 0; --i) {
                // the shells' own reveal state, not visible: a section
                // deactivation captures while the whole view is already
                // effectively invisible, geometry still intact
                const item = chatLogView.itemAtRow(i)
                // a dummy's key is positional and rots the moment the
                // history shifts: only a loaded row can name a position
                if (!item || !item.revealed || !item.contentReady
                        || !item.rowLoaded || item.height <= 0)
                    continue
                const offset = chatLogView.viewportOffsetToRow(i)
                if (isNaN(offset))
                    return
                d.windowRecords[d.recordKey] = ({
                    oldestRowId: item.rowKey,
                    span: i + 1,
                    offset: offset
                })
                return
            }
        }

        // Opens the window for the chat the source model now carries:
        // through its window record when one exists, at the newest message
        // otherwise. The at-bottom exception restores to the CURRENT newest
        // window — the ordinary open — never a frozen record.
        function openWindow() {
            d.recordKey = root.messageStore.getChatId()
            const record = d.windowRecords[d.recordKey]
            if (d.dressActive && record && !record.atBottom) {
                const index = SQUtils.ModelUtils.indexOf(
                            d.windowSource, d.denseMode ? "key" : "id",
                            record.oldestRowId)
                if (index >= 0) {
                    d.restoreWindow(index, record)
                    return
                }
                // deleted anchor or cleared history: the record names nothing
                delete d.windowRecords[d.recordKey]
            }
            d.resetWindow()
            d.schedulePositionAtNewest()
        }

        // Rebuilds the recorded window around the anchor as one staged batch:
        // the skeleton holds until every row is dressed, one atomic reveal,
        // then the recorded offset from the window's content top — the same
        // rows at the same width reproduce the same layout exactly.
        function restoreWindow(endIndex, record) {
            clearStaging()
            initialFillActive = false
            if (root.rowPool)
                root.rowPool.clearBoost(d.rowPoolKind)
            d.pendingPositionAtNewest = false
            d.windowAtInitial = false
            d.lastFetchHistoryCount = -1
            d.pendingRestore = ({ messageId: record.oldestRowId,
                                  offset: record.offset })
            const capacity = d.usePool
                           ? Math.max(1, d.acquiredCount + d.poolHeadroom())
                           : d.maxWindowSize
            const start = Math.max(0, endIndex
                                      - Math.min(record.span, capacity) + 1)
            d.admitStaged(function() {
                // start first: moving the start deeper never admits rows, so
                // the span between the stale bounds and the target is never
                // transiently admitted
                d.windowStart = start
                d.windowEnd = endIndex
            })
        }

        function applyPendingRestore() {
            const restore = d.pendingRestore
            // cleared a turn later, not here: the marker scroll this restore
            // must win over can arrive in the same turn as the reveal
            Qt.callLater(function() {
                if (d.pendingRestore === restore)
                    d.pendingRestore = null
            })
            for (let i = chatLogView.count - 1; i >= 0; --i) {
                const item = chatLogView.itemAtRow(i)
                if (item && item.rowKey === restore.messageId) {
                    chatLogView.positionAtRowOffset(i, restore.offset)
                    return
                }
            }
            // the anchor never made it into the batch (timeout reveal of a
            // wedged row): the bottom is the only safe place left
            chatLogView.positionAtNewest()
        }

        // The window proxy's filters only engage at completion: a source
        // attached during creation would flash the ENTIRE unfiltered history
        // through the Repeater once. Hold the source off until then.
        property bool viewCompleted: false

        // ---- Dressed window (ADR 0007): in-window ⇔ holds a pooled item ----
        readonly property bool usePool: !!root.rowPool
        readonly property string rowPoolKind: "message"

        // Only while visible does the view hold pooled items: there is one
        // pool and at most one dressed view app-wide, and the inactive chats'
        // views must not starve the active one.
        readonly property bool dressActive: !d.usePool || root.visible

        onDressActiveChanged: {
            if (!d.usePool)
                return
            if (d.dressActive) {
                d.openWindow()
            } else {
                // capture BEFORE the un-dress collapses the window
                d.captureWindowRecord()
                d.clearStaging()
                d.dressQueue = []
                d.initialFillActive = false
                d.pendingRestore = null
                if (root.rowPool)
                    root.rowPool.clearBoost(d.rowPoolKind)
                d.closeWindow()
            }
        }

        // Every real message content type resolves to MessageView's single
        // inner message component, so one pooled kind covers them all; the
        // rest are rare by construction and stay on-demand rows.
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

        // Pooled items this view currently holds; with the pool's readyCount
        // it defines the window cap at any instant.
        property int acquiredCount: 0
        // The boost asks for readyCount, which every dressing drains — the
        // need must ratchet down with each dressed row or the pool builds
        // the whole shortfall again on top of it.
        onAcquiredCountChanged: {
            if (d.initialFillActive)
                d.boostInitial()
        }
        // Shell asked for an item the pool could not hand out. Warm paging
        // must never starve — a nonzero delta over a scroll session means the
        // release-before-acquire ordering broke.
        property int starvedCount: 0

        function poolHeadroom() {
            return root.rowPool ? root.rowPool.readyCount(d.rowPoolKind) : 0
        }

        // Pool sizing: two viewports' worth of rows at the observed row
        // height (48px until measured), clamped; setTarget is grow-only.
        readonly property int poolTarget: {
            const rowHeight = d.avgRowHeight > 0 ? d.avgRowHeight : 48
            return Math.min(80, Math.max(24, Math.ceil(chatLogView.height / rowHeight) * 2))
        }
        onPoolTargetChanged: d.applyPoolTarget()

        function applyPoolTarget() {
            if (root.rowPool)
                root.rowPool.setTarget(d.rowPoolKind, d.poolTarget)
        }

        // Initial fill runs as one staged batch: the skeleton holds until a
        // viewport-estimate's worth of rows are dressed, then everything
        // admitted so far reveals in a single frame.
        property bool initialFillActive: false
        readonly property int initialRevealTarget: Math.max(1, Math.ceil(
            chatLogView.height / (d.avgRowHeight > 0 ? d.avgRowHeight : 48)))

        function stageExistingShells() {
            for (let i = 0; i < chatLogView.count; ++i) {
                const shell = chatLogView.itemAtRow(i)
                if (!shell || d.stagedShells.indexOf(shell) >= 0)
                    continue
                shell.revealed = false
                d.stageShell(shell)
            }
        }

        function readyStagedCount() {
            let n = 0
            for (let i = 0; i < d.stagedShells.length; ++i) {
                if (d.stagedShells[i].contentReady)
                    ++n
            }
            return n
        }

        // Widens the opening window toward its initial size as the pool
        // fills; every admitted row joins the initial batch.
        function growInitialWindow() {
            if (!d.initialFillActive || !d.dressActive)
                return
            const target = Math.min(d.initialWindowSize, Math.max(1, d.historyCount)) - 1
            const cap = d.windowStart
                        + Math.max(1, d.acquiredCount + d.poolHeadroom()) - 1
            const end = Math.min(target, cap)
            if (end > d.windowEnd) {
                d.admitStaged(function() {
                    d.windowEnd = end
                })
            }
        }

        function boostInitial() {
            if (!root.rowPool || !d.initialFillActive)
                return
            const wanted = Math.min(d.initialRevealTarget, Math.max(1, d.historyCount))
            root.rowPool.boost(d.rowPoolKind, Math.max(0, wanted - d.acquiredCount))
        }

        // ---- Paced dressing: staged shells bind a few per event-loop turn,
        // inside a frame budget, so a chat switch never rebinds the whole
        // window inside one input event.
        property var dressQueue: []
        property bool drainScheduled: false

        // ---- Scroll gate (issue 0010 follow-up): a fast fling holds
        // dressing exactly like a panel switch — a dress blows the frame
        // when motion makes dropped frames most visible. Velocity-only:
        // `moving` stays true through the whole deceleration tail and a
        // resting finger mid-drag must dress. Hysteresis (enter high, exit
        // low) keeps the gate from flapping around one threshold.
        readonly property real fastScrollEnterVelocity: chatLogView.height
        readonly property real fastScrollExitVelocity: chatLogView.height * 0.4
        property bool fastScroll: false

        function updateScrollGate(speed) {
            if (!d.fastScroll && speed > d.fastScrollEnterVelocity)
                d.fastScroll = true
            else if (d.fastScroll && speed < d.fastScrollExitVelocity)
                d.fastScroll = false
        }

        // Either hold input gates the drain; both must clear to dress.
        readonly property bool dressHeld: root.dressHold || d.fastScroll
        onDressHeldChanged: {
            if (!d.dressHeld && d.dressQueue.length)
                d.scheduleDrain()
        }

        // ---- Scroll freeze (issue 0013): content geometry never mutates
        // while the view is in motion — drag, fling and the whole
        // deceleration tail. Slides, reveals and placeholder resizes wait
        // for rest; fetches, model assimilation and dress-queueing stay
        // free. Deliberately broader than the velocity gate above: any
        // programmatic contentY correction cancels an active flick, so the
        // geometry underneath the physics must simply not change.
        // Includes the scrollbar drag (issue 0022): dragging the scrollbar
        // scrubs through placeholder space exactly like a fling does, so the
        // same freeze must cover it and the release must settle — including
        // the teleport. The Flickable itself never reports a scrollbar drag
        // as motion, hence externallyMoving below.
        readonly property bool viewMoving: chatLogView.inMotion

        onViewMovingChanged: {
            if (!d.viewMoving)
                d.settleAfterMotion()
        }

        // A staged batch that completed mid-motion; revealed at settle.
        property bool revealOnRest: false

        // Per-side placeholder estimates: top covers the history above the
        // window, bottom the recent rows below it — never each other, so a
        // slide resizes only the end it moved (the coupled max() height is
        // what made the bottom placeholder pop into the viewport mid-fling
        // and ping-pong the window). Floored at a viewport only while that
        // side pages, because the height doubles as the paging trigger depth.
        // The rows a placeholder stands for. Dense mode knows the real count
        // — the model holds one row per stored message — so each placeholder
        // covers exactly the rows on its own side and the scrollbar is
        // proportionally honest across the whole history. The legacy model
        // holds only what was paged in, so its span stays capped: an
        // uncapped estimate over a history it cannot see would be a guess
        // dressed up as a measurement.
        readonly property int placeholderSpanCap: d.denseMode ? d.historyCount : 300

        function placeholderRows(remaining) {
            return Math.min(Math.max(0, remaining), d.placeholderSpanCap)
        }

        readonly property real liveTopPlaceholderHeight: {
            const rows = d.placeholderRows(d.historyCount - 1 - d.windowEnd)
            const estimate = rows * (d.avgRowHeight || 48)
            const active = d.olderMessagesAvailable || d.stagedCount > 0
            return Math.max(active ? chatLogView.height : 0, estimate)
        }
        readonly property real liveBottomPlaceholderHeight: {
            const estimate = d.placeholderRows(d.windowStart)
                             * (d.avgRowHeight || 48)
            return Math.max(d.windowStart > 0 ? chatLogView.height : 0,
                            estimate)
        }

        // What the view actually gets: latched while in motion, following
        // the live estimates at rest.
        property real topPlaceholderHeight: 0
        property real bottomPlaceholderHeight: 0

        onLiveTopPlaceholderHeightChanged: d.updatePlaceholderHeights()
        onLiveBottomPlaceholderHeightChanged: d.updatePlaceholderHeights()

        function updatePlaceholderHeights() {
            if (d.viewMoving)
                return
            d.topPlaceholderHeight = d.liveTopPlaceholderHeight
            d.bottomPlaceholderHeight = d.liveBottomPlaceholderHeight
        }

        // The viewport top's estimated history row while it sits inside the
        // top placeholder: pixel depth ÷ avgRowHeight past the window's
        // history end — the same estimate the scrollbar renders, so the
        // landing is self-consistent — exactly the oldest loaded row at the
        // placeholder's far edge. -1 outside the placeholder.
        function scrollTargetRow() {
            const depth = chatLogView.viewportDepthIntoTopPlaceholder()
            if (depth <= 0 || d.historyCount === 0)
                return -1
            if (depth >= d.topPlaceholderHeight - 1)
                return d.historyCount - 1
            if (d.denseMode) {
                // rank-exact: the placeholder stands for a known number of
                // rows, so the fraction of it above the viewport IS the
                // index, whatever the pixel extent turned out to be. Only
                // the extent is estimated, never which row.
                const rows = Math.max(0, d.historyCount - 1 - d.windowEnd)
                const span = Math.max(1, d.topPlaceholderHeight)
                return Math.min(d.historyCount - 1,
                                d.windowEnd + Math.round(depth / span * rows))
            }
            const rowHeight = d.avgRowHeight > 0 ? d.avgRowHeight : 48
            return Math.min(d.historyCount - 1,
                            d.windowEnd + Math.round(depth / rowHeight))
        }

        // The same mapping for the recent end: the viewport bottom inside the
        // bottom placeholder names an index below the window. Dense only —
        // the legacy bottom placeholder is capped and cannot be read this
        // way. -1 outside the placeholder.
        function scrollTargetRowBelow() {
            if (!d.denseMode || d.windowStart <= 0)
                return -1
            const depth = chatLogView.viewportDepthIntoBottomPlaceholder()
            if (depth <= 0)
                return -1
            if (depth >= d.bottomPlaceholderHeight - 1)
                return 0
            const span = Math.max(1, d.bottomPlaceholderHeight)
            return Math.max(0, d.windowStart
                               - Math.round(depth / span * d.windowStart))
        }

        // Settle: everything motion deferred happens here. Capture first,
        // then mutate — the teleport target must be read from the frozen
        // geometry before the placeholder heights unlatch.
        function settleAfterMotion() {
            const target = d.scrollTargetRow()
            const targetBelow = d.scrollTargetRowBelow()
            d.updatePlaceholderHeights()
            const mayTeleport = d.dressActive && !d.initialFillActive
                              && !d.pendingRestore
            if (mayTeleport && target > d.windowEnd + d.windowChunkSize
                    && d.teleportToRow(target)) {
                d.revealOnRest = false
                return
            }
            // the recent side: scrubbing back down out-runs the window just
            // as readily as scrolling up out of it
            if (mayTeleport && targetBelow >= 0
                    && targetBelow < d.windowStart - d.windowChunkSize
                    && d.teleportToRow(targetBelow)) {
                d.revealOnRest = false
                return
            }
            if (d.revealOnRest) {
                d.revealOnRest = false
                d.checkStagedReady()
            }
        }

        // Teleport slide: the viewport out-scrolled the window by more than
        // a chunk, so instead of unrolling every chunk in between the whole
        // window releases and re-admits at the target through the window
        // record restore path, which pins the viewport to the target row at
        // the atomic reveal — never a raw contentY write.
        function teleportToRow(targetIndex) {
            // the row is named by its key, which every row has: a dummy's key
            // is positional, which is exactly what a landing inside a hole
            // needs to pin on until the fill replaces it
            const id = SQUtils.ModelUtils.get(d.windowSource, targetIndex,
                                              d.denseMode ? "key" : "id")
            if (id === undefined || id === null)
                return false
            // landing inside a hole: the window admits the dummies (skeleton
            // until they dress) and the page for that rank is requested
            d.fetchAtRankIfHole(targetIndex)
            const span = Math.max(1, d.windowEnd - d.windowStart + 1)
            d.windowAtInitial = false
            // same chat, same session: the restore's fetch-guard reset does
            // not apply — a fetch already fired for this history count must
            // not repeat until it actually grows the history
            const lastFetch = d.lastFetchHistoryCount
            d.restoreWindow(targetIndex,
                            { oldestRowId: String(id), span: span, offset: 0 })
            d.lastFetchHistoryCount = lastFetch
            return true
        }

        // ---- Holes (issue 0022) ----
        // The rank whose page is being fetched, -1 when none is. One request
        // at a time: a scrub through a long hole would otherwise fire one per
        // settle. Released by messagesWindowLoaded, whatever its outcome.
        property int pendingRankFetch: -1

        function fetchAtRankIfHole(targetIndex) {
            if (!d.denseMode || d.pendingRankFetch >= 0)
                return
            if (SQUtils.ModelUtils.get(d.windowSource, targetIndex, "loaded"))
                return
            const rank = d.historyCount - 1 - targetIndex
            if (rank < 0)
                return
            d.pendingRankFetch = rank
            root.messageStore.loadMessagesAtRank(rank)
        }

        // The rows the dense model must keep loaded. Deferred, so a slide
        // that writes both bounds publishes once.
        property bool denseWindowPublishScheduled: false

        function scheduleDenseWindowPublish() {
            if (!d.denseMode || d.denseWindowPublishScheduled)
                return
            d.denseWindowPublishScheduled = true
            Qt.callLater(d.publishDenseWindow)
        }

        function publishDenseWindow() {
            d.denseWindowPublishScheduled = false
            if (!d.denseMode)
                return
            root.messageStore.setDenseWindow(d.windowStart, d.windowEnd,
                                             d.windowChunkSize)
        }

        onWindowStartChanged: d.scheduleDenseWindowPublish()
        onWindowEndChanged: d.scheduleDenseWindowPublish()

        // Rows a trade may evict: rows fully outside the viewport on the
        // evicted side. The "a viewport's worth survives" size cap assumes
        // the viewport rides the slide's leading edge; after a teleport it
        // sits at the window's history end, where an unguarded recent-trade
        // evicts the very rows being read and the window walks away from
        // the viewport. A viewport anchored to the newest message is not
        // free-floating — the anchor re-pins it, so nothing needs guarding.
        function tradableRows(fromRecentEnd) {
            if (chatLogView.stickingToNewest)
                return d.maxWindowSize
            let rows = 0
            for (let i = 0; i < chatLogView.count; ++i) {
                const item = chatLogView.itemAtRow(i)
                if (!item || !item.visible || item.height <= 0)
                    continue
                const y = item.mapToItem(chatLogView.contentItem, 0, 0).y
                if (fromRecentEnd) {
                    if (y >= chatLogView.contentY + chatLogView.height)
                        ++rows
                } else if (y + item.height <= chatLogView.contentY) {
                    ++rows
                }
            }
            return rows
        }

        // Eager history prefetch: fetching is pure I/O and stays free during
        // motion. While the viewport scrolls through the placeholder toward
        // the loaded-history end, fire the fetch early so the settle usually
        // finds its rows already loaded. The lastFetchHistoryCount guard
        // blocks repeats until the fetch actually grows the history.
        function prefetchHistoryAhead() {
            if (!d.viewMoving)
                return
            if (root.rootStore.loadingHistoryMessagesInProgress
                    || d.historyExhausted || !d.mayFetchMoreHistory)
                return
            const depth = chatLogView.viewportDepthIntoTopPlaceholder()
            if (depth <= 0)
                return
            const rowHeight = d.avgRowHeight > 0 ? d.avgRowHeight : 48
            if (d.windowEnd + depth / rowHeight
                    < d.historyCount - 1 - d.windowChunkSize)
                return
            d.lastFetchHistoryCount = d.historyCount
            messageStore.loadMoreMessages()
        }

        function enqueueDress(shell) {
            if (d.dressQueue.indexOf(shell) === -1)
                d.dressQueue.push(shell)
            d.scheduleDrain()
        }

        function scheduleDrain() {
            if (d.drainScheduled)
                return
            d.drainScheduled = true
            Qt.callLater(d.drainDressQueue)
        }

        function dequeueDress(shell) {
            const i = d.dressQueue.indexOf(shell)
            if (i !== -1)
                d.dressQueue.splice(i, 1)
        }

        // Drain order: viewport-nearest-first, so the skeleton clears where
        // the user is looking. Undressed shells hold no geometry (invisible,
        // zero height), so distance is counted in rows from a reference row
        // resolved fresh at every slice — never from insertion order.
        function dressReferenceRow() {
            if (d.pendingRestore) {
                // restoring mid-history: the record's offset is the viewport
                // top's distance below the window's top row (the highest
                // proxy row); estimate the rows above the viewport center at
                // the running average height
                const rowHeight = d.avgRowHeight > 0 ? d.avgRowHeight : 48
                const rowsAbove = (d.pendingRestore.offset
                                   + chatLogView.height / 2) / rowHeight
                return Math.max(0, Math.round(
                                    d.windowEnd - d.windowStart - rowsAbove))
            }
            // fresh open and every bottom-pinned view: row 0 is the bottom
            if (chatLogView.stickingToNewest)
                return 0
            // mid-history without a restore in flight: the dressed rows
            // still on screen locate the viewport
            const center = chatLogView.contentY + chatLogView.height / 2
            let best = 0
            let bestDistance = Number.MAX_VALUE
            for (let i = 0; i < chatLogView.count; ++i) {
                const item = chatLogView.itemAtRow(i)
                if (!item || !item.visible || item.height <= 0)
                    continue
                const distance = Math.abs(center - item.mapToItem(
                                     chatLogView.contentItem,
                                     0, item.height / 2).y)
                if (distance < bestDistance) {
                    bestDistance = distance
                    best = i
                }
            }
            return best
        }

        function sortDressQueue() {
            if (d.dressQueue.length < 2)
                return
            const ref = d.dressReferenceRow()
            d.dressQueue.sort((a, b) => Math.abs(a.index - ref)
                                        - Math.abs(b.index - ref))
        }

        function drainDressQueue() {
            d.drainScheduled = false
            // an un-dressed view must never take items — whatever is queued
            // belongs to a closing window and dies with it
            if (!d.dressActive) {
                d.dressQueue = []
                return
            }
            // held: the queue keeps accumulating, release restarts the drain
            if (d.dressHeld)
                return
            // at most one dress per slice: a single dress already fills a
            // frame on the devices this paces for, and the callLater chain
            // yields to rendering between slices
            d.sortDressQueue()
            while (d.dressQueue.length) {
                const shell = d.dressQueue.shift()
                if (!shell || shell.retired || !shell.pooled
                        || shell.pooledItem)
                    continue
                shell.doAcquire()
                break
            }
            if (d.dressQueue.length)
                d.scheduleDrain()
        }

        function noteStarvedShell(shell) {
            if (!root.rowPool)
                return
            d.starvedCount++
            if (d.initialFillActive) {
                d.boostInitial()
                return
            }
            // a live row (outside any batch) must never wait on a dry pool:
            // trimming the far end frees an item for it right now
            if (shell.revealed)
                Qt.callLater(d.trimFarEndForLiveRow)
            root.rowPool.boost(d.rowPoolKind, 1)
        }

        function trimFarEndForLiveRow() {
            if (d.poolHeadroom() > 0)
                return
            // deferred, so re-check that a live row is still waiting: a stale
            // trim (the shell was served or destroyed meanwhile) would evict
            // the far end of a window someone else just rebuilt — a restore
            // legitimately holds the whole pool
            let waiting = false
            for (let i = 0; i < chatLogView.count; ++i) {
                const shell = chatLogView.itemAtRow(i)
                if (shell && shell.revealed && shell.pooled
                        && !shell.pooledItem && !shell.retired) {
                    waiting = true
                    break
                }
            }
            if (!waiting)
                return
            const trimmed = Math.min(d.windowEnd, d.historyCount - 1) - 1
            if (trimmed >= d.windowStart)
                d.windowEnd = trimmed
        }

        // Everything a pooled MessageView needs beyond its row data — the
        // per-chat context the inline delegate used to bind. Set as bindings
        // at acquire (several change live, e.g. joined, isChatBlocked) and
        // broken again at release so no binding reaches back into this view
        // from the app-wide pool.
        readonly property var pooledViewContext: [
            "rootStore", "messageStore", "channelEmoji", "emojiPopup",
            "stickersPopup", "chatLogView", "chatContentModule",
            "formatBalance", "usersModel", "isChatBlocked", "joined",
            "sendViaPersonalChatEnabled", "messageLinkSharingEnabled",
            "disabledTooltipText", "areTestNetworksEnabled",
            "extraLeftPadding", "chatId", "myPublicKey",
            "gifUnfurlingEnabled", "neverAskAboutUnfurlingAgain",
            "stickersLoaded"]

        function dressPooledView(view, shell) {
            view.objectName = "chatMessageViewDelegate"
            view.width = Qt.binding(() => shell.width)
            for (let i = 0; i < d.pooledViewContext.length; ++i) {
                const prop = d.pooledViewContext[i]
                view[prop] = Qt.binding(() => root[prop])
            }
            view.createMessageLink = (chatId, messageId) =>
                root.messageStore.createMessageLink(chatId, messageId)
            view.mentionsMap = Qt.binding(() => mentionResolver.resolveFor(
                view.unparsedText + " " + view.quotedMessageUnparsedText))
        }

        function undressPooledView(view) {
            // a plain self-assignment breaks the binding without disturbing
            // the value; the rebind on the next acquire is the reset
            view.width = view.width
            for (let i = 0; i < d.pooledViewContext.length; ++i) {
                const prop = d.pooledViewContext[i]
                view[prop] = view[prop]
            }
            view.mentionsMap = ({})
        }

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

        // The space a dummy row holds. Follows the same running average, and
        // that average only moves at rest (reveals are frozen during motion),
        // so dummy rows never resize mid-fling.
        readonly property real dummyRowHeight: d.avgRowHeight > 0 ? d.avgRowHeight : 48

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
                const id = d.stagedRowId(i)
                if (id !== undefined && id !== null)
                    d.stagedIds.add(id)
            }
            d.syncStagedCount()
        }

        // What a staged row is tracked by. Dense rows are named by their key
        // (message ids are empty until a hole fills), and a dummy is not
        // staged at all: it has nothing to build, so it must never hold a
        // batch open — it shows its skeleton the moment it is admitted.
        function stagedRowId(row) {
            if (!d.denseMode)
                return SQUtils.ModelUtils.get(messagesWindow, row, "messageId")
            if (!SQUtils.ModelUtils.get(messagesWindow, row, "loaded"))
                return null
            return SQUtils.ModelUtils.get(messagesWindow, row, "key")
        }

        // A staged row leaving the window before its shell was ever created
        // must not hold the batch open.
        function dropStagedRows(first, last) {
            if (d.stagedIds.size === 0)
                return
            let dropped = false
            for (let i = first; i <= last; ++i) {
                const id = d.stagedRowId(i)
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
            // a shell joining the batch is build progress: re-arm the stall
            // detector (the initial fill has no admit call to arm it)
            revealTimeout.restart()
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
            // the initial batch does not wait for the whole window: one
            // atomic reveal at a viewport-worth of dressed rows, stragglers
            // pop in on their own completion above the viewport. Never fall
            // through to the all-staged-ready path — the window is still
            // growing, so "all ready" holds trivially at any partial count
            // (the stall detector below covers a pool that stops producing)
            if (d.initialFillActive) {
                const wanted = Math.min(d.initialRevealTarget,
                                        Math.max(1, d.historyCount))
                if (d.readyStagedCount() >= wanted)
                    d.revealStaged()
                else
                    revealTimeout.restart()
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
            d.revealOnRest = false
            revealTimeout.stop()
        }

        // Reveals whatever is staged — normally a complete batch, on timeout
        // a partial one (better than wedging paging on a pathological row).
        function revealStaged() {
            revealTimeout.stop()
            // scroll freeze: a batch completing mid-motion holds its atomic
            // reveal until rest — the skeleton keeps covering it
            if (d.viewMoving) {
                d.revealOnRest = true
                return
            }
            if (d.initialFillActive) {
                d.initialFillActive = false
                if (root.rowPool)
                    root.rowPool.clearBoost(d.rowPoolKind)
            }
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
            if (d.pendingRestore)
                d.applyPendingRestore()
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
            if (!d.windowAtInitial)
                return
            if (d.usePool) {
                d.growInitialWindow()
                return
            }
            if (d.initialWindowSize - 1 > d.windowEnd)
                d.windowEnd = d.initialWindowSize - 1
        }

        readonly property int historyCount: d.windowSource ? d.windowSource.count : 0

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
            pendingRestore = null
            windowStart = 0
            initialFillActive = false
            if (d.usePool) {
                if (d.dressActive) {
                    initialFillActive = true
                    // clamped to the history: an end past the last row makes
                    // every later correction churn the tail row through
                    // remove/reinsert, spawning dying shells
                    windowEnd = Math.max(0, Math.min(
                                    initialWindowSize,
                                    Math.max(1, d.acquiredCount + d.poolHeadroom()),
                                    Math.max(1, d.historyCount)) - 1)
                    d.boostInitial()
                    // shells born before this dress (construction-time window,
                    // async creation) join the initial batch instead of
                    // popping in one by one ahead of the atomic reveal
                    d.stageExistingShells()
                } else {
                    closeWindow()
                }
            } else {
                windowEnd = initialWindowSize - 1
            }
            windowAtInitial = true
            lastFetchHistoryCount = -1
        }

        function slideWindowToHistory(allowTrade = true) {
            // one batch at a time: the paging timer keeps asking while the
            // placeholder shows, and the next chunk must wait for this one.
            // Frozen in motion: no slide may start until the view rests.
            if (d.stagedCount > 0 || d.initialFillActive || !d.dressActive
                    || d.viewMoving)
                return

            if (d.windowEnd < d.historyCount - 1) {
                if (d.usePool) {
                    // only as many rows as the pool can dress, and the recent
                    // end releases before the history end acquires, so a
                    // slide can never over-subscribe the pool; a viewport's
                    // worth of rows always survives it, so what the user is
                    // looking at never leaves the window mid-slide. A trade
                    // evicts the recent end — forbidden while the viewport is
                    // pinned there (allowTrade false), or the exhausted-pool
                    // prefetch would evict the very rows being looked at and
                    // ping-pong against the slide back
                    const headroom = d.poolHeadroom()
                    const wanted = Math.min(d.historyCount - 1 - d.windowEnd,
                                            d.windowChunkSize)
                    const grow = Math.min(wanted, headroom)
                    const size = d.windowEnd - d.windowStart + 1
                    const slide = allowTrade
                                ? Math.min(wanted - grow,
                                           Math.max(0, size - d.initialRevealTarget),
                                           d.tradableRows(true))
                                : 0
                    if (grow + slide === 0) {
                        // dry and nothing to trade: grow the pool instead of
                        // spinning on the paging timer
                        root.rowPool.boost(d.rowPoolKind, 1)
                        return
                    }
                    d.windowAtInitial = false
                    d.admitStaged(function() {
                        d.windowStart += slide
                        d.windowEnd += grow + slide
                    })
                    return
                }
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
            if (d.stagedCount > 0 || d.windowStart <= 0
                    || d.initialFillActive || !d.dressActive || d.viewMoving)
                return

            if (d.usePool) {
                const headroom = d.poolHeadroom()
                const wanted = Math.min(d.windowStart, d.windowChunkSize)
                const grow = Math.min(wanted, headroom)
                const size = d.windowEnd - d.windowStart + 1
                const slide = Math.min(wanted - grow,
                                       Math.max(0, size - d.initialRevealTarget),
                                       d.tradableRows(false))
                if (grow + slide === 0) {
                    root.rowPool.boost(d.rowPoolKind, 1)
                    return
                }
                d.admitStaged(function() {
                    d.windowEnd -= slide
                    d.windowStart -= grow + slide
                })
                return
            }

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

        // Deferred so the proxy churn of an attach settles first — but a
        // jump issued meanwhile wins: the stale reposition must not yank
        // the view back to the bottom.
        property bool pendingPositionAtNewest: false

        function schedulePositionAtNewest() {
            d.pendingPositionAtNewest = true
            Qt.callLater(d.applyScheduledPositionAtNewest)
        }

        function applyScheduledPositionAtNewest() {
            if (!d.pendingPositionAtNewest)
                return
            d.pendingPositionAtNewest = false
            chatLogView.positionAtNewest()
        }

        function goToMessage(messageIndex) {
            d.pendingPositionAtNewest = false
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
            // an explicit jump to the bottom outranks a restore in flight
            d.pendingRestore = null
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

    // Index-shift invariant (issue 0022): the window's bounds move with every
    // source insert or removal that shifts the rows the window selects, in the
    // same event-loop turn as the model change, so the window's CONTENT — its
    // message ids — never changes implicitly. Only slide, teleport and admit
    // change content. The single place this is applied is d.applyIndexShift.
    Connections {
        target: d.windowSource

        function onRowsInserted(parent, first, last) {
            d.applyIndexShift(first, last, true)
            if (first <= d.windowEnd)
                Qt.callLater(d.refilterWindow)
            Qt.callLater(d.updateHistoryExhausted)
        }

        function onRowsRemoved(parent, first, last) {
            d.applyIndexShift(first, last, false)
            if (first <= d.windowEnd)
                Qt.callLater(d.refilterWindow)
            Qt.callLater(d.updateHistoryExhausted)
        }
    }

    // The opening window widens with the pool: every item the boosted pool
    // finishes lets the initial batch admit one more row.
    Connections {
        target: root.rowPool

        function onAvailabilityChanged(kind, readyCount) {
            // deferred: a release fired from the window proxy's own
            // rowsAboutToBeRemoved must not grow the window while the
            // IndexFilter is mid-update (binding loop on maximumIndex)
            if (kind === d.rowPoolKind && readyCount > 0)
                Qt.callLater(d.growInitialWindow)
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

        onTriggered: {
            d.revealStaged()
        }
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
            // the marker scroll racing a restore: in-session the record wins
            if (d.pendingRestore)
                return
            d.goToMessage(messageIndex)
        }
    }

    // A window page answered (issue 0021): the rows arrive as dataChanged on
    // the dense model and dress through the paced queue from there — all this
    // has to do is let the next hole be requested. Its own block because the
    // signal only exists on the dense-model build of the message module;
    // every other host legitimately has no such signal to connect to.
    Connections {
        target: d.denseMode ? root.messageStore.messageModule : null
        ignoreUnknownSignals: true

        function onMessagesWindowLoaded(anchorIndex, error) {
            d.pendingRankFetch = -1
        }
    }

    Connections {
        target: root.messageStore

        function onMessageSearchOngoingChanged() {
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        function onLoadingChanged() {
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
            if (!messageStore.loading && chatLogView.stickingToNewest
                    && !d.pendingRestore) {
                Qt.callLater(d.scrollToBottom)
            }
        }
    }

    Connections {
        target: !!d.chatDetails ? d.chatDetails : null

        function onActiveChanged() {
            if (active && chatLogView.stickingToNewest && !d.pendingRestore) {
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
        // Latched while the view is in motion (scroll freeze).
        topPlaceholderHeight: d.topPlaceholderHeight
        bottomPlaceholderHeight: d.bottomPlaceholderHeight

        // Page one viewport ahead of the scroll so a batch is usually
        // revealed before its placeholder is ever seen.
        prefetchMargin: chatLogView.height

        // A scrollbar drag is a move the Flickable cannot see. Dense only:
        // the legacy placeholder is capped, so its scrollbar position does
        // not name a history position and a settle there would teleport to a
        // row the user never aimed at.
        externallyMoving: d.denseMode && verticalScrollBar.pressed

        onMoreUpRequested: d.slideWindowToHistory(!chatLogView.stickingToNewest)
        onMoreDownRequested: d.slideWindowToRecent()

        onVerticalVelocityChanged: d.updateScrollGate(Math.abs(verticalVelocity))
        onContentYChanged: d.prefetchHistoryAhead()

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

            // Roles renamed to MessageView's property names, so pointing a
            // pooled MessageView at a row is a plain per-role bulk assign
            // (RowBinder) with no per-role glue.
            sourceModel: RolesRenamingModel {
                sourceModel: d.viewCompleted && !messageStore.loading
                             ? d.windowSource : null
                onSourceModelChanged: {
                    // whatever the paging timer did against the detached
                    // window, the view opens on the chat's window record —
                    // or the newest message without one
                    if (sourceModel)
                        d.openWindow()
                    else
                        d.resetWindow()
                    d.updateHistoryExhausted()
                }

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

            filters: IndexFilter {
                minimumIndex: d.windowStart
                maximumIndex: d.windowEnd
            }

            // Declared on the model itself so these connections run before the
            // Repeater's: a synchronously created shell must already find its
            // id captured. Leaving rows hand their pooled items back HERE —
            // the Repeater destroys delegates through deleteLater, which
            // would defer the release past the acquires of the same slide.
            onRowsInserted: (parent, first, last) => d.captureStagedRows(first, last)
            onRowsAboutToBeRemoved: (parent, first, last) => {
                d.dropStagedRows(first, last)
                for (let i = first; i <= last; ++i) {
                    const shell = chatLogView.itemAtRow(i)
                    if (shell && shell.retire)
                        shell.retire()
                }
            }
            // A model swap (chat switch) resets instead of removing rows:
            // the whole window must retire the same way, or the outgoing
            // shells — alive until their deferred destruction — keep their
            // availability connections and steal every item the dying
            // window releases, starving the incoming chat's shells for good.
            onModelAboutToBeReset: {
                // the outgoing rows still hold their geometry: the window
                // record must be taken before they retire
                d.captureWindowRecord()
                for (let i = 0; i < chatLogView.count; ++i) {
                    const shell = chatLogView.itemAtRow(i)
                    if (shell && shell.retire)
                        shell.retire()
                }
            }

            onCountChanged: d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        ScrollBar.vertical: StatusScrollBar {
            id: verticalScrollBar

            visible: chatLogView.contentHeight > chatLogView.height
        }

        // The shell never builds real message content: it acquires a
        // pre-built MessageView from the row pool and RowBinder points it at
        // the shell's row (in-window ⇔ holds a pooled item). Rare kinds and
        // pool-less hosts fall back to the inline async Loader, whose
        // component must stay inline — an external one would lose the model
        // roles' context.
        delegate: Item {
            id: shell

            // Declared (not context-injected) so index carries a change
            // signal: it dropping to -1 is the only removal signal a
            // shrink-removed shell gets (see retire below)
            required property int index
            required property var model

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
            implicitHeight: {
                if (showsSkeleton)
                    return d.dummyRowHeight
                return contentItem ? contentItem.height : 0
            }

            // Dense mode: a row the window admitted before its data was
            // fetched. It holds a row of skeleton — never an empty gap, or
            // the fill would move everything below it — and dresses through
            // the ordinary paced queue the moment its roles arrive.
            readonly property bool rowLoaded: !d.denseMode || model.loaded === true

            // Held from the fill until the dress produces content, so the
            // hole closing costs no geometry beyond the row's own height.
            property bool skeletonHeld: false
            readonly property bool showsSkeleton: d.denseMode
                                                  && (!rowLoaded || skeletonHeld)

            // Reactive on the deleted flag: a row deleted mid-life hands its
            // pooled item back and turns into an on-demand row.
            readonly property bool pooled: rowLoaded && !!root.rowPool
                                           && !model.deleted
                                           && d.isPooledContentType(model.messageContentType)
            property Item pooledItem: null
            readonly property Item contentItem: pooledItem ?? inlineLoader.item

            // test seam (fallback mode): deactivating wedges the row's build
            property alias active: inlineLoader.active

            // Content being present only means the MessageView *instance*
            // exists — MessageView is itself a Loader whose content keeps
            // incubating (with a 50px fallback height). A row is only ready
            // once that inner content is fully built and measured; a content
            // type without a component (inner status Null) is ready as is.
            readonly property bool contentReady: {
                // a dummy is complete as it stands — its skeleton is what it
                // has to show — so it never holds a staged batch open
                if (!rowLoaded)
                    return true
                if (pooled)
                    return !!pooledItem && pooledItem.status !== Loader.Loading
                return inlineLoader.status === Loader.Ready && inlineLoader.item
                       && inlineLoader.item.status !== Loader.Loading
            }

            // Rows admitted by a staged slide hold no visual space until the
            // whole batch is ready; everything else shows as soon as it is
            // ready itself. A row that is still loading is never shown.
            property bool revealed: false
            visible: revealed && (contentReady || showsSkeleton)

            readonly property string messageId: model.messageId

            // What names this row across a rebuild. Dense rows have a key of
            // their own — positional while the row is a dummy — so a teleport
            // into a hole still has something to pin on.
            readonly property string rowKey: d.denseMode ? String(model.key)
                                                         : String(model.messageId)

            function startMessageFoundAnimation() {
                if (contentItem)
                    contentItem.startMessageFoundAnimation()
            }

            // On its way out of the window: the item is already released and
            // must not be re-acquired while the deferred destruction runs.
            // Rows removed by a window shrink die the same deferred death as
            // reset rows but never see retire() — the index dropping to -1 is
            // their only signal, and without it they steal every released
            // item through the still-armed availability connection.
            property bool retired: false
            onIndexChanged: {
                if (index < 0)
                    retire()
            }

            function retire() {
                retired = true
                d.dequeueDress(shell)
                releasePooled()
            }

            // Every dress goes through the paced queue: a rebind rebuilds the
            // message's inner content (text blocks, previews), one costs a
            // whole frame on a low-end device, and any trigger (availability,
            // reveal, slide, restore, live insert) can fire for a window's
            // worth of shells in one turn. The drain is doAcquire's only
            // caller — nothing dresses inside a signal handler.
            function tryAcquire() {
                if (!pooled || pooledItem || retired || !root.rowPool)
                    return
                d.enqueueDress(shell)
            }

            // Guards the pool's availability cascade re-entering THIS shell
            // while its acquisition is mid-flight (pooledItem not yet set):
            // unguarded, one shell drains the whole pool into orphans.
            property bool acquiring: false

            function doAcquire() {
                if (acquiring || !pooled || pooledItem || retired
                        || !root.rowPool || !d.dressActive)
                    return
                acquiring = true
                const item = root.rowPool.acquire(d.rowPoolKind)
                if (!item) {
                    acquiring = false
                    d.noteStarvedShell(shell)
                    return
                }
                d.dressPooledView(item, shell)
                rowBinder.target = item
                rowBinder.bind(messagesWindow, index)
                item.parent = shell
                // last: the signal relay below only attaches to a fully
                // dressed and bound item, so the rebind writes cannot fire
                // stale intent signals
                pooledItem = item
                acquiring = false
                d.acquiredCount++
            }

            function releasePooled() {
                if (!pooledItem)
                    return
                const item = pooledItem
                pooledItem = null
                // accounting and the pool hand-back first: on a shell dying in
                // a destruction cascade the binder child may already be gone,
                // and a throw past this point would leak the item for good
                // (exceptions in onDestruction vanish silently)
                d.acquiredCount--
                d.undressPooledView(item)
                if (root.rowPool)
                    root.rowPool.release(item)
                if (rowBinder) {
                    rowBinder.detach()
                    rowBinder.target = null
                }
            }

            onPooledChanged: {
                if (pooled)
                    tryAcquire()
                else
                    releasePooled()
            }

            RowBinder {
                id: rowBinder
            }

            // A shell that found the pool dry dresses itself as soon as an
            // item is released or built.
            Connections {
                target: root.rowPool
                enabled: shell.pooled && !shell.pooledItem && !shell.retired

                function onAvailabilityChanged(kind, readyCount) {
                    if (kind === d.rowPoolKind && readyCount > 0)
                        shell.tryAcquire()
                }
            }

            // Intent relay for the pooled item — the inline component wires
            // these declaratively; dying with the shell keeps the pooled item
            // free of connections into this view after release.
            Connections {
                target: shell.pooledItem

                function onOpenStickerPackPopup(stickerPackId) {
                    root.openStickerPackPopup(stickerPackId)
                }
                function onTokenPaymentRequested(recipientAddress, tokenKey, rawAmount) {
                    root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)
                }
                function onShowReplyArea(messageId, author) {
                    root.showReplyArea(messageId, author)
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
                function onEditModeOnChanged() {
                    root.editModeChanged(shell.pooledItem.editModeOn,
                                         shell.pooledItem.messageId)
                }
                function onVisibleChanged() {
                    if (!shell.pooledItem.visible && shell.pooledItem.editModeOn)
                        root.messageStore.setEditModeOff(shell.pooledItem.messageId)
                }
            }

            // Membership in a staged batch is decided by the captured row id,
            // not by creation timing: under a still-incubating ancestor the
            // shell is created asynchronously, long after the admit returned.
            // The initial fill stages every row for its one atomic reveal.
            Component.onCompleted: {
                // a dummy never joins a batch: it is ready as it stands
                if (rowLoaded && (d.takeStagedId(rowKey) || d.initialFillActive))
                    d.stageShell(this)
                else
                    revealed = true
                tryAcquire()
            }
            Component.onDestruction: {
                d.unstageShell(this)
                d.dequeueDress(this)
                releasePooled()
            }

            onContentReadyChanged: {
                if (contentReady && rowLoaded)
                    skeletonHeld = false
                if (contentReady && !revealed)
                    d.checkStagedReady()
            }

            // The hole closed under this row. Its content is built through
            // the paced queue like every other dress (pooled flips with
            // rowLoaded, which enqueues); the skeleton keeps the row's space
            // until that content is there.
            onRowLoadedChanged: {
                if (rowLoaded && d.denseMode && !contentReady)
                    skeletonHeld = true
            }

            Loader {
                id: dummySkeleton

                width: shell.width
                height: d.dummyRowHeight
                active: shell.showsSkeleton
                visible: active
                sourceComponent: MessageRowSkeleton {}
            }

            Loader {
                id: inlineLoader

                width: shell.width
                asynchronous: true
                // a dummy has no content type yet: building the fallback row
                // for it would render an empty message and then throw it away
                active: !shell.pooled && shell.rowLoaded

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
                    mentionsMap: mentionResolver.resolveFor(model.unparsedText + " " + model.quotedMessageUnparsedText)

                    isChatBlocked: root.isChatBlocked
                    joined: root.joined

                    sendViaPersonalChatEnabled: root.sendViaPersonalChatEnabled
                    messageLinkSharingEnabled: root.messageLinkSharingEnabled
                    createMessageLink: (chatId, messageId) => root.messageStore.createMessageLink(chatId, messageId)
                    disabledTooltipText: root.disabledTooltipText
                    areTestNetworksEnabled: root.areTestNetworksEnabled
                    extraLeftPadding: root.extraLeftPadding

                    chatId: root.chatId
                    messageId: model.messageId
                    communityId: model.communityId
                    responseToMessageWithId: model.responseToMessageWithId
                    senderId: model.senderId
                    senderDisplayName: model.senderDisplayName
                    usesDefaultName: model.usesDefaultName
                    senderOptionalName: model.senderOptionalName
                    senderIsEnsVerified: model.senderIsEnsVerified
                    senderIcon: model.senderIcon
                    senderIsAdded: model.senderIsAdded
                    senderTrustStatus: model.senderTrustStatus
                    compressedKey: model.compressedKey
                    amISender: model.amISender
                    messageText: model.messageText
                    unparsedText: model.unparsedText
                    messageImage: model.messageImage
                    albumMessageImages: model.albumMessageImages
                    albumCount: model.albumCount
                    messageTimestamp: model.messageTimestamp
                    messageOutgoingStatus: model.messageOutgoingStatus
                    resendError: model.resendError
                    messageContentType: model.messageContentType
                    pinnedMessage: model.pinnedMessage
                    messagePinnedBy: model.messagePinnedBy
                    reactionsModel: model.reactionsModel
                    sticker: model.sticker
                    stickerPack: model.stickerPack
                    editModeOn: model.editModeOn
                    onEditModeOnChanged: root.editModeChanged(editModeOn, model.messageId)
                    isEdited: model.isEdited
                    deleted: model.deleted
                    deletedBy: model.deletedBy
                    deletedByContactDisplayName: model.deletedByContactDisplayName
                    deletedByContactIcon: model.deletedByContactIcon
                    linkPreviewModel: model.linkPreviewModel
                    links: model.links
                    paymentRequestModel: model.paymentRequestModel
                    messageAttachments: model.messageAttachments
                    transactionParams: model.transactionParams
                    hasMention: model.hasMention
                    quotedMessageText: model.quotedMessageText
                    quotedMessageUnparsedText: model.quotedMessageUnparsedText
                    quotedMessageFrom: model.quotedMessageFrom
                    quotedMessageContentType: model.quotedMessageContentType
                    quotedMessageDeleted: model.quotedMessageDeleted
                    quotedMessageAuthorDetailsName: model.quotedMessageAuthorDetailsName
                    quotedMessageAuthorDetailsDisplayName: model.quotedMessageAuthorDetailsDisplayName
                    quotedMessageAuthorDetailsThumbnailImage: model.quotedMessageAuthorDetailsThumbnailImage
                    quotedMessageAuthorDetailsEnsVerified: model.quotedMessageAuthorDetailsEnsVerified
                    quotedMessageAuthorDetailsIsContact: model.quotedMessageAuthorDetailsIsContact
                    quotedMessageAlbumMessageImages: model.quotedMessageAlbumMessageImages
                    quotedMessageAlbumImagesCount: model.quotedMessageAlbumImagesCount
                    bridgeName: model.bridgeName

                    gapFrom: model.gapFrom
                    gapTo: model.gapTo

                     // This is possible since we have all data loaded before we load qml.
                     // When we fetch messages to fulfill a gap we have to set them at once.
                     // Also one important thing here is that messages are set in descending order
                     // in terms of `timestamp` of a message, that means a message with the most
                     // recent time is added at index 0.
                    prevMessageIndex: model.prevMessageIndex
                    prevMessageTimestamp: model.prevMessageTimestamp
                    prevMessageSenderId: model.prevMessageSenderId
                    prevMessageContentType: model.prevMessageContentType
                    prevMessageDeleted: model.prevMessageDeleted
                    nextMessageIndex: model.nextMessageIndex
                    nextMessageTimestamp: model.nextMessageTimestamp

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
                        if(!visible && model.editModeOn)
                            messageStore.setEditModeOff(model.messageId)
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
