pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core.Utils as SQUtils

/*
  A view that renders the rows of whatever model it is given, stages what it is
  told to wait for, and holds the viewport still.

  It owns no window, no proxy and no fetch. When a placeholder edge comes into
  reach it asks - moreRequestedStart/End - and whoever owns the data answers
  however it likes: by moving an index window's bounds, or by calling a backend
  that replies much later. Everything that arrives between the request and
  moreLoadedStart/End() is one batch, revealed in a single frame once every row
  of it has content and the heights have stopped moving.

  loadingStart/End belong to the view, set the moment it asks, because the view
  is the only party that knows a request exists. The owner's obligation is one
  call to moreLoadedStart/End() per request - whatever arrived, even nothing.

  batchRevealed() fires inside the reveal, in the same turn: an owner that
  defers removals (an index window trimming its far end) must do them there, or
  the two ends change in different frames and the content height moves twice.

  Position is held in one of two ways, and they do not compete. While a slide is
  in flight a surviving row is anchored and its offset re-applied whenever it
  moves, which is what keeps the content still to the pixel. Outside a slide,
  and only with stickToEnd set, a viewport already at the bottom edge is kept
  there as the content grows. The anchor wins wherever both could apply.

  Row contract: the item handed back must have an intrinsic implicitHeight and
  must not size itself to its parent - a row that does collapses to zero height
  with no warning.
*/

