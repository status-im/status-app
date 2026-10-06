pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import QtModelsToolkit

import StatusQ.Core.Utils as SQUtils

/*
  A view that renders the rows of whatever model it is given, stages what it is
  told to wait for, and holds the viewport still.

  It owns no window, no proxy and no fetch. When a placeholder edge comes into
  reach it asks - moreRequestedTop/Bottom - and whoever owns the data answers
  however it likes: by moving an index window's bounds, or by calling a backend
  that replies much later. Everything that arrives between the request and
  moreLoadedTop/Bottom() is one batch, revealed in a single frame once every row
  of it has content and the heights have stopped moving.

  loadingTop/Bottom belong to the view, set the moment it asks, because the view
  is the only party that knows a request exists. The owner's obligation is one
  call to moreLoadedTop/Bottom() per request - whatever arrived, even nothing.

  batchRevealed() fires inside the reveal, in the same turn: an owner that
  defers removals (an index window trimming its far end) must do them there, or
  the two ends change in different frames and the content height moves twice.

  The owner can open a batch itself: everything that arrives between
  beginBatch() and endBatch() is one batch, staged and revealed the same way,
  whether it arrives inside that pair synchronously or long after from a
  backend. That is how a jump that moves a window gets a batchRevealed() to
  complete in, whether the move replaces every row or only slides some in.

  Position is held in one of two ways, and they do not compete. While a slide is
  in flight a surviving row is anchored and its offset re-applied whenever it
  moves, which is what keeps the content still to the pixel. Outside a slide,
  and only with stickToBottom set, a viewport already at the bottom edge is kept
  there as the content grows. The anchor wins wherever both could apply.

  verticalLayoutDirection renders the rows bottom-up, which is how a chat shows
  a newest-first model. It is done by turning the model upside down on the way
  to the rows and nothing else: the rows arrive in the order they are drawn, so
  no position, band or edge in here is mirrored, and every "top" and "bottom"
  below is the screen's throughout. Only itemAtRow() converts, because it is
  public and speaks the caller's model.

  Row contract: the item handed back must have an intrinsic implicitHeight and
  must not size itself to its parent - a row that does collapses to zero height
  with no warning.
*/

