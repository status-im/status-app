pragma ComponentBehavior: Bound

import QtQuick

import SortFilterProxyModel
import QtModelsToolkit

/*
  A view that renders only a window of its source model, and asks someone else
  for the row content.

  It owns three things and nothing more:

    the window   an IndexFilter slice [windowFirst, windowLast] of sourceModel.
    the slide    moving that window by N rows in two phases - grow one end,
                 and trim the other only once every incoming row is ready, so
                 the two ends never change in the same frame.
    the position the viewport is held still across a slide.

  It knows no model roles, no delegate type and no cache. Row content arrives
  through `acquireDelegate` and goes back through `releaseDelegate`; whoever
  supplies those decides what a row looks like and whether items are recycled.

  Row contract: the item handed back must have an intrinsic implicitHeight and
  must not size itself to its parent - a row that does collapses to zero height
  with no warning.

  Known limitation: which rows belong to a slide's batch is decided by when
  their shells are created. Under an asynchronous ancestor - Storybook's "Load
  pages asynchronously" setting, for instance - shells are created after the
  slide has returned and the batch mis-counts. Capturing membership by row key
  at mutation time is the fix, and is not done here.
*/
Flickable {
    id: root

    property var sourceModel: null

    // function(parent, modelRow, cb) - hand a row item back through cb(obj).
    // May answer synchronously or later; both are supported.
    property var acquireDelegate
    // function(obj) - the item is no longer needed.
    property var releaseDelegate

    // Written by the slide, so a caller must not bind these - assign them, and
    // read them back through the change signal.
    // The role that identifies a row. Batch membership is captured by key, not
    // by when a shell happened to be created, so it survives an asynchronous
    // ancestor and an insertion landing mid-slide. A model without this role
    // still works - those rows simply reveal themselves individually instead of
    // joining a batch.
    property string keyRole: "key"

    property int windowFirst: 0
    property int windowLast: 59

    readonly property int windowSize: root.windowLast - root.windowFirst + 1
    readonly property int rowCount: rowsRepeater.count

    readonly property int sourceRowCount:
        root.sourceModel ? root.sourceModel.ModelCount.count : 0

    // True while a slide in that direction is waiting for its rows. "Up" means
    // toward the beginning of the model.
    readonly property bool movingUp: d.movingUp
    readonly property bool movingDown: d.movingDown

    // Move the window, clamped to what the model has left. Returns how far it
    // actually went; 0 if it could not move or a slide is already running.
    function slideWindowUp(count) {
        return d.startSlide(-count)
    }

    function slideWindowDown(count) {
        return d.startSlide(count)
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

        property bool movingUp: false
        property bool movingDown: false

        readonly property bool moving: d.movingUp || d.movingDown

        // How far this slide is going, and how many of the rows it added are
        // still waiting for content. Rows count themselves in and out.
        property int slideAmount: 0
        // Keys admitted by the slide whose shells do not exist yet, and the
        // shells that have claimed one. A batch is complete when no key is
        // outstanding and every claimed shell has content.
        property var stagedKeys: new Set()
        property bool keyWarningShown: false

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

        // Load-bearing: completion is synchronous, so without this the first
        // row to answer finishes the slide from inside the Repeater's creation
        // pass and the far end is trimmed against a half-built window.
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

        function apply(y) {
            const was = d.applyingPosition

            d.applyingPosition = true
            root.contentY = y
            d.applyingPosition = was
        }

        function applyContentHeight() {
            const was = d.applyingPosition

            d.applyingPosition = true
            root.contentHeight = Math.max(root.height, rowsColumn.height)
            d.applyingPosition = was
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

            // Absolute, not relative, so re-applying it converges instead of
            // drifting - which is what makes holding the anchor safe.
            const target = d.anchorItem.y - d.anchorOffset

            d.apply(Math.max(0, Math.min(d.bottomY(), target)))
        }

        // Picks the row nearest the viewport top that will survive the trim.
        // Returns whether it found one; a failure leaves any existing anchor
        // alone rather than dropping it.
        //
        // Index-based on the *current* window, so it is equally valid before
        // the bound moves and while a slide is in flight: sliding down the trim
        // takes the first n rows, sliding up the last n, either way.
        function armAnchor(delta, n) {
            const count = rowsRepeater.count
            const firstSurvivor = delta > 0 ? n : 0
            const lastSurvivor = delta > 0 ? count - 1 : count - 1 - n

            let best = null
            let bestDistance = Number.MAX_VALUE

            for (let i = firstSurvivor; i <= lastSurvivor; ++i) {
                const item = rowsRepeater.itemAt(i)

                if (!item || !item.visible)
                    continue

                const distance = Math.abs(item.y - root.contentY)

                if (distance < bestDistance) {
                    bestDistance = distance
                    best = item
                }
            }

            if (!best)
                return false

            d.anchorItem = best
            d.anchorOffset = best.y - root.contentY
            return true
        }

        // A manual move while a slide is in flight must not cost the
        // guarantee - dropping the anchor there is what made the batch reveal
        // jump by the height of everything that changed. Re-anchor to where the
        // user has just put the view instead. Outside a slide the anchor has no
        // work to do.
        function userMoved() {
            if (!d.moving) {
                d.releaseAnchor()
                return
            }

            if (d.armAnchor(d.movingDown ? 1 : -1, d.slideAmount))
                return

            // Nothing that survives is on screen: the user has scrolled into
            // the rows being removed, which is the one case where staying put
            // is impossible. Hold what we have and re-measure it, so the
            // content that does survive still lands where it belongs.
            if (d.anchorItem)
                d.anchorOffset = d.anchorItem.y - root.contentY
        }

        // IndexFilter judges a row by its position, and QSortFilterProxyModel
        // never re-tests a row it has already judged: an insertion renumbers
        // the rows after it, so accepted rows stay accepted past maximumIndex
        // and rejected rows never come back into range.
        //
        // Wired from the proxy's own sourceModelChanged rather than from a
        // handler on the model, because the order matters: re-filtering from a
        // slot that runs before the proxy has processed the same change is at
        // best undone, and on a removal leaves empty rows behind.
        // QAbstractProxyModel emits sourceModelChanged after wiring its
        // internal connections, so this lands after the proxy's own handler.
        function rewireInvalidation() {
            if (d.wiredModel) {
                d.wiredModel.rowsInserted.disconnect(windowFilter.invalidated)
                d.wiredModel.rowsRemoved.disconnect(windowFilter.invalidated)
            }

            d.wiredModel = windowModel.sourceModel

            if (d.wiredModel) {
                d.wiredModel.rowsInserted.connect(windowFilter.invalidated)
                d.wiredModel.rowsRemoved.connect(windowFilter.invalidated)
            }
        }

        // Grows the window at one end and leaves the other alone. The opposite
        // end is trimmed in completeWave(), once every row added here has
        // content.
        function startSlide(delta) {
            if (d.moving)
                return 0

            const room = delta > 0 ? root.sourceRowCount - 1 - root.windowLast
                                   : root.windowFirst
            const n = Math.min(Math.abs(delta), room)

            if (n <= 0)
                return 0

            d.slideAmount = n
            d.stagedKeys = new Set()
            d.wave = []
            d.noProgressIntervals = 0

            // Before anything moves, while the geometry is still settled.
            d.releaseAnchor()
            d.armAnchor(delta, n)

            d.admitting = true

            if (delta > 0) {
                d.movingDown = true
                root.windowLast += n
            } else {
                d.movingUp = true
                root.windowFirst -= n
            }

            d.admitting = false

            // Nothing outstanding means a warm cache answered every row inside
            // the bound assignment; otherwise the stall detector guards the wait.
            if (d.stagedKeys.size === 0 && d.waveWaiting().length === 0)
                d.beginSettling()
            else
                acquireTimer.restart()

            return n
        }

        // Reveals the batch, drops the far end, and puts the viewport back
        // where it was. Only the change *above* the viewport moves anything on
        // screen, and every surviving row shifts by the same amount, so any one
        // of them serves as the reference.
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

            // The trim belongs to the slide and happens once, with the first
            // wave: that is what makes the two ends change together.
            if (d.slideAmount > 0) {
                if (d.movingDown)
                    root.windowFirst += d.slideAmount
                else
                    root.windowLast -= d.slideAmount

                d.slideAmount = 0
                d.movingUp = false
                d.movingDown = false
            }

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
        function captureStagedRows(first, last) {
            if (!d.admitting)
                return

            for (let i = first; i <= last; ++i) {
                const key = windowModel.get(i, root.keyRole)

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
                const key = windowModel.get(i, root.keyRole)

                if (key !== undefined && key !== null && d.stagedKeys.delete(key))
                    dropped = true
            }

            if (dropped)
                d.checkWaveComplete()
        }

        function clearStaging() {
            d.stagedKeys = new Set()

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

            d.wave.push(shell)
            return true
        }

        function forgetRow(shell) {
            const i = d.wave.indexOf(shell)

            if (i !== -1) {
                d.wave.splice(i, 1)
                d.checkWaveComplete()
            }
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

        // Not gated on d.moving: a wave can outlive the slide that created it.
        function checkWaveComplete() {
            if (d.finishing || d.admitting)
                return

            if (d.wave.length === 0)
                return

            if (d.stagedKeys.size > 0 || d.waveWaiting().length > 0)
                return

            acquireTimer.stop()
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

    SortFilterProxyModel {
        id: windowModel

        sourceModel: root.sourceModel

        filters: IndexFilter {
            id: windowFilter

            minimumIndex: root.windowFirst
            maximumIndex: root.windowLast
        }

        onSourceModelChanged: d.rewireInvalidation()

        // Declared on the proxy itself so these run before the Repeater's: a
        // shell built synchronously must already find its key captured.
        onRowsInserted: (parent, first, last) => d.captureStagedRows(first, last)
        // aboutToBeRemoved, while the key is still readable
        onRowsAboutToBeRemoved: (parent, first, last) => d.dropStagedRows(first, last)
        // a reset removes every row with no per-row signal
        onModelAboutToBeReset: {
            d.clearStaging()

            if (d.moving)
                d.completeWave()
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
    }

    onHeightChanged: {
        d.applyContentHeight()
        d.restorePosition()
    }

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

        Repeater {
            id: rowsRepeater

            model: windowModel

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

                Component.onCompleted: {
                    if (!root.acquireDelegate)
                        return

                    shell.staged = d.claimStagedRow(shell)

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
    }

    Component.onCompleted: {
        if (!root.acquireDelegate || !root.releaseDelegate)
            console.warn("WindowedView: acquireDelegate/releaseDelegate are not"
                         + " both set; rows will be empty or never released")
    }
}