Flickable {
    id: root

    // The rows to render. Whoever owns it also owns what "more" means.
    property var model: null

    // function(parent, modelRow, cb) - hand a row item back through cb(obj).
    // May answer synchronously or later; both are supported.
    property var acquireDelegate
    // function(obj) - the item is no longer needed.
    property var releaseDelegate

    // The role that identifies a row. A fetch admits an unknown number of rows,
    // so membership in a batch is a set of keys rather than a count. A model
    // without this role still works - those rows reveal themselves individually
    // instead of joining a batch.
    property string keyRole: "key"

    // Set by whoever owns the data: is there anything beyond each end?
    property bool moreAvailableStart: false
    property bool moreAvailableEnd: false

    // Stands in for content that is not there yet: the whole viewport while the
    // first population is being gathered, and a band at either end while more is
    // available there or on its way. Instantiated once, on first need, and moved
    // between those placements - so it must fill whatever space it is given. The
    // view sets its width and height; an intrinsic height of its own is
    // overridden.
    property Component placeholder: null

    // Ask for more by itself when a band the user can see still has content
    // behind it. The band is the trigger area, so a view with no placeholder
    // reserves nothing and pages only when told to.
    property bool autoRequest: true

    // Space each end reserves for the placeholder. The single instance only ever
    // occupies the end nearer the viewport, so the other end reserves this much
    // blank.
    property real placeholderHeight: root.height

    // Keep the viewport at the bottom edge while it is already there, so the
    // last row stays visible as content grows and the initial fill lands
    // showing the newest row rather than the oldest. Off by default: for a
    // top-down list a short model growing past the viewport should stay put.
    property bool stickToEnd: false

    readonly property int rowCount: rowsRepeater.count

    // The viewport is at the bottom of the content. Whoever owns the data needs
    // this to tell a row that should simply be shown from one that should be
    // announced: arriving at the end while the user is already there is the
    // first, and arriving while they are reading further up is the second.
    readonly property bool atEnd: d.atEndOfContent()

    // A request is outstanding in that direction. The view owns these because
    // it is the only party that knows it asked.
    readonly property bool loadingStart: d.loadingStart
    readonly property bool loadingEnd: d.loadingEnd

    // A batch has been admitted and is being made ready - shells built, content
    // acquired, heights settling - but is not on screen yet. The phase after the
    // owner has answered, and separate from loadingStart/End, which cover only
    // the wait for that answer. A synchronous owner has no loading phase worth
    // seeing at all, and all of the time goes here.
    readonly property bool staging: d.wave.length > 0

    // Either a request is outstanding, a batch is staged and unrevealed, or a
    // fresh population is still being gathered.
    readonly property bool busy: d.loadingStart || d.loadingEnd
                                 || root.staging || d.initialLoading

    // A fresh population - a first load, or a jump that replaced every row - is
    // being staged and has not been revealed yet: the view is showing nothing
    // and will show all of it at once. Distinct from busy, which is equally
    // true while paging over content that is already on screen, so this is the
    // one to hang a skeleton on.
    readonly property bool initialLoading: d.initialLoading

    // "I would like more rows at this end." Nothing is promised.
    signal moreRequestedStart()
    signal moreRequestedEnd()

    // Fired inside the reveal, in the same turn. An owner deferring removals
    // must perform them in this handler.
    signal batchRevealed()

    // Asks for more at one end, once. Ignored while that end is loading or has
    // nothing more to give.
    function requestMoreStart() {
        return d.request(true)
    }

    function requestMoreEnd() {
        return d.request(false)
    }

    // The owner's answer: whatever arrived, that is the batch. Called exactly
    // once per request, even when nothing arrived.
    function moreLoadedStart() {
        d.loaded(true)
    }

    function moreLoadedEnd() {
        d.loaded(false)
    }

    function itemAtRow(row) {
        return rowsRepeater.itemAt(row)
    }

    contentWidth: width

    // contentHeight is assigned, never bound: writing it runs Flickable's own
    // fixup, which moves contentY, and every internal contentY write has to be
    // distinguishable from a user scroll (see d.apply).


    QtObject {
        id: d

        property bool loadingStart: false
        property bool loadingEnd: false

        readonly property bool loading: d.loadingStart || d.loadingEnd

        // A batch asked for at this end has been admitted but not revealed yet.
        // The band has to stand for all of it: an owner that answers inside the
        // signal clears loading* immediately, and "nothing more beyond this"
        // arrives at the same moment - so without this the placeholder comes
        // down at request time and the rows that replace it appear separately,
        // which is the two-step change everything else here works to avoid.
        readonly property bool pendingStart: d.loadingStart
                                             || (d.wave.length > 0 && d.requestedAtStart)
        readonly property bool pendingEnd: d.loadingEnd
                                           || (d.wave.length > 0 && !d.requestedAtStart)

        // How far this slide is going, and how many of the rows it added are
        // still waiting for content. Rows count themselves in and out.
        // Which end the outstanding request was made at, so the anchor and the
        // reveal know which side is growing.
        property bool requestedAtStart: false
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
        // not cheap, and availability at an end toggles constantly.
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
        readonly property bool shouldRequestMore:
                root.autoRequest && !root.busy && !d.finishing && !d.scrollBarHeld
                && ((root.moreAvailableStart && d.bandInViewport(startBand))
                    || (root.moreAvailableEnd && d.bandInViewport(endBand)))

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

            // The start end first, so a view short enough to show both bands
            // walks back through the history rather than fighting itself.
            if (root.moreAvailableStart && d.bandInViewport(startBand))
                d.request(true)
            else if (root.moreAvailableEnd && d.bandInViewport(endBand))
                d.request(false)
        }

        // Whether a band overlaps what the user can see. Both ends can be on
        // screen at once when the whole window fits with room to spare.
        function bandInViewport(band) {
            return band.visible && band.y < root.contentY + root.height
                    && band.y + band.height > root.contentY
        }

        // How far a band's nearest edge is from the viewport, for picking
        // between two that are both on screen.
        function bandDistance(band) {
            const middle = root.contentY + root.height / 2

            return Math.abs(band.y + band.height / 2 - middle)
        }

        function chooseHost() {
            if (!root.placeholder)
                return null

            if (fillBand.visible)
                return fillBand

            const start = d.bandInViewport(startBand)
            const end = d.bandInViewport(endBand)

            if (start && end)
                return d.bandDistance(startBand) <= d.bandDistance(endBand)
                        ? startBand : endBand

            if (start)
                return startBand

            if (end)
                return endBand

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

        // What the start band contributes above the rows, as the current
        // contentY already accounts for it. Its `height` is a constant, so what
        // actually changes is whether it is shown at all - a Column drops an
        // invisible child from its layout entirely.
        property real appliedStartBand: 0

        function startBandExtent() {
            return startBand.visible ? startBand.height : 0
        }

        function applyContentHeight() {
            d.preservingFlick(d.applyContentHeightNow)
        }

        function applyContentHeightNow() {
            // Sampled before the write, while contentHeight still describes the
            // bottom the viewport was actually sitting at - and against the
            // height it was sitting in, which a resize has already changed.
            const wasAtEnd = d.wasAtEndOfContent()
            const startBandDelta = d.startBandExtent() - d.appliedStartBand
            const was = d.applyingPosition

            d.appliedStartBand = d.startBandExtent()

            d.applyingPosition = true
            root.contentHeight = Math.max(root.height, rowsColumn.height)

            // The start band grew or shrank above the rows, so without this
            // every one of them shifts by that much - visibly, since outside a
            // slide no anchor is armed to absorb it. The end band needs nothing:
            // it is below the viewport. Applied before the stickToEnd pin, and
            // restorePosition() still runs after this and wins whenever an
            // anchor is armed.
            // Not during a reveal: there the band's appearing is part of content
            // arriving all at once, and the anchor - or the stickToEnd pin - owns
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
            if (root.stickToEnd && wasAtEnd && !d.anchorItem && !root.moving)
                root.contentY = d.bottomY()      // guard already held

            d.appliedHeight = root.height
            d.applyingPosition = was
        }

        // Whether the viewport is at the bottom of the content as contentHeight
        // currently describes it. Not Flickable.atYEnd: this is read inside a
        // height handler, where contentHeight still holds the pre-change value -
        // which is the point - and a sub-pixel gap must still count as the end.
        function atEndOfContent() {
            return root.contentY >= Math.max(0, root.contentHeight - root.height) - 1
        }

        // The viewport height the current contentY was last reconciled against.
        // A resize changes `height` before this runs, so asking whether the view
        // *was* at the end has to be asked of the geometry it was placed in:
        // shrinking moves the bottom down, and measured against the new height a
        // viewport sitting exactly at the old bottom reads as no longer there -
        // which is how shrinking lost stickToEnd while growing kept it.
        property real appliedHeight: 0

        function wasAtEndOfContent() {
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

        function restorePosition() {
            if (!d.anchorItem)
                return

            // A row the Column has not placed yet. Positioners lay their
            // children out one at a time, and a correction can be asked for
            // from the middle of that pass - the anchor's own y change is what
            // asks for it. No child of a Column ever legitimately sits above
            // its origin, so this is a position the layout cannot have
            // produced, and a target computed from it clamps the viewport to
            // the top and loses where the content was.
            if (d.anchorItem.y < 0)
                return

            // Absolute, not relative, so re-applying it converges instead of
            // drifting - which is what makes holding the anchor safe.
            const target = d.anchorItem.y - d.anchorOffset
            const bottom = d.bottomY()

            d.apply(Math.max(0, Math.min(bottom, target)))

            // The correction ran into the end and stopped there, so holding a
            // row no longer describes where the view is - the bottom does. A
            // view told to follow the end has to go back to following it, or it
            // sits at the bottom without being stuck to it and the next row to
            // arrive leaves it behind. Not while a slide is in flight: there the
            // anchor is the guarantee, and the far end has yet to be trimmed.
            if (root.stickToEnd && !root.busy && target >= bottom
                    && root.contentY >= bottom - 0.5)
                d.releaseAnchor()
        }

        function holdAnchor(item) {
            d.anchorItem = item
            d.anchorOffset = item.y - root.contentY
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
            // At the end and asked to stay there, the bottom *is* the position,
            // and the pin in applyContentHeight() keeps it. Arming here would
            // suppress that pin, which is conditioned on there being no anchor.
            if (root.stickToEnd && d.atEndOfContent())
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
                if (item.y >= root.contentY + root.height)
                    break

                if (item.y >= root.contentY - 0.5) {
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
        // Growing at the start trims at the end, so a row at the top is safe;
        // growing at the end trims at the start, so it is the bottom. Returns
        // whether it found one; a failure leaves any existing anchor alone.
        function armAnchor(atStart) {
            const edge = atStart ? root.contentY : root.contentY + root.height

            let best = null
            let bestDistance = Number.MAX_VALUE

            for (let i = 0; i < rowsRepeater.count; ++i) {
                const item = rowsRepeater.itemAt(i)

                if (!item || !item.visible)
                    continue

                const distance = Math.abs(item.y - edge)

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
            if (!d.loading && d.wave.length === 0) {
                d.releaseAnchor()
                return
            }

            if (d.armAnchor(d.requestedAtStart))
                return

            // Nothing that survives is on screen: the user has scrolled into
            // the rows being removed, which is the one case where staying put
            // is impossible. Hold what we have and re-measure it, so the
            // content that does survive still lands where it belongs.
            if (d.anchorItem)
                d.anchorOffset = d.anchorItem.y - root.contentY
        }

        // Asks the owner for more at one end. Nothing is admitted here - the
        // owner may answer inside this call by moving a window's bounds, or much
        // later from a backend. Either way every row that arrives before
        // moreLoaded*() is one batch.
        function request(atStart) {
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

            if (atStart ? !root.moreAvailableStart : !root.moreAvailableEnd)
                return false

            d.wave = []
            d.stagedKeys = new Set()
            d.noProgressIntervals = 0

            // Armed before anything can arrive, while the geometry is settled.
            // Requesting at the start grows above and trims below, so a row at
            // the viewport top survives; at the end it is the other way round.
            d.releaseAnchor()
            d.armAnchor(atStart)

            d.requestedAtStart = atStart

            if (atStart)
                d.loadingStart = true
            else
                d.loadingEnd = true

            // Rows admitted synchronously inside the signal are captured by the
            // model connection below, and shells built inside it stage
            // themselves because loading is already true.
            d.admitting = true

            if (atStart)
                root.moreRequestedStart()
            else
                root.moreRequestedEnd()

            d.admitting = false

            acquireTimer.restart()
            d.checkWaveComplete()
            return true
        }

        // The owner is done. Whatever arrived is the batch; it may be nothing.
        function loaded(atStart) {
            if (atStart ? !d.loadingStart : !d.loadingEnd)
                return      // no request outstanding at that end

            if (atStart)
                d.loadingStart = false
            else
                d.loadingEnd = false

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
            return root.model ? SQUtils.ModelUtils.get(root.model, row, root.keyRole)
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
            const rows = root.model ? root.model.rowCount() : 0

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

    // The view does not own the model, so the staging handlers live here.
    // Ordering against the Repeater's own connection is deliberately not relied
    // on: a shell built before its key was captured stages itself because a
    // request is outstanding, and one built afterwards claims the key.
    Connections {
        target: root.model

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
            d.loadingStart = false
            d.loadingEnd = false
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
            id: startBand

            // The band owns the space it reserved: a placeholder whose content
            // is taller than the band it is put in must not draw over the rows.
            clip: true

            // named so a test can tell which placement holds the instance
            objectName: "startPlaceholder"

            width: rowsColumn.width
            height: root.placeholderHeight
            visible: !root.initialLoading && !!root.placeholder
                     && (root.moreAvailableStart || d.pendingStart)

            onVisibleChanged: d.applyPlaceholder()
        }

        Repeater {
            id: rowsRepeater

            model: root.model

            // A shell: it holds the row's place and its content, and knows
            // nothing about what the content is.
            delegate: Item {
                id: shell

                required property var model

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

                    // Either its key was captured before the Repeater built it,
                    // or the Repeater won the race and the outstanding request
                    // is what tells it to wait. Both mean the same thing.
                    shell.staged = d.claimStagedRow(shell) || d.loading

                    root.acquireDelegate(shell, shell.model, (obj) => {
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
            id: endBand

            // The band owns the space it reserved: a placeholder whose content
            // is taller than the band it is put in must not draw over the rows.
            clip: true

            // named so a test can tell which placement holds the instance
            objectName: "endPlaceholder"

            width: rowsColumn.width
            height: root.placeholderHeight
            visible: !root.initialLoading && !!root.placeholder
                     && (root.moreAvailableEnd || d.pendingEnd)

            onVisibleChanged: d.applyPlaceholder()
        }
    }

    onInitialLoadingChanged: d.applyPlaceholder()

    Component.onCompleted: {
        if (!root.acquireDelegate || !root.releaseDelegate)
            console.warn("WindowedView: acquireDelegate/releaseDelegate are not"
                         + " both set; rows will be empty or never released")
    }
}