Flickable {
    id: root

    // The rows to render. Whoever owns it also owns what "more" means.
    property var model: null

    // function(parent, row, modelRow, cb) - hand a row item back through
    // cb(obj). May answer synchronously or later; both are supported.
    //
    // `row` is the model row the item is wanted for, and `parent.row` is the
    // same number live. A provider that answers at once can use either; one
    // that queues answers - to pace its building, or to dress the rows nearest
    // the viewport first - re-reads `parent.row`, because the window may move
    // while its answer is owed and a row number is a coordinate valid only for
    // the turn it was asked in.
    property var acquireDelegate
    // function(obj) - the item is no longer needed.
    property var releaseDelegate

    // The role that identifies a row. A fetch admits an unknown number of rows,
    // so membership in a batch is a set of keys rather than a count. A model
    // without this role still works - those rows reveal themselves individually
    // instead of joining a batch.
    property string keyRole: "key"

    // Content of the view's own, above and below the rows, with ListView's
    // meaning.
    property Component header: null
    property Component footer: null

    // Set by whoever owns the data: is there anything beyond each edge? Top
    // and bottom are the screen's, so an owner whose model runs the other way
    // round - a newest-first chat model rendered BottomToTop - crosses its own
    // ends here.
    property bool moreAvailableTop: false
    property bool moreAvailableBottom: false

    // Stands in for content that is not there yet: the whole viewport while the
    // first population is being gathered, and a band at either edge while more is
    // available there or on its way. Instantiated once, on first need, and moved
    // between those placements - so it must fill whatever space it is given. The
    // view sets its width and height; an intrinsic height of its own is
    // overridden.
    property Component placeholder: null

    // Ask for more by itself when a band the user can see still has content
    // behind it. The band is the trigger area, so a view with no placeholder
    // reserves nothing and pages only when told to.
    property bool autoRequest: true

    // Space each edge reserves for the placeholder. The single instance only ever
    // occupies the edge nearer the viewport, so the other reserves this much
    // blank.
    property real placeholderHeight: root.height

    // Keep the viewport at the bottom edge while it is already there, so the
    // last row stays visible as content grows and the initial fill lands
    // showing the newest row rather than the oldest. Off by default: for a
    // top-down list a short model growing past the viewport should stay put.
    property bool stickToBottom: false

    enum VerticalLayoutDirection { TopToBottom, BottomToTop }

    // Where positionViewAtRow() puts the row it is given. ListView's
    // vocabulary, minus the modes a windowed view has no use for: Contain
    // leaves a row that is already wholly on screen exactly where it is.
    enum PositionMode { Beginning, Center, End, Contain }

    // Which way rows are laid out, with Qt's meaning: BottomToTop lays them out
    // from the bottom of the view up to the top, so model row 0 is the bottom
    // one. For a newest-first model - which is how a chat backend hands messages
    // over - that puts the newest message at the bottom with nobody reversing
    // anything, and itemAtRow() still takes a model row, as ListView's
    // itemAtIndex() does.
    //
    // Only the order rows are rendered in changes. Top and bottom everywhere
    // else mean the screen, so whoever owns the data crosses its own ends when
    // this is set: the band at the top asks for more, and with a newest-first
    // model what belongs above is the model's *end*.
    //
    // Meant to be set once. Changing it swaps the model the rows are built
    // from, which destroys and rebuilds every one of them, so the view treats it
    // as a fresh population - the same path as a jump.
    property int verticalLayoutDirection:
            WindowedView.VerticalLayoutDirection.TopToBottom

    // How many rows the view holds. Not the model's total when something is
    // windowing it - that belongs to whoever owns the window.
    readonly property int rowCount: rowsRepeater.count

    // The viewport is at the bottom of the content. Whoever owns the data needs
    // this to tell a row that should simply be shown from one that should be
    // announced: arriving at the bottom while the user is already there is the
    // first, and arriving while they are reading further up is the second.
    readonly property bool atBottom: d.atBottomOfContent()

    // A request is outstanding in that direction. The view owns these because
    // it is the only party that knows it asked.
    readonly property bool loadingTop: d.loadingTop
    readonly property bool loadingBottom: d.loadingBottom

    // A batch has been admitted and is being made ready - shells built, content
    // acquired, heights settling - but is not on screen yet. The phase after the
    // owner has answered, and separate from loadingTop/Bottom, which cover only
    // the wait for that answer. A synchronous owner has no loading phase worth
    // seeing at all, and all of the time goes here.
    readonly property bool staging: d.wave.length > 0

    // Either a request is outstanding, a batch is staged and unrevealed, or a
    // fresh population is still being gathered.
    readonly property bool busy: d.loadingTop || d.loadingBottom
                                 || d.batchOpen || root.staging
                                 || d.initialLoading

    // A fresh population - a first load, or a jump that replaced every row - is
    // being staged and has not been revealed yet: the view is showing nothing
    // and will show all of it at once. Distinct from busy, which is equally
    // true while paging over content that is already on screen, so this is the
    // one to hang a skeleton on.
    readonly property bool initialLoading: d.initialLoading

    // "I would like more rows at this edge." Nothing is promised.
    signal moreRequestedTop()
    signal moreRequestedBottom()

    // Fired inside the reveal, in the same turn. An owner deferring removals
    // must perform them in this handler.
    signal batchRevealed()

    // A positionViewAtRow() request has been honoured and the row is where it
    // was asked to be - the moment to flash a jumped-to row. Deliberately not
    // fired for positionViewAtRowOffset(): that one restores a position the
    // reader already had, and should pass unnoticed.
    signal rowPositioned(int row)

    // Asks for more at one edge, once. Ignored while that edge is loading or has
    // nothing more to give.
    function requestMoreTop() {
        return d.request(true)
    }

    function requestMoreBottom() {
        return d.request(false)
    }

    // The owner's answer: whatever arrived, that is the batch. Called exactly
    // once per request, even when nothing arrived.
    function moreLoadedTop() {
        d.loaded(true)
    }

    function moreLoadedBottom() {
        d.loaded(false)
    }

    // Everything that arrives until endBatch() is one batch: staged, revealed
    // in a single frame, with batchRevealed() fired inside the reveal. The rows
    // may arrive inside the pair or much later - call endBatch() when the owner
    // is done, exactly once, even when nothing arrived. Opened while the view
    // is already busy, it joins what is in flight, and one reveal covers both.
    function beginBatch() {
        d.beginBatch()
    }

    function endBatch() {
        d.endBatch()
    }

    // The row item for a *model* row, as ListView.itemAtIndex() is: rendering
    // bottom-up moves row 0 to the bottom, it does not renumber it.
    function itemAtRow(row) {
        return rowsRepeater.itemAt(d.renderRow(row))
    }

    // The model row `key` occupies among the rows this view holds, or -1 when it
    // holds no such row - which is the signal to move the window and ask again.
    //
    // A row that is staged and not yet revealed is held, and so is found:
    // addressable and visible are different things. Row numbers are coordinates
    // valid for the turn they were asked in, so hold the key and ask again
    // rather than keeping the number.
    function rowForKey(key) {
        if (!d.effectiveModel)
            return -1

        const rendered = SQUtils.ModelUtils.indexOf(d.effectiveModel,
                                                    root.keyRole, key)

        return rendered < 0 ? -1 : d.modelRow(rendered)
    }

    // The key of a model row this view holds, or undefined. The inverse of
    // rowForKey(), for remembering a position as an identity rather than as a
    // number.
    function keyAtRow(row) {
        if (row < 0 || row >= root.rowCount)
            return undefined

        return d.keyAt(d.renderRow(row))
    }

    // Puts a model row where `mode` says. Returns whether the request was
    // accepted: a row this view does not hold is refused and nothing is
    // recorded - move the window first and ask again.
    //
    // Accepted is not the same as done. A row the Column has not laid out yet -
    // the ordinary case in the frame a batch is revealed - is remembered and
    // positioned as soon as it has geometry, and rowPositioned() says when.
    // The request is then handed to the anchor, so later content changes hold
    // the row where it was put, and it is abandoned as soon as the user
    // scrolls: a jump must not outlive their next move.
    function positionViewAtRow(row, mode) {
        return d.requestPosition(row, mode, NaN)
    }

    // Places the viewport top `offset` px below the top of a model row - the
    // restore primitive, and the counterpart of viewportOffsetToRow(). Exact
    // where the mode above is relative: the same rows at the same width lay out
    // the same way, so the offset reproduces the position they were captured
    // from.
    function positionViewAtRowOffset(row, offset) {
        return d.requestPosition(row, WindowedView.PositionMode.Beginning,
                                 offset)
    }

    // The content edge the model's first and last row sit at - the bottom and
    // the top rendering bottom-up, the other way round otherwise. Exact, and
    // needing no row geometry, because the edge is the edge whether or not the
    // row that belongs there is in the window; when it is not, that edge is the
    // placeholder band, so an owner who means the row itself moves the window
    // there first.
    function positionViewAtBeginning() {
        d.cancelPosition()
        d.releaseAnchor()
        d.apply(d.bottomUp ? d.bottomY() : 0)
    }

    function positionViewAtEnd() {
        d.cancelPosition()
        d.releaseAnchor()
        d.apply(d.bottomUp ? 0 : d.bottomY())
    }

    // How far the viewport top sits below the top of a model row, or NaN while
    // that row has no measurable geometry - never 0, which is a position rather
    // than an absence, and a caller recording a position must be able to tell
    // the difference.
    //
    // Visibility is deliberately not required: measured geometry outlives an
    // ancestor's hide until the next layout polish, and capturing as a view is
    // hidden is what this is for.
    function viewportOffsetToRow(row) {
        const item = root.itemAtRow(row)

        if (!item || item.height <= 0)
            return NaN

        return root.contentY - d.rowTop(item)
    }

    contentWidth: width

    // contentHeight is assigned, never bound: writing it runs Flickable's own
    // fixup, which moves contentY, and every internal contentY write has to be
    // distinguishable from a user scroll (see d.apply).


    QtObject {
        id: d

        readonly property bool bottomUp: root.verticalLayoutDirection
                === WindowedView.VerticalLayoutDirection.BottomToTop

        // How many rows the model has, asked of the model itself. The argument
        // is only a dependency: rowCount() tells QML nothing about when its
        // answer changes, so callers read the Repeater's count - which moves
        // with every model change - to make their binding re-evaluate with it.
        //
        // Needed because the Repeater reports the *old* count while it creates
        // the items for the new one, and a shell is created in exactly that
        // window - a binding on rowsRepeater.count there is one insert behind.
        function modelRowsFor(repeaterCount) {
            return d.effectiveModel ? d.effectiveModel.rowCount() : 0
        }

        // The two row spaces, and the only places they are converted. Public
        // functions take and return *model* rows, like ListView's do; the
        // Repeater, the staging ranges and the anchor loops all count in the
        // order the rows are rendered, which bottom-up is the other way up.
        // Both are their own inverse, and both are the identity top-down.
        function renderRow(modelRow) {
            return d.bottomUp ? root.rowCount - 1 - modelRow : modelRow
        }

        function modelRow(renderedRow) {
            return d.bottomUp ? root.rowCount - 1 - renderedRow : renderedRow
        }

        // The model the rows are actually built from, which is the given one
        // turned upside down when rendering bottom-up. Null for a null model
        // rather than an empty proxy, so every `root.model ? ...` guard in here
        // keeps answering the way it did.
        //
        // Everything internal counts in this model's rows: the Repeater's
        // indexes, the staging ranges, the anchor loops. That is the whole
        // reason this is cheap - the rows arrive already in the order they are
        // drawn, so no position, band or edge has to be mirrored. Only
        // itemAtRow(), which is public and speaks the caller's model, converts.
        // Keyed on the reverser having its source, not on root.model having a
        // value: a Repeater handed a proxy that is still sourceless builds
        // every row against its empty shape and then builds them all again
        // when the source lands. Both of these react to root.model, so reading
        // root.model here would race the reverser's own binding and lose about
        // half the time; reading the reverser cannot.
        // Keyed on the reverser having its source, not on root.model having a
        // value: a Repeater handed a proxy that is still sourceless builds
        // every row against its empty shape and then builds them all again
        // when the source lands. Both of these react to root.model, so reading
        // root.model here would race the reverser's own binding and lose about
        // half the time; reading the reverser cannot.
        readonly property var effectiveModel: d.bottomUp
                ? (reverser.sourceModel ? reverser : null)
                : root.model

        property bool loadingTop: false
        property bool loadingBottom: false

        // An owner-opened batch: rows are admitted until endBatch().
        property bool batchOpen: false

        readonly property bool loading: d.loadingTop || d.loadingBottom
                                        || d.batchOpen

        // A batch asked for at this edge has been admitted but not revealed yet.
        // The band has to stand for all of it: an owner that answers inside the
        // signal clears loading* immediately, and "nothing more beyond this"
        // arrives at the same moment - so without this the placeholder comes
        // down at request time and the rows that replace it appear separately,
        // which is the two-step change everything else here works to avoid.
        readonly property bool pendingTop: d.loadingTop
                                             || (d.wave.length > 0 && d.requestedAtEdge
                                                 && d.requestedAtTop)
        readonly property bool pendingBottom: d.loadingBottom
                                           || (d.wave.length > 0 && d.requestedAtEdge
                                               && !d.requestedAtTop)

        // How far this slide is going, and how many of the rows it added are
        // still waiting for content. Rows count themselves in and out.
        // Which edge the outstanding request was made at, so the anchor and the
        // reveal know which side is growing.
        property bool requestedAtTop: false
        // Whether the current wave was asked for at an edge at all. A batch the
        // owner opened has no edge, so it lights no band.
        property bool requestedAtEdge: false
        // Keys admitted by the slide whose shells do not exist yet, and the
        // shells that have claimed one. A batch is complete when no key is
        // outstanding and every claimed shell has content.
        property var stagedKeys: new Set()
        property bool keyWarningShown: false

        // Set when rows arrive into a view that is showing nothing, cleared
        // when they are revealed.
        property bool initialLoading: false

        // Placeholder /////////////////////////////////////////////////////
        //
        // One object for all three placements, built the first time any of them
        // wants it and kept for the view's life: the content of a skeleton is
        // not cheap, and availability at an edge toggles constantly.
        property Item placeholderItem: null
        property Item placeholderHost: null

        function ensurePlaceholder() {
            if (d.placeholderItem || !root.placeholder)
                return

            d.placeholderItem = root.placeholder.createObject(placeholderPark)

            if (!d.placeholderItem) {
                console.warn("WindowedView: creating the placeholder failed")
                return
            }

            d.placeholderItem.visible = false
        }

        // Auto-request ///////////////////////////////////////////////////
        //
        // Holding the scroll bar defers a request.
        readonly property bool scrollBarHeld: {
            const bar = root.ScrollBar.vertical

            return !!bar && bar.pressed
        }

        // Load more condition: `busy` is part of the condition, so
        // a request takes it down and the reveal brings it back up - and if the
        // band is still on screen by then, that rise is the next request.
        // Releasing the handle is an edge too.
        readonly property bool hasViewport: root.width > 0 && root.height > 0
                                            && rowsColumn.height > 0

        readonly property bool shouldRequestMore:
                root.autoRequest && d.hasViewport
                && !root.busy && !d.finishing && !d.scrollBarHeld
                && ((root.moreAvailableTop && d.bandInViewport(topBand))
                    || (root.moreAvailableBottom && d.bandInViewport(bottomBand)))

        // Deferred by one turn, not polled: requesting writes `d.wave`, which
        // feeds `staging`, which feeds `busy`, which this condition reads - so
        // doing it here, inside the notification, is a binding loop. callLater
        // runs in this same event-loop iteration, before anything is rendered,
        // so nothing is actually delayed.
        onShouldRequestMoreChanged: {
            if (d.shouldRequestMore)
                Qt.callLater(d.requestForVisibleBand)
        }

        function requestForVisibleBand() {
            // Re-checked rather than trusted from the edge that scheduled it:
            // the view may have moved, stopped being idle, or had the request
            // answered by other means in between.
            if (!d.shouldRequestMore)
                return

            // The top first, so a view short enough to show both bands walks
            // back through the history rather than fighting itself.
            if (root.moreAvailableTop && d.bandInViewport(topBand))
                d.request(true)
            else if (root.moreAvailableBottom && d.bandInViewport(bottomBand))
                d.request(false)
        }

        // Where a row or a band sits in the same space contentY is measured
        // in. The Column is normally at the origin and the two agree; rendering
        // bottom-up with less content than viewport pushes it down so the rows
        // rest on the bottom edge, and then they do not.
        function rowTop(item) {
            return item.y + rowsColumn.y
        }

        // Whether a band overlaps what the user can see. Both ends can be on
        // screen at once when the whole window fits with room to spare.
        function bandInViewport(band) {
            return band.visible
                    && d.rowTop(band) < root.contentY + root.height
                    && d.rowTop(band) + band.height > root.contentY
        }

        // How far a band's nearest edge is from the viewport, for picking
        // between two that are both on screen.
        function bandDistance(band) {
            const middle = root.contentY + root.height / 2

            return Math.abs(d.rowTop(band) + band.height / 2 - middle)
        }

        function chooseHost() {
            if (!root.placeholder)
                return null

            if (fillBand.visible)
                return fillBand

            const start = d.bandInViewport(topBand)
            const end = d.bandInViewport(bottomBand)

            if (start && end)
                return d.bandDistance(topBand) <= d.bandDistance(bottomBand)
                        ? topBand : bottomBand

            if (start)
                return topBand

            if (end)
                return bottomBand

            return null
        }

        // Runs on every contentY change, so it returns early when the host has
        // not changed. Qt already ignores a reparent to the same parent, so what
        // this saves is the rest: two fresh Qt.bindings and a visible write per
        // scroll frame. Not observable in behaviour, only in churn.
        function applyPlaceholder() {
            const host = d.chooseHost()

            if (host === d.placeholderHost)
                return

            if (host)
                d.ensurePlaceholder()

            if (!d.placeholderItem) {
                d.placeholderHost = null
                return
            }

            d.placeholderHost = host

            if (!host) {
                d.placeholderItem.visible = false
                d.placeholderItem.parent = placeholderPark
                return
            }

            d.placeholderItem.parent = host
            d.placeholderItem.width = Qt.binding(() => host.width)
            d.placeholderItem.height = Qt.binding(() => host.height)
            d.placeholderItem.visible = true
        }

        // Guards completeWave() against being re-entered by the destruction of
        // the rows it is itself trimming.
        property bool finishing: false

        // True only while the window bound is being moved and the Repeater is
        // building the new shells. A provider that answers synchronously - a
        // warm cache with no delay - completes those rows inside this window,
        // and the first of them must not be allowed to finish the slide while
        // the rest do not yet exist.
        //
        // Waiting for the batch's heights to settle ////////////////////////
        //
        // Content arriving is not the same as content being measured: a row
        // whose item was recycled reports its previous implicitHeight until the
        // delegate's own layout runs, which for a QQuickLayout is a polish
        // away and cannot be forced. Revealing then would lay the batch out
        // against the heights of whatever those items showed before.
        //
        // A hidden row's height does settle - measured - so the batch can be
        // measured before it is shown: sample the summed height every frame and
        // reveal once two consecutive samples agree.
        property real heightSum: -1
        property int stableSamples: 0
        property int settleSamples: 0

        // A height that never stops moving - an image with no reserved size, an
        // animation - would otherwise wedge the slide forever.
        readonly property int maxSettleSamples: 10

        // The rows staged for the current reveal. Membership is the single
        // source of truth - "waiting" and "arrived" are derived from whether a
        // shell has content yet, so there is no counter to fall out of step.
        //
        // Always *reassigned*, never mutated in place to properly propagate
        // changes.
        property var wave: []

        function waveArrived() {
            return d.wave.filter(shell => !!shell.content)
        }

        function waveWaiting() {
            return d.wave.filter(shell => !shell.content)
        }

        function contentHeightSum() {
            let sum = 0

            const arrived = d.waveArrived()

            for (let i = 0; i < arrived.length; ++i)
                sum += arrived[i].content.implicitHeight

            return sum
        }

        function beginSettling() {
            d.heightSum = -1
            d.stableSamples = 0
            d.settleSamples = 0
            settleTimer.restart()
        }

        function settleTick() {
            const sum = d.contentHeightSum()

            ++d.settleSamples

            if (sum === d.heightSum) {
                ++d.stableSamples
            } else {
                d.heightSum = sum
                d.stableSamples = 0
            }

            if (d.stableSamples >= 1) {
                d.completeWave()
                return
            }

            if (d.settleSamples >= d.maxSettleSamples) {
                console.warn("WindowedView: row heights did not settle within",
                             d.maxSettleSamples, "frames; revealing anyway")
                d.completeWave()
            }
        }

        // Belt and braces, and no longer load-bearing on its own: completion
        // used to be synchronous, and without this the first row to answer
        // finished the slide from inside the Repeater's creation pass, trimming
        // the far end against a half-built window. The settle wait now defers
        // completion to a timer, and rows admitted before moreLoaded*() arrive
        // while `loading` is still true, so either check alone suffices.
        // Removing it is measurably safe today; it is kept because it states
        // the intent, and because a future synchronous reveal path would need it.
        property bool admitting: false

        property var wiredModel: null

        // Held anchor //////////////////////////////////////////////////////
        //
        // The viewport is not corrected once and measured at the right moment.
        // A row is picked before the window moves, its offset below the
        // viewport top recorded, and the correction re-applied every time that
        // row moves - see the Connections below. Late geometry therefore needs
        // no timing assumption at all: a recycled row reports a stale
        // implicitHeight until the next polish, and when it finally settles the
        // anchor moves again and the correction simply re-runs.
        property Item anchorItem: null
        property real anchorOffset: 0

        // All internal contentY and contentHeight writes go through these, so
        // onContentYChanged can tell them from a user move - wheel, touch, and
        // scrollbar drags, which emit no movement signals at all.
        property bool applyingPosition: false

        // Writing contentY cancels an in-flight flick: setContentY() resets the
        // timeline and ends the movement. So the velocity is taken before the
        // write and the flick started again after it. Under Qt's constant
        // deceleration the distance still to travel is v^2/2a, which depends on
        // nothing but the current velocity - so resuming from it continues the
        // same trajectory rather than approximating it.
        property real heldFlickVelocity: 0
        property bool flickHoldActive: false

        function preservingFlick(write) {
            // The velocity is taken once, on the first write of a turn, and put
            // back after every write of that turn - completeWave() moves the
            // position several times over (applyContentHeight(), then
            // restorePosition(), then again as the layout settles) and each one
            // cancels the flick afresh. Re-reading the velocity per write
            // instead would pick up the flick this just restarted, whose
            // smoothed value has had no frame to update and reads as nothing,
            // so the second write would kill the flick for good.
            // Not while the view is out of bounds. An overshoot past either
            // end reports as flicking, but what is running then is Qt's own
            // rebound back into bounds - re-flicking there fights the bounce
            // instead of preserving anything.
            if (!d.flickHoldActive && root.flickingVertically
                    && root.verticalOvershoot === 0
                    && root.verticalVelocity !== 0) {
                d.heldFlickVelocity = -root.verticalVelocity
                d.flickHoldActive = true

                // Releases the hold at the end of this turn. It only ever
                // clears - a restore deferred to here could land in a quite
                // different situation and start a flick nobody asked for.
                Qt.callLater(d.endFlickHold)
            }

            write()

            if (d.flickHoldActive && d.heldFlickVelocity !== 0)
                root.flick(0, d.heldFlickVelocity)
        }

        function endFlickHold() {
            d.flickHoldActive = false
            d.heldFlickVelocity = 0
        }

        function apply(y) {
            d.preservingFlick(() => {
                const was = d.applyingPosition

                d.applyingPosition = true
                root.contentY = y
                d.applyingPosition = was
            })
        }

        // What stands above the rows at the screen's top, as the current
        // contentY already accounts for it: the start band, and whatever the
        // owner put in the slot there. The band's `height` is a constant, so for
        // it what changes is only whether it is shown at all - a Column drops an
        // invisible child from its layout entirely - while a slot's content can
        // also grow and shrink. Both arrive here the same way, because any of it
        // changes the Column's height, and that is what calls this.
        property real appliedAboveRows: 0

        function aboveRowsExtent() {
            return (topBand.visible ? topBand.height : 0)
                    + (topSlot.visible ? topSlot.height : 0)
        }

        function applyContentHeight() {
            d.preservingFlick(d.applyContentHeightNow)
        }

        function applyContentHeightNow() {
            // Sampled before the write, while contentHeight still describes the
            // bottom the viewport was actually sitting at - and against the
            // height it was sitting in, which a resize has already changed.
            const wasAtBottom = d.wasAtBottomOfContent()
            const startBandDelta = d.aboveRowsExtent() - d.appliedAboveRows
            const was = d.applyingPosition

            d.appliedAboveRows = d.aboveRowsExtent()

            d.applyingPosition = true
            root.contentHeight = Math.max(root.height, rowsColumn.height)

            // The start band or the slot above the rows grew or shrank, so
            // without this
            // every one of them shifts by that much - visibly, since outside a
            // slide no anchor is armed to absorb it. The bottom band needs nothing:
            // it is below the viewport. Applied before the stickToBottom pin, and
            // restorePosition() still runs after this and wins whenever an
            // anchor is armed.
            // Not during a reveal: there the band's appearing is part of content
            // arriving all at once, and the anchor - or the stickToBottom pin - owns
            // where that lands. Paying for it here as well would scroll a first
            // paint past the very band it just put up.
            if (startBandDelta !== 0 && !d.finishing)
                root.contentY = Math.max(0, Math.min(d.bottomY(),
                                                     root.contentY + startBandDelta))

            // Not while a slide holds a row - that anchor is the exact
            // guarantee, and the rows a slide adds at the end belong below the
            // viewport, not pulled into it - and not while the user has hold of
            // the view, where snapping to the bottom would fight the drag.
            //
            // The anchor clause is redundant as things stand: every caller
            // re-applies the anchor immediately after this returns, so it wins
            // by running last. It is kept so the rule holds on its own rather
            // than by call-site ordering.
            // The pending clause is redundant for the same reason as the
            // anchor one: restorePosition() runs after every caller of this and
            // honours the request, so a pin here is corrected in the same turn.
            // Kept so the rule holds on its own rather than by call-site
            // ordering.
            if (root.stickToBottom && wasAtBottom && !d.anchorItem
                    && d.pendingRow < 0 && !root.moving)
                root.contentY = d.bottomY()      // guard already held

            d.appliedHeight = root.height
            d.applyingPosition = was
        }

        // Whether the viewport is at the bottom of the content as contentHeight
        // currently describes it. Not Flickable.atYEnd: this is read inside a
        // height handler, where contentHeight still holds the pre-change value -
        // which is the point - and a sub-pixel gap must still count as the end.
        function atBottomOfContent() {
            return root.contentY >= Math.max(0, root.contentHeight - root.height) - 1
        }

        // The viewport height the current contentY was last reconciled against.
        // A resize changes `height` before this runs, so asking whether the view
        // *was* at the end has to be asked of the geometry it was placed in:
        // shrinking moves the bottom down, and measured against the new height a
        // viewport sitting exactly at the old bottom reads as no longer there -
        // which is how shrinking lost stickToBottom while growing kept it.
        property real appliedHeight: 0

        function wasAtBottomOfContent() {
            return root.contentY >= Math.max(0, root.contentHeight
                                                - d.appliedHeight) - 1
        }

        // Live values, not the contentHeight property: inside a height handler
        // it still holds the pre-change value.
        function bottomY() {
            return Math.max(0, Math.max(root.height, rowsColumn.height) - root.height)
        }

        function releaseAnchor() {
            d.anchorItem = null
        }

        // A positioning request that cannot be honoured yet, in rendered rows.
        // -1 is no request; pendingOffset NaN means use pendingMode.
        property int pendingRow: -1
        property real pendingOffset: NaN
        property int pendingMode: WindowedView.PositionMode.Beginning

        function cancelPosition() {
            d.pendingRow = -1
            d.pendingOffset = NaN
        }

        function requestPosition(row, mode, offset) {
            if (row < 0 || row >= root.rowCount)
                return false

            // A deliberate position replaces whatever was holding the view,
            // including a slide's anchor: the request is the guarantee now.
            d.releaseAnchor()

            d.pendingRow = d.renderRow(row)
            d.pendingMode = mode
            d.pendingOffset = offset

            // Asked from inside a reveal - batchRevealed() is where an owner
            // resolves a jump, and it fires before the batch is laid out - the
            // request is only recorded. The rows have heights by then but the
            // Column has not placed them, so the geometry this would compute
            // from is the previous layout's. completeWave() lays the batch out
            // and calls restorePosition() itself, which honours the request
            // against the real thing, in the same turn and so in the same
            // frame.
            if (!d.finishing)
                d.restorePosition()

            return true
        }

        // Honours a pending request once its row has geometry, and says whether
        // it dealt with the position. A request still waiting answers false, so
        // the anchor keeps the content still in the meantime rather than the
        // view sitting wherever the pending row happens to be.
        function applyPendingPosition() {
            if (d.pendingRow < 0)
                return false

            const target = rowsRepeater.itemAt(d.pendingRow)

            // A staged row has no content and no height; a revealed one can
            // still be pre-polish. Either way its geometry is not yet the
            // geometry the request was about.
            if (!target || !target.visible || target.height <= 0)
                return false

            const exact = !isNaN(d.pendingOffset)
            const top = d.rowTop(target)
            const bottom = d.bottomY()
            let wanted = top

            if (exact)
                wanted = top + d.pendingOffset
            else if (d.pendingMode === WindowedView.PositionMode.Center)
                wanted = top + target.height / 2 - root.height / 2
            else if (d.pendingMode === WindowedView.PositionMode.End)
                wanted = top + target.height - root.height
            else if (d.pendingMode === WindowedView.PositionMode.Contain) {
                const above = top < root.contentY
                const below = top + target.height > root.contentY + root.height

                // Already wholly on screen: the point of this mode is to leave
                // a reader where they are.
                if (!above && !below)
                    wanted = root.contentY
                else if (above)
                    wanted = top
                else
                    wanted = top + target.height - root.height
            }

            const applied = Math.max(0, Math.min(bottom, wanted))

            d.apply(applied)

            // An exact request that had to be clamped was asked in a frame
            // whose layout has not absorbed the revealed rows yet, so the
            // content is still too short to honour it. Keep the request and
            // retry when the heights settle - landing at the clamp would put a
            // restore at the bottom instead of where it was captured. A mode
            // request does not retry: a row near an end legitimately clamps.
            if (exact && Math.abs(applied - wanted) > 0.01)
                return true

            // Handed to the anchor, by item rather than by row: the window may
            // slide underneath, which would make the same row a different
            // message.
            const row = d.modelRow(d.pendingRow)

            d.anchorItem = target
            d.anchorOffset = d.rowTop(target) - root.contentY
            d.cancelPosition()

            if (!exact)
                root.rowPositioned(row)

            return true
        }

        function restorePosition() {
            if (d.applyPendingPosition())
                return

            if (!d.anchorItem)
                return

            // A row the Column has not placed yet. Positioners lay their
            // children out one at a time, and a correction can be asked for
            // from the middle of that pass - the anchor's own y change is what
            // asks for it. No child of a Column ever legitimately sits above
            // its origin, so this is a position the layout cannot have
            // produced, and a target computed from it clamps the viewport to
            // the top and loses where the content was.
            // Deliberately the raw Column coordinate rather than rowTop(): this
            // asks whether the Column has placed the item at all, which is a
            // question about its own origin.
            if (d.anchorItem.y < 0)
                return

            // Absolute, not relative, so re-applying it converges instead of
            // drifting - which is what makes holding the anchor safe.
            const target = d.rowTop(d.anchorItem) - d.anchorOffset
            const bottom = d.bottomY()

            d.apply(Math.max(0, Math.min(bottom, target)))

            // The correction ran into the bottom and stopped there, so holding a
            // row no longer describes where the view is - the bottom does. A
            // view told to stay there has to go back to doing so, or it
            // sits at the bottom without being stuck to it and the next row to
            // arrive leaves it behind. Not while a slide is in flight: there the
            // anchor is the guarantee, and the far end has yet to be trimmed.
            if (root.stickToBottom && !root.busy && target >= bottom
                    && root.contentY >= bottom - 0.5)
                d.releaseAnchor()
        }

        function holdAnchor(item) {
            d.anchorItem = item
            d.anchorOffset = d.rowTop(item) - root.contentY
        }

        // A resize re-wraps every row, so every height changes at once - the
        // ones above the viewport included, which is what moves the content out
        // from under the reader. The row held still is the topmost one whose top
        // edge they can actually see: a row clipped by the viewport top is not
        // the message they are reading from its beginning.
        //
        // Different from armAnchor(), which wants the row nearest an edge
        // because a slide is about to trim the other one.
        function anchorForResize() {
            // Nothing laid out to anchor to - the rows have collapsed, and
            // anchoring to that would record the collapse as the place to come
            // back to. The width being restored arrives here before the rows
            // have re-expanded, which is exactly this case.
            if (rowsColumn.height <= 0)
                return

            // At the end and asked to stay there, the bottom *is* the position,
            // and the pin in applyContentHeight() keeps it. Arming here would
            // suppress that pin, which is conditioned on there being no anchor.
            if (root.stickToBottom && d.atBottomOfContent())
                return

            // A slide owns the position while it is in flight, and its anchor is
            // the exact guarantee; it must not be swapped mid-reveal.
            if (root.busy)
                return

            let covering = null

            for (let i = 0; i < rowsRepeater.count; ++i) {
                const item = rowsRepeater.itemAt(i)

                if (!item || !item.visible)
                    continue

                // Past the bottom of the viewport, and the rows are ordered,
                // so there is nothing visible left to find.
                if (d.rowTop(item) >= root.contentY + root.height)
                    break

                if (d.rowTop(item) >= root.contentY - 0.5) {
                    d.holdAnchor(item)
                    return
                }

                covering = item
            }

            // Nothing starts on screen - one row is taller than the viewport -
            // so hold the row that covers the top, offset and all.
            if (covering)
                d.holdAnchor(covering)
        }

        // Picks the visible row nearest the viewport edge that will survive.
        // Growing at the top trims at the bottom, so a row at the top is safe;
        // growing at the bottom trims at the top, so it is the bottom one. Returns
        // whether it found one; a failure leaves any existing anchor alone.
        function armAnchor(atTop) {
            const edge = atTop ? root.contentY : root.contentY + root.height

            let best = null
            let bestDistance = Number.MAX_VALUE

            for (let i = 0; i < rowsRepeater.count; ++i) {
                const item = rowsRepeater.itemAt(i)

                if (!item || !item.visible)
                    continue

                const distance = Math.abs(d.rowTop(item) - edge)

                if (distance < bestDistance) {
                    bestDistance = distance
                    best = item
                }
            }

            if (!best)
                return false

            d.holdAnchor(best)
            return true
        }

        // A manual move while a slide is in flight must not cost the
        // guarantee - dropping the anchor there is what made the batch reveal
        // jump by the height of everything that changed. Re-anchor to where the
        // user has just put the view instead. Outside a slide the anchor has no
        // work to do.
        function userMoved() {
            // A jump must not outlive the user's next move - the same lifetime
            // the resize anchor has.
            d.cancelPosition()

            if (!d.loading && d.wave.length === 0) {
                d.releaseAnchor()
                return
            }

            if (d.armAnchor(d.requestedAtEdge ? d.requestedAtTop : true))
                return

            // Nothing that survives is on screen: the user has scrolled into
            // the rows being removed, which is the one case where staying put
            // is impossible. Hold what we have and re-measure it, so the
            // content that does survive still lands where it belongs.
            if (d.anchorItem)
                d.anchorOffset = d.rowTop(d.anchorItem) - root.contentY
        }

        // Asks the owner for more at one end. Nothing is admitted here - the
        // owner may answer inside this call by moving a window's bounds, or much
        // later from a backend. Either way every row that arrives before
        // moreLoaded*() is one batch.
        function request(atTop) {
            // Not just "not loading": a batch that has been admitted but not yet
            // revealed is still outstanding, and starting a second request there
            // would reset the wave and orphan the first batch's staged rows -
            // they would stay hidden for good. One batch at a time is what the
            // single wave, single anchor and single requested-edge assume.
            //
            // initialLoading covers the window between capturing a fresh
            // population's keys and the first shell claiming one, where the
            // wave is still empty. No caller can observe that window while the
            // Repeater builds its items synchronously inside the insert, so the
            // clause is belt and braces; it is here so the rule does not rest
            // on that being true.
            if (d.loading || d.wave.length > 0 || d.initialLoading)
                return false

            if (atTop ? !root.moreAvailableTop : !root.moreAvailableBottom)
                return false

            d.wave = []
            d.stagedKeys = new Set()
            d.noProgressIntervals = 0

            // Armed before anything can arrive, while the geometry is settled.
            // Requesting at the top grows above and trims below, so a row at
            // the viewport top survives; at the bottom it is the other way round.
            d.releaseAnchor()
            d.armAnchor(atTop)

            d.requestedAtTop = atTop
            d.requestedAtEdge = true

            if (atTop)
                d.loadingTop = true
            else
                d.loadingBottom = true

            // Rows admitted synchronously inside the signal are captured by the
            // model connection below, and shells built inside it stage
            // themselves because loading is already true.
            d.admitting = true

            if (atTop)
                root.moreRequestedTop()
            else
                root.moreRequestedBottom()

            d.admitting = false

            acquireTimer.restart()
            d.checkWaveComplete()
            return true
        }

        // The owner is done. Whatever arrived is the batch; it may be nothing.
        function loaded(atTop) {
            if (atTop ? !d.loadingTop : !d.loadingBottom)
                return      // no request outstanding at that edge

            if (atTop)
                d.loadingTop = false
            else
                d.loadingBottom = false

            d.checkWaveComplete()
        }

        function beginBatch() {
            if (d.batchOpen)
                return

            const wasBusy = root.busy

            d.batchOpen = true

            if (!wasBusy) {
                d.wave = []
                d.stagedKeys = new Set()
                d.noProgressIntervals = 0
                d.requestedAtEdge = false

                // No edge to grow from, so hold the reading position: the row
                // at the viewport top stays put while rows come and go.
                d.releaseAnchor()
                d.armAnchor(true)
            }

            // A staged wave may be settling; it must not reveal while the batch
            // can still add to it. endBatch() starts the settle again.
            settleTimer.stop()

            // Nothing on screen: what arrives is a fresh population, shown
            // under the fill placeholder and revealed in one step.
            if (d.showingNothing())
                d.initialLoading = true

            acquireTimer.restart()
        }

        function endBatch() {
            if (!d.batchOpen)
                return

            d.batchOpen = false
            d.checkWaveComplete()
        }

        // Reveals the rows of the current wave that have arrived, and - on the
        // first wave of a slide - drops the far end. Rows still waiting stay
        // staged and become the next wave, so a slow row delays its own reveal
        // instead of dragging the content height along one row at a time.
        //
        // No measurement here: the held anchor restores the position, now and
        // again whenever the rows move as their deferred layout settles.
        function completeWave() {
            settleTimer.stop()
            d.finishing = true

            const arrived = d.waveArrived()

            for (let i = 0; i < arrived.length; ++i) {
                arrived[i].staged = false
                arrived[i].revealed = true
            }

            d.wave = d.waveWaiting()

            // In this same turn, so rows leaving and rows appearing change the
            // content together. An owner that defers removals trims here.
            root.batchRevealed()

            // Cleared here, not at the end: it collapses the viewport-filling
            // placeholder, and that has to happen in the same layout pass as the
            // rows appearing. Cleared after the height was applied and the
            // placeholder would come down in a second step - the two-stage jump
            // the batched reveal exists to remove.
            d.initialLoading = false

            // The heights are final by now, so this pass is exact rather than
            // provisional - no late correction is needed.
            rowsColumn.forceLayout()
            d.applyContentHeight()
            d.restorePosition()

            // Not re-armed here: an arrival does that, so a wave still owed
            // rows gets a fresh interval each time one lands, and a provider
            // gone silent for good just leaves its rows hidden.
            acquireTimer.stop()
            d.finishing = false
        }

        // Called by every row as it is built. Returns whether the row joined
        // the batch, which the row remembers so it reports back exactly once.
        // Called from the proxy as rows enter, before the Repeater has built
        // anything for them.
        // Through ModelUtils, so any QAbstractItemModel works. Reading
        // model.get(row, role) directly only works for SortFilterProxyModel: a
        // plain ListModel ignores the second argument and hands back the whole
        // row object, which then never matches a shell's key and silently
        // demotes staging to the loading-flag fallback.
        function keyAt(row) {
            return d.effectiveModel
                    ? SQUtils.ModelUtils.get(d.effectiveModel, row, root.keyRole)
                    : undefined
        }

        // Rows entering while a request is outstanding are that request's batch.
        // How many rows are on screen. Maintained from the shells' own
        // revealed-property change rather than counted from the Repeater: its
        // items type as plain QQuickItem, and a row's own `visible` would also
        // read false whenever the view itself is hidden, which is not the same
        // question at all.
        property int revealedCount: 0

        // A population arriving into a view showing nothing is a fresh one,
        // however it came about - a first load, or a jump that removed every
        // row before inserting the replacements.
        function showingNothing() {
            return d.revealedCount === 0
        }

        // Rows entering a batch that is already open: the one a request
        // admitted, or a fresh population still being gathered. Anything else
        // is a live row and shows itself.
        function captureStagedRows(first, last) {
            if (!d.loading && !d.initialLoading)
                return

            d.captureKeys(first, last)
        }

        // Every row the model currently holds, as one batch.
        //
        // Started by the first shell built into a view that is showing nothing,
        // not by a model signal, because no signal reliably marks a fresh
        // population: a proxy windowing a large model delivers its first page
        // as a reset, and the Repeater answers a reset by destroying whatever
        // it built and regenerating - a second generation of rows that arrives
        // with no signal of its own at all. A shell asking on its own behalf is
        // indifferent to all of that.
        function beginFreshFill() {
            // rowCount() rather than root.rowCount: the Repeater is mid-build,
            // so its count does not describe the model yet. Reading it in a
            // handler, which is where rowCount() belongs.
            const rows = d.effectiveModel ? d.effectiveModel.rowCount() : 0

            if (rows <= 0)
                return

            const had = d.stagedKeys.size

            d.captureKeys(0, rows - 1)

            // Not one key between them: the model has no key role, so these
            // rows reveal one by one as documented. Announcing a fill that
            // nothing will ever complete would leave the view busy - and
            // paging refused - for good.
            if (d.stagedKeys.size === had)
                return

            d.initialLoading = true
            d.noProgressIntervals = 0

            // Nothing else arms it here: contentArrived() is what normally
            // re-arms the detector, and a provider that never answers produces
            // no arrival to do it.
            acquireTimer.restart()
        }

        function captureKeys(first, last) {

            for (let i = first; i <= last; ++i) {
                const key = d.keyAt(i)

                if (key === undefined || key === null) {
                    if (!d.keyWarningShown) {
                        d.keyWarningShown = true
                        console.warn("WindowedView: no \"" + root.keyRole
                                     + "\" role on the model; rows will reveal"
                                     + " individually instead of as a batch")
                    }
                    continue
                }

                d.stagedKeys.add(key)
            }
        }

        // A staged row leaving the window before its shell was ever built must
        // not hold the batch open. Read on aboutToBeRemoved, while the key can
        // still be read.
        function dropStagedRows(first, last) {
            if (d.stagedKeys.size === 0)
                return

            let dropped = false

            for (let i = first; i <= last; ++i) {
                const key = d.keyAt(i)

                if (key !== undefined && key !== null && d.stagedKeys.delete(key))
                    dropped = true
            }

            if (dropped)
                d.checkWaveComplete()
        }

        function clearStaging() {
            d.stagedKeys = new Set()
            d.initialLoading = false

            for (let i = 0; i < d.wave.length; ++i)
                d.wave[i].staged = false

            d.wave = []
            acquireTimer.stop()
        }

        // Called by every row as it is built: it belongs to the batch exactly
        // when its own key was admitted by the slide.
        function claimStagedRow(shell) {
            if (!d.stagedKeys.delete(shell.rowKey))
                return false

            d.wave = d.wave.concat([shell])
            return true
        }

        function forgetRow(shell) {
            if (d.wave.indexOf(shell) === -1)
                return

            d.wave = d.wave.filter(row => row !== shell)
            d.checkWaveComplete()
        }

        // One row got its content: progress, so the stall detector re-arms.
        // How many whole intervals may pass with nothing arriving at all before
        // the slide is completed regardless. Nothing arriving yet is not the
        // same as being wedged: a provider slower than one interval would
        // otherwise have its trim applied with nothing to reveal, which is
        // exactly the two-ends-together invariant this design exists to keep.
        readonly property int maxWaitIntervals: 3
        property int noProgressIntervals: 0

        function contentArrived() {
            d.noProgressIntervals = 0
            acquireTimer.restart()
            d.checkWaveComplete()
        }

        // Not gated on loading: a wave can outlive the request that created it.
        function checkWaveComplete() {
            if (d.finishing || d.admitting)
                return

            if (d.wave.length === 0) {
                // Nothing is owed - the batch was revealed, or every row of it
                // left the window again before it arrived. A detector left armed
                // here fires against an empty wave. While a request is still
                // outstanding something *is* owed, so it keeps running for an
                // owner that never answers at all.
                if (!d.loading && d.stagedKeys.size === 0) {
                    acquireTimer.stop()

                    // Nothing is owed, so no fill is outstanding either. A fill
                    // whose rows all left the window before they arrived
                    // completes no wave, and without this its flag - and the
                    // refusal to page that hangs off it - would never lift.
                    d.initialLoading = false
                }

                return
            }

            // Nothing more is owed by the *provider*: every admitted row has
            // its content and no key is left to claim. The detector watches the
            // provider, so it comes down here even while the owner is still
            // loading - waiting for an answer is not a stall, and letting it
            // fire there would reveal a batch the owner may still be adding to,
            // splitting the very thing this reveals in one shot.
            const providerDone = d.stagedKeys.size === 0
                                 && d.waveWaiting().length === 0

            if (providerDone)
                acquireTimer.stop()

            if (d.loading)
                return      // the owner has not finished admitting rows

            if (!providerDone)
                return

            d.beginSettling()
        }

        // No progress for a whole interval. Giving up on *waiting* must not mean
        // giving up on batching: the slide completes - far end trimmed, flags
        // cleared, position restored - and whatever has not arrived stays staged
        // as the next wave. Those rows then reveal together whenever they turn
        // up, so a merely slow provider costs one deferred reveal rather than a
        // row-by-row crawl of the content height.
        function abandonWait() {
            const arrived = d.waveArrived().length
            const waiting = d.waveWaiting().length

            if (arrived === 0 && waiting === 0 && d.stagedKeys.size === 0) {
                // Nothing is owed yet. An owner that fetches before it admits
                // has a request outstanding here and rows still to come, so
                // keep watching - let the detector lapse and a provider that
                // goes silent after that admission is never caught.
                if (d.loading)
                    acquireTimer.restart()

                return
            }


            if (arrived === 0 && ++d.noProgressIntervals < d.maxWaitIntervals) {
                // Nothing to reveal yet: keep waiting rather than trim against
                // an empty reveal. Bounded, so a wedge still ends.
                acquireTimer.restart()
                return
            }

            if (arrived > 0)
                console.warn("WindowedView: no progress for",
                             acquireTimer.interval + "ms; revealing", arrived,
                             "rows and holding", waiting, "for the next wave")
            else
                console.warn("WindowedView: nothing arrived in",
                             d.noProgressIntervals * acquireTimer.interval + "ms;",
                             waiting, "rows stay staged and reveal together when they do")

            // Rows that were never built cannot be waited on any longer.
            d.stagedKeys = new Set()
            d.completeWave()
        }

    }

    // Turns the given model upside down for BottomToTop, and sits idle
    // otherwise. A reversal and nothing else: the row count is the same, the
    // roles are the same, and every structural change is translated into its
    // exact counterpart rather than a reset - a row inserted at the model's
    // front arrives here as an append, ranges stay contiguous, and persistent
    // indexes survive. That translation is what lets the staging handlers below
    // take the ranges as they come.
    ReverseProxyModel {
        id: reverser

        sourceModel: d.bottomUp ? root.model : null
    }

    // The view does not own the model, so the staging handlers live here.
    // Ordering against the Repeater's own connection is deliberately not relied
    // on: a shell built before its key was captured stages itself because a
    // request is outstanding, and one built afterwards claims the key.
    Connections {
        target: d.effectiveModel

        function onRowsInserted(parent, first, last) {
            d.captureStagedRows(first, last)
        }

        // aboutToBeRemoved, while the key is still readable
        function onRowsAboutToBeRemoved(parent, first, last) {
            d.dropStagedRows(first, last)
        }

        // a reset removes every row with no per-row signal
        function onModelAboutToBeReset() {
            d.clearStaging()
            d.loadingTop = false
            d.loadingBottom = false
        }
    }

    // Stall detector for the wait itself, re-armed by every row that arrives,
    // so it fires only after a whole interval with no progress at all - a
    // wedged batch, not a slow one. Without it a provider that never answers
    // leaves the window oversized and both slide directions disabled for good.
    Timer {
        id: acquireTimer

        interval: 1000

        onTriggered: d.abandonWait()
    }

    Timer {
        id: settleTimer

        interval: 16
        repeat: true

        onTriggered: d.settleTick()
    }

    // The whole point of the held anchor: a slide moves the surviving rows,
    // and so does the deferred layout of a recycled row a frame later. Both
    // arrive here, and both are corrected the same way.
    Connections {
        target: d.anchorItem

        function onYChanged() {
            d.restorePosition()
        }
    }

    // Any contentY change that is not ours is the user scrolling - wheel,
    // touch, or a scrollbar drag, which emits no movement signals at all.
    onContentYChanged: {
        if (!d.applyingPosition)
            d.userMoved()

        d.applyPlaceholder()
    }

    onHeightChanged: {
        d.applyContentHeight()
        d.restorePosition()
    }

    // Caught here rather than from the heights that follow: the re-wrap lands on
    // the next polish, so this handler still sees the geometry the reader was
    // looking at, which is the only moment the offset to hold can be read.
    //
    // A height change needs none of this - it moves the viewport, not the rows,
    // so the top-visible row keeps its offset by itself.
    onWidthChanged: d.anchorForResize()

    Column {
        id: rowsColumn

        width: root.width

        // Rendering bottom-up, rows too few to fill the viewport rest on its
        // bottom edge rather than hanging from the top - a chat with three
        // messages shows them above the composer, not under the header. Qt's
        // ListView does the same thing by moving originY.
        //
        // Nothing has to be corrected when this moves: it is only ever non-zero
        // while the content is shorter than the viewport, where contentY is
        // pinned at nought and there is nothing to hold.
        y: d.bottomUp ? Math.max(0, root.height - rowsColumn.height) : 0

        // forceLayout() only lays out with the heights known at that instant,
        // and a recycled row's real height arrives at the next polish. So the
        // content height that completeWave wrote is provisional, and so was the
        // clamp applied to contentY with it. Correcting again here costs nothing
        // (restorePosition is absolute and idempotent) and does not rely on the
        // anchor happening to move, which in a downward slide it does not: the
        // rows that grow are below it.
        onHeightChanged: {
            d.applyContentHeight()
            d.restorePosition()
        }

        // Where the placeholder waits when no placement wants it. Outside the
        // column, so a parked placeholder reserves no space.
        Item {
            id: placeholderPark

            parent: root
            visible: false
            width: 0
            height: 0
        }

        // The header/footer slots
        Loader {
            id: topSlot

            // named so a test can tell which placement holds the slot
            objectName: "topSlot"

            width: rowsColumn.width

            sourceComponent: d.bottomUp ? root.footer : root.header
            visible: !!sourceComponent
        }

        // The three placements. Each reserves its own space and is empty until
        // the one instance is moved into it. Invisible children leave a Column's
        // layout entirely, so a band that is not wanted costs nothing.
        Item {
            id: fillBand

            // The band owns the space it reserved: a placeholder whose content
            // is taller than the band it is put in must not draw over the rows.
            clip: true

            // named so a test can tell which placement holds the instance
            objectName: "fillPlaceholder"

            width: rowsColumn.width
            height: root.height
            visible: root.initialLoading && !!root.placeholder

            onVisibleChanged: d.applyPlaceholder()
        }

        Item {
            id: topBand

            // The band owns the space it reserved: a placeholder whose content
            // is taller than the band it is put in must not draw over the rows.
            clip: true

            // named so a test can tell which placement holds the instance
            objectName: "topPlaceholder"

            width: rowsColumn.width
            height: root.placeholderHeight
            visible: !root.initialLoading && !!root.placeholder
                     && (root.moreAvailableTop || d.pendingTop)

            onVisibleChanged: d.applyPlaceholder()
        }

        Repeater {
            id: rowsRepeater

            model: d.effectiveModel

            // A shell: it holds the row's place and its content, and knows
            // nothing about what the content is.
            delegate: Item {
                id: shell

                required property var model
                required property int index

                // The row this shell holds, in the model's numbering - the
                // space every public function speaks, and the one the provider
                // is handed. Live, so it stays right while an answer is owed.
                readonly property int row: d.bottomUp
                        ? d.modelRowsFor(root.rowCount) - 1 - shell.index
                        : shell.index

                property Item content: null

                // Not shown the moment its content arrives. A row built
                // outside a slide is a batch of one and reveals itself; one
                // built for a slide waits until the whole batch is ready, so
                // the batch appears in a single frame instead of trickling in.
                property bool revealed: false

                // Whether this row belongs to the batch a slide admitted, and
                // is still waiting for its content.
                property bool staged: false

                readonly property var rowKey:
                    shell.model ? shell.model[root.keyRole] : undefined

                // Width is pinned unconditionally, height is gated on the
                // reveal. That asymmetry is deliberate and load-bearing: a
                // staged row still lays its content out at the final width, so
                // its height is measurable before it is ever shown. Make the
                // width conditional on `revealed` as well and a staged row
                // never measures - the settle wait below would then never see a
                // stable sum and the cap would fire on every slide.
                width: rowsColumn.width
                height: shell.revealed && shell.content
                        ? shell.content.implicitHeight : 0
                visible: shell.revealed

                onRevealedChanged: d.revealedCount += shell.revealed ? 1 : -1

                Component.onCompleted: {
                    if (!root.acquireDelegate)
                        return

                    // Nothing on screen and nothing asked for: this row is
                    // the first of a fresh population, so it opens the batch
                    // its siblings will claim from.
                    if (!d.loading && !d.initialLoading && d.showingNothing())
                        d.beginFreshFill()

                    // An open batch that removed every row before adding these
                    // is replacing the population: the fill placeholder covers
                    // it until the reveal.
                    if (d.batchOpen && d.showingNothing())
                        d.initialLoading = true

                    // Either its key was captured before the Repeater built it,
                    // or the Repeater won the race and the outstanding request
                    // is what tells it to wait. Both mean the same thing.
                    shell.staged = d.claimStagedRow(shell) || d.loading

                    root.acquireDelegate(shell, shell.row, shell.model, (obj) => {
                        // The row can be gone by the time a deferred answer
                        // arrives. Checking the id is what works: it reads null
                        // once the shell is destroyed, while a captured JS
                        // reference to the same object stays truthy - which is
                        // why the provider cannot reliably check this itself.
                        if (!shell) {
                            if (obj && root.releaseDelegate)
                                root.releaseDelegate(obj)
                            return
                        }

                        shell.content = obj

                        if (shell.staged) {
                            shell.staged = false
                            d.contentArrived()
                        } else {
                            shell.revealed = true
                        }
                    })
                }

                // The content is handed back before the shell dies: children
                // are deleted with it, so an item still parented here would go
                // too. releaseDelegate is checked because a teardown cascade
                // can reach it first, and an exception thrown here disappears
                // without trace.
                Component.onDestruction: {
                    // A destroyed row fires no property change, so the count
                    // it contributed is given back here.
                    if (shell.revealed)
                        --d.revealedCount

                    d.forgetRow(shell)

                    if (d.anchorItem === shell)
                        d.releaseAnchor()

                    if (shell.content && root.releaseDelegate) {
                        root.releaseDelegate(shell.content)
                        shell.content = null
                    }

                    if (shell.staged) {
                        shell.staged = false
                        d.contentArrived()
                    }
                }
            }
        }

        Item {
            id: bottomBand

            // The band owns the space it reserved: a placeholder whose content
            // is taller than the band it is put in must not draw over the rows.
            clip: true

            // named so a test can tell which placement holds the instance
            objectName: "bottomPlaceholder"

            width: rowsColumn.width
            height: root.placeholderHeight
            visible: !root.initialLoading && !!root.placeholder
                     && (root.moreAvailableBottom || d.pendingBottom)

            onVisibleChanged: d.applyPlaceholder()
        }

        // The other placement: the screen's bottom.
        Loader {
            id: bottomSlot

            objectName: "bottomSlot"

            width: rowsColumn.width

            sourceComponent: d.bottomUp ? root.header : root.footer
            visible: !!sourceComponent
        }
    }

    onInitialLoadingChanged: d.applyPlaceholder()

    Component.onCompleted: {
        if (!root.acquireDelegate || !root.releaseDelegate)
            console.warn("WindowedView: acquireDelegate/releaseDelegate are not"
                         + " both set; rows will be empty or never released")
    }
}
