import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTest

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils

Item {
    id: root

    width: 500
    height: 400

    readonly property int chunk: 10
    readonly property int windowSize: 20

    // ------------------------------------------------------------------
    // Row content. Two shapes, because they settle differently.
    // ------------------------------------------------------------------

    // implicitHeight computed arithmetically: final the instant it is set, so
    // most groups are unaffected by layout timing.
    Component {
        id: plainDelegate

        Item {
            property int value: 0

            // varies with the row, so the suite has tall and short rows
            implicitHeight: 20 + (value % 5) * 30
        }
    }

    // implicitHeight routed through a QQuickLayout, which recomputes on polish.
    // A recycled item therefore reports its *previous* height until then, which
    // is the whole reason the view waits for heights to settle.
    Component {
        id: layoutDelegate

        Item {
            id: layoutRow

            property int value: 0

            implicitHeight: column.height

            ColumnLayout {
                id: column

                anchors.left: parent.left
                anchors.right: parent.right

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20 + (layoutRow.value % 5) * 30
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // The provider: where rows come from, and how slowly.
    // ------------------------------------------------------------------
    QtObject {
        id: provider

        property Component delegate: plainDelegate
        property int delay: 0              // ms before answering; 0 = synchronously
        property bool mute: false           // answer never arrives
        property bool pooled: false

        property int builtCount: 0
        property int acquiredCount: 0
        property var parked: []

        // Maintained explicitly: mutating a `property var` array in place
        // notifies nothing, so a binding on parked.length would never update.
        property int availableCount: 0

        // Which shell acquire() was handed for which row number, so a test can
        // hold the view to the numbers it gives out.
        property var dressedAt: ({})
        property int dressedCount: 0

        function forgetDressing() {
            provider.dressedAt = ({})
            provider.dressedCount = 0
        }

        function acquire(parent, row, modelRow, callback) {
            provider.dressedAt[row] = parent
            provider.dressedCount++

            const deliver = () => {
                if (!parent || provider.mute)
                    return

                let item = null

                if (provider.pooled && provider.parked.length > 0) {
                    item = provider.parked.pop()
                    provider.availableCount = provider.parked.length
                } else {
                    item = provider.delegate.createObject(parkingLot)
                    provider.builtCount++
                }

                item.value = modelRow.value
                item.parent = parent
                item.visible = true
                provider.acquiredCount++
                callback(item)
            }

            if (provider.delay <= 0)
                deliver()
            else
                deliveryTimer.fire(deliver, provider.delay)
        }

        function release(item) {
            if (!item)
                return

            provider.acquiredCount--

            if (!provider.pooled) {
                item.destroy()
                return
            }

            item.parent = parkingLot
            item.visible = false
            provider.parked.push(item)
            provider.availableCount = provider.parked.length
        }

        function reset() {
            for (let i = 0; i < provider.parked.length; ++i)
                provider.parked[i].destroy()

            provider.parked = []
            provider.availableCount = 0
            provider.builtCount = 0
            provider.acquiredCount = 0
            provider.mute = false
            provider.delay = 0
            provider.pooled = false
            provider.delegate = plainDelegate
            provider.forgetDressing()
        }
    }

    Item { id: parkingLot; visible: false }

    // Deferred deliveries, all on one timer so a batch waits in parallel.
    Timer {
        id: deliveryTimer

        property var queue: []

        interval: 16
        repeat: true

        function fire(callback, delay) {
            queue.push({ callback, dueAt: Date.now() + delay })
            running = true
        }

        function clear() {
            queue = []
            running = false
        }

        onTriggered: {
            const now = Date.now()
            const waiting = []

            for (let i = 0; i < queue.length; ++i) {
                if (queue[i].dueAt > now)
                    waiting.push(queue[i])
                else
                    queue[i].callback()
            }

            queue = waiting
            running = queue.length > 0
        }
    }

    // ------------------------------------------------------------------
    // The data owner. A bare ListModel - no proxy, no window component: the
    // view's contract is a model plus the two flags, and simulating loading by
    // hand keeps this suite about the view alone.
    // ------------------------------------------------------------------
    ListModel {
        id: rows

        // rows are `value`-stamped and carry the key role the view captures
        function make(from, count) {
            const out = []

            for (let i = 0; i < count; ++i)
                out.push({ key: "k" + (from + i), value: from + i })

            return out
        }
    }

    QtObject {
        id: owner

        property int nextEnd: 0             // next value to hand out at the end
        property int nextStart: -1          // next value to hand out at the start
        property bool removeOnReveal: true  // simulate a capped window

        // How many rows the last request admitted, so the reveal knows how many
        // to drop from the far end.
        property int admitted: 0
        property bool admittedAtStart: false

        // how many times the view revealed a batch, so a suite can assert a
        // slide cost exactly one reveal rather than one per row
        property int revealCount: 0

        // a row nobody asked for, as an external insert would be
        readonly property int liveValue: 9000

        // The heights the view revealed the batch at. Sampled inside the reveal,
        // because that is the only moment a stale height is observable - the
        // held anchor corrects the position a frame later, and by the time
        // tryVerify notices the view is idle the evidence is gone.
        property real sumAtReveal: -1

        function reset(initial) {
            deliveryTimer.clear()
            rows.clear()
            owner.nextEnd = 0
            owner.nextStart = -1
            owner.admitted = 0
            owner.revealCount = 0
            owner.removeOnReveal = true
            owner.sumAtReveal = -1

            if (initial > 0)
                rows.append(rows.make(0, initial))
            owner.nextEnd = initial
        }

        function admitEnd(count) {
            rows.append(rows.make(owner.nextEnd, count))
            owner.nextEnd += count
            owner.admitted = count
            owner.admittedAtStart = false
        }

        function admitStart(count) {
            const first = owner.nextStart - count + 1
            rows.insert(0, rows.make(first, count))
            owner.nextStart = first - 1
            owner.admitted = count
            owner.admittedAtStart = true
        }

        function appendLive() {
            rows.append(rows.make(owner.liveValue, 1))
        }

        // The deferred far-end removal, performed inside the view's reveal.
        function dropFarEnd() {
            if (!owner.removeOnReveal || owner.admitted === 0)
                return

            if (owner.admittedAtStart)
                rows.remove(rows.count - owner.admitted, owner.admitted)
            else
                rows.remove(0, owner.admitted)

            owner.admitted = 0
        }
    }

    WindowedView {
        id: view

        anchors.fill: parent

        model: rows

        moreAvailableTop: true
        moreAvailableBottom: true

        acquireDelegate: (parent, row, modelRow, cb) =>
                provider.acquire(parent, row, modelRow, cb)
        releaseDelegate: (item) => provider.release(item)

        onMoreRequestedTop: {
            owner.admitStart(root.chunk)
            view.moreLoadedTop()
        }

        onMoreRequestedBottom: {
            owner.admitEnd(root.chunk)
            view.moreLoadedBottom()
        }

        onBatchRevealed: {
            owner.revealCount++
            owner.sumAtReveal = revealedContentSum()
            owner.dropFarEnd()
        }

        ScrollBar.vertical: ScrollBar { id: scrollBar }
    }

    // ------------------------------------------------------------------
    // Shared helpers
    // ------------------------------------------------------------------
    function shells() {
        const out = []

        for (let i = 0; i < view.rowCount; ++i) {
            const shell = view.itemAtRow(i)

            if (shell)
                out.push(shell)
        }

        return out
    }

    // Total of the heights the rows are currently reporting.
    function revealedContentSum() {
        let sum = 0

        for (const shell of shells())
            if (shell.visible && shell.content)
                sum += shell.content.implicitHeight

        return sum
    }

    function hiddenShells() {
        return shells().filter(shell => !shell.visible)
    }

    function values() {
        return shells().filter(shell => shell.visible && shell.content)
                       .map(shell => shell.content.value)
    }

    // offset of an identified row below the viewport top; immune to a row
    // boundary landing exactly on contentY, which makes "the first visible row"
    // flip between two answers for a sub-pixel difference
    function offsetOf(value) {
        for (const shell of shells())
            if (shell.visible && shell.content && shell.content.value === value)
                return shell.y - view.contentY

        return NaN
    }

    // Rows being present is not the same as the Column having laid them out:
    // a positioner works off a polish, so a condition met on row count alone
    // can hold a frame before any geometry exists - and then every position
    // assertion reads contentHeight as the bare viewport height.
    function settled(expectedRows) {
        return !view.busy && view.rowCount === expectedRows
                && hiddenShells().length === 0
                && view.contentHeight > view.height
    }

    function topRow() {
        for (const shell of shells())
            if (shell.visible && shell.content && shell.y + shell.height > view.contentY + 0.01)
                return { value: shell.content.value, offset: shell.y - view.contentY }

        return { value: -9999, offset: 0 }
    }

    TestCase {
        id: positionTests

        name: "WindowedView.Position"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            provider.delay = 30
            owner.reset(60)     // tall enough that the viewport sits mid-content
            tryVerify(() => settled(60), 5000, "rows laid out")
        }

        function scrollToMiddle() {
            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            verify(view.contentY > 50, "there is room to scroll")
        }

        function heightOfFirst(count) {
            const all = shells()
            let total = 0

            for (let i = 0; i < count && i < all.length; ++i)
                total += all[i].height

            return total
        }

        function test_requestAtEndKeepsTheContentStill() {
            scrollToMiddle()

            const before = topRow()
            const contentY = view.contentY
            const dropped = heightOfFirst(root.chunk)

            verify(view.requestMoreBottom())
            tryVerify(() => !view.busy, 5000)

            const after = offsetOf(before.value)
            verify(!isNaN(after), "the anchor row " + before.value + " survived")
            fuzzyCompare(after, before.offset, 0.5, "the row did not move")
            fuzzyCompare(view.contentY, contentY - dropped, 0.5,
                         "contentY moved by exactly the dropped height")
        }

        function test_requestAtStartKeepsTheContentStill() {
            scrollToMiddle()

            const before = topRow()
            const contentY = view.contentY

            verify(view.requestMoreTop())
            tryVerify(() => !view.busy, 5000)

            const added = heightOfFirst(root.chunk)
            const after = offsetOf(before.value)
            verify(!isNaN(after), "the anchor row survived")
            fuzzyCompare(after, before.offset, 0.5, "the row did not move")
            fuzzyCompare(view.contentY, contentY + added, 0.5,
                         "contentY moved by exactly the added height")
        }

        function test_nothingMovesWhileTheBatchIsStaged() {
            scrollToMiddle()

            const before = topRow()
            const contentY = view.contentY

            verify(view.requestMoreBottom())
            verify(view.busy, "still staged")

            fuzzyCompare(offsetOf(before.value), before.offset, 0.5,
                         "the viewport is untouched mid-load")
            fuzzyCompare(view.contentY, contentY, 0.5)

            tryVerify(() => !view.busy, 5000)
        }

        function test_noOverscrollAtTheTop() {
            view.contentY = 0

            verify(view.requestMoreBottom())
            tryVerify(() => !view.busy, 5000)

            verify(view.contentY >= 0, "not overscrolled: " + view.contentY)
            verify(!isNaN(view.contentY))
        }

        function test_noOverscrollAtTheBottom() {
            view.contentY = view.contentHeight - view.height

            verify(view.requestMoreTop())
            tryVerify(() => !view.busy, 5000)

            verify(view.contentY >= 0)
            verify(view.contentY <= view.contentHeight - view.height + 0.5,
                   "within the extents: " + view.contentY)
        }
    }

    TestCase {
        id: manualMoveTests

        name: "WindowedView.ManualMove"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            provider.delay = 120        // long enough to scroll during the load
            owner.reset(60)
            tryVerify(() => settled(60), 5000, "rows laid out")
        }

        // Dropping the anchor when the user takes over is what made the reveal
        // jump by the height of everything that changed. A manual move must
        // re-anchor instead.
        function moveDuringLoad(request, delta) {
            view.contentY = Math.round((view.contentHeight - view.height) / 2)

            verify(request(), "the request was taken")
            verify(view.busy, "in flight")

            view.contentY = Math.max(0, view.contentY + delta)

            const before = topRow()
            tryVerify(() => !view.busy, 5000)

            const after = offsetOf(before.value)
            verify(!isNaN(after), "the row the user was looking at survived")
            fuzzyCompare(after, before.offset, 0.5, "content stayed in place")
        }

        function test_scrollingDownDuringAnEndRequest() {
            moveDuringLoad(() => view.requestMoreBottom(), 200)
        }

        function test_scrollingUpDuringAStartRequest() {
            moveDuringLoad(() => view.requestMoreTop(), -200)
        }
    }

    TestCase {
        id: windowTests

        name: "WindowedView.Window"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            owner.reset(root.windowSize)
            tryVerify(() => settled(root.windowSize), 5000, "rows laid out")
        }

        function test_rendersTheWholeModel() {
            compare(view.rowCount, root.windowSize)
            compare(values()[0], 0)
            compare(values()[root.windowSize - 1], root.windowSize - 1)
            compare(view.busy, false)
        }

        function test_requestAtEndStagesTheBatchThenRevealsIt() {
            provider.delay = 40      // so the staged state is observable
            const before = values()

            verify(view.requestMoreBottom(), "the request was taken")
            verify(view.busy, "busy until the batch is revealed")

            compare(view.rowCount, root.windowSize + root.chunk,
                    "the admitted rows are in the model")
            compare(hiddenShells().length, root.chunk, "and staged, not shown")
            compare(values(), before, "nothing visible changed yet")

            for (const shell of hiddenShells())
                compare(shell.height, 0, "a staged row takes no space")

            tryVerify(() => !view.busy, 5000)
            compare(view.rowCount, root.windowSize, "the far end was dropped on reveal")
            compare(hiddenShells().length, 0)
            compare(values()[0], root.chunk, "the window moved by one chunk")
        }

        function test_requestAtStartMovesTheOtherWay() {
            provider.delay = 40
            verify(view.requestMoreTop())
            compare(hiddenShells().length, root.chunk)

            tryVerify(() => !view.busy, 5000)
            compare(view.rowCount, root.windowSize)
            compare(values()[0], -root.chunk, "older rows are now at the top")
        }

        function test_aSecondRequestIsRefusedWhileLoading() {
            provider.delay = 60
            verify(view.requestMoreBottom())
            compare(view.requestMoreBottom(), false, "already loading at that end")
            compare(view.requestMoreTop(), false, "and the other end too")

            tryVerify(() => !view.busy, 5000)
        }

        function test_aRefusedRequestSetsNoState() {
            view.moreAvailableBottom = false
            compare(view.requestMoreBottom(), false, "nothing more to get")
            compare(view.busy, false)
            compare(view.loadingBottom, false)
            view.moreAvailableBottom = true
        }

        // The view must not complete a batch from inside the Repeater's own
        // creation pass: with a synchronous provider the first row would finish
        // it before its siblings exist, and the far end would be dropped
        // against a half-built window.
        function test_aSynchronousProviderStillLandsCorrectly() {
            provider.delay = 0

            verify(view.requestMoreBottom())
            tryVerify(() => !view.busy, 5000)

            compare(view.rowCount, root.windowSize, "exactly one drop happened")
            compare(hiddenShells().length, 0)
            compare(values()[0], root.chunk)
            compare(values().length, root.windowSize)
        }
    }

    TestCase {
        id: stagingTests

        name: "WindowedView.Staging"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            owner.reset(root.windowSize)
            tryVerify(() => settled(root.windowSize), 5000, "rows laid out")
        }

        function valuesOf(shellList) {
            return shellList.map(shell => shell.model.value).sort((a, b) => a - b)
        }

        // The batch is the rows that entered while the request was outstanding,
        // identified by key. Position cannot be used: the owner adds at one end
        // and removes at the other, so a row's index means something different
        // before and after the trim.
        function test_rowsAdmittedWhileLoadingAreTheBatch() {
            provider.delay = 40         // so the staged state is observable

            verify(view.requestMoreBottom())

            const staged = valuesOf(hiddenShells())
            compare(staged.length, root.chunk)
            compare(staged[0], root.windowSize)
            compare(staged[staged.length - 1], root.windowSize + root.chunk - 1)

            tryVerify(() => !view.busy, 5000)
        }

        // A row arriving after the owner has said "that is all" belongs to
        // nobody, even though the batch it missed is still staged: it shows
        // itself straight away and does not hold the reveal open.
        function test_aLiveRowMidRevealDoesNotJoinTheBatch() {
            provider.delay = 60

            verify(view.requestMoreBottom())
            verify(view.busy, "the batch is staged")
            compare(view.loadingBottom, false, "and the owner has already answered")

            owner.appendLive()

            const live = shells().filter(
                shell => shell.model.value === owner.liveValue)
            compare(live.length, 1, "the live row has a shell")
            tryVerify(() => live[0].visible && !!live[0].content, 2000,
                      "which reveals itself without waiting for the batch")

            compare(hiddenShells().length, root.chunk,
                    "the batch is still exactly the admitted rows")

            tryVerify(() => !view.busy, 5000)
            verify(values().indexOf(owner.liveValue) !== -1,
                   "and the live row survives the trim")
        }

        // A staged row leaving the window before it was ever built must release
        // its claim, or the batch waits for a row that will never come.
        function test_aBatchRowRemovedBeforeItArrivesDoesNotWedgeTheReveal() {
            provider.mute = true        // nothing the batch asks for arrives

            verify(view.requestMoreBottom())
            verify(view.busy)

            // take the whole batch straight back out again
            rows.remove(rows.count - root.chunk, root.chunk)
            owner.admitted = 0

            tryVerify(() => !view.busy, 5000, "the reveal did not wait on them")
            compare(view.rowCount, root.windowSize)
            compare(hiddenShells().length, 0)
        }
    }

    TestCase {
        id: cacheTests

        name: "WindowedView.Cache"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            // Rows first, so the view hands every item back before the counters
            // are zeroed - otherwise the previous group's releases land on a
            // fresh provider and the accounting starts out negative.
            owner.reset(0)
            provider.reset()
            provider.pooled = true
            owner.reset(root.windowSize)
            tryVerify(() => settled(root.windowSize), 5000, "rows laid out")
        }

        function slide(request, times) {
            for (let i = 0; i < times; ++i) {
                verify(request(), "slide " + i + " was taken")
                tryVerify(() => !view.busy, 5000)
            }
        }

        function test_buildingStopsAtTheHighWaterMark() {
            compare(provider.builtCount, root.windowSize,
                    "the first fill builds one item per row")

            slide(() => view.requestMoreBottom(), 1)

            // A slide overlaps: the new chunk exists before the far end is
            // dropped, so the mark is one chunk above the window - and never
            // above it again, however far the view travels.
            const high = provider.builtCount
            verify(high <= root.windowSize + root.chunk,
                   "one extra chunk at most, not one per slide: " + high)

            slide(() => view.requestMoreBottom(), 5)
            slide(() => view.requestMoreTop(), 6)

            compare(provider.builtCount, high,
                    "nothing was built after the high-water mark")
        }

        function test_everyItemIsEitherInUseOrParked() {
            slide(() => view.requestMoreBottom(), 3)
            slide(() => view.requestMoreTop(), 3)

            compare(provider.acquiredCount, view.rowCount,
                    "one item per row in the window")
            compare(provider.acquiredCount + provider.availableCount,
                    provider.builtCount, "no item leaked and none was released twice")
        }

        // The provider is told which row it is dressing. A provider that
        // paces its answers has to order them somehow - nearest the viewport
        // first - and the row number is all there is to go on: a shell waiting
        // for its content has no geometry yet.
        function test_theProviderIsToldWhichRowItDresses() {
            compare(provider.dressedCount, root.windowSize,
                    "one acquire per row of the fill")

            for (let row = 0; row < view.rowCount; ++row) {
                const shell = view.itemAtRow(row)

                compare(provider.dressedAt[row], shell,
                        "row " + row + " was dressed as row " + row)
                compare(shell.row, row, "and the shell says the same")
            }
        }
    }

    TestCase {
        id: revealHeightsTests

        name: "WindowedView.RevealHeights"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            // The Layout-based row is the point: a recycled item reports its
            // *previous* implicitHeight until the next polish, so revealing on
            // arrival would place the batch at stale heights and then correct
            // itself a frame later - visibly.
            provider.delegate = layoutDelegate
            provider.pooled = true
            provider.delay = 20
            owner.reset(60)
            // No trim: the heights at the reveal have to be compared against the
            // heights of the same rows once everything has settled, and a trim
            // would take ten of them out in between.
            owner.removeOnReveal = false
            tryVerify(() => settled(60), 5000, "rows laid out")
        }

        function test_revealedAtFinalHeightsWithNoLateCorrection() {
            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            verify(view.contentY > 50)

            const before = topRow()

            verify(view.requestMoreBottom())
            tryVerify(() => !view.busy, 5000)

            const atReveal = view.contentY
            const offsetAtReveal = offsetOf(before.value)

            // Two more frames, because a stale height is corrected on the very
            // next polish: if the reveal had used one, this is where it shows.
            // Frames rather than a fixed wait - the claim is "nothing changes on
            // the following polish", not "nothing changes within N ms".
            waitForRendering(view)
            waitForRendering(view)

            compare(owner.sumAtReveal, revealedContentSum(),
                    "the heights the batch was revealed at were the final ones")
            compare(view.contentY, atReveal, "no late correction of the position")
            fuzzyCompare(offsetOf(before.value), offsetAtReveal, 0.01,
                         "and the anchor row did not shift afterwards")
            fuzzyCompare(offsetOf(before.value), before.offset, 0.5,
                         "content stayed where the user had it")
        }
    }

    TestCase {
        id: scrollBarTests

        name: "WindowedView.ScrollBar"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            provider.delay = 150        // several frames to sample across
            owner.reset(60)
            tryVerify(() => settled(60), 5000, "rows laid out")
        }

        // The whole reason a batch is revealed at once: a row-by-row reveal
        // grows the content height on every arrival, and the handle crawls and
        // resizes under the user's cursor for as long as the batch takes.
        function test_theHandleIsCompletelyStillWhileLoading() {
            view.contentY = Math.round((view.contentHeight - view.height) / 2)

            const heights = new Set()
            const positions = new Set()
            const sizes = new Set()

            verify(view.requestMoreBottom())

            let frames = 0

            while (view.busy && frames < 200) {
                heights.add(view.contentHeight)
                positions.add(scrollBar.position.toFixed(4))
                sizes.add(scrollBar.size.toFixed(4))
                ++frames
                waitForRendering(view)
            }

            verify(frames >= 2, "sampled more than once: " + frames)
            verify(frames < 200, "the load finished")

            compare(heights.size, 1,
                    "contentHeight took one value: " + Array.from(heights))
            compare(positions.size, 1,
                    "the handle never moved: " + Array.from(positions))
            compare(sizes.size, 1,
                    "the handle never resized: " + Array.from(sizes))
        }
    }

    TestCase {
        id: watchdogTests

        name: "WindowedView.Watchdog"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            owner.reset(root.windowSize)
            tryVerify(() => settled(root.windowSize), 5000, "rows laid out")
        }

        // Slower than the stall detector's interval is not the same as stalled.
        // Every arrival re-arms it, so a merely slow provider still costs one
        // reveal - not one per row, and not a warning.
        function test_aProviderSlowerThanTheWatchdogStillRevealsInOneStep() {
            provider.delay = 1200       // acquireTimer.interval is 1000

            verify(view.requestMoreBottom())
            tryVerify(() => !view.busy, 8000)

            compare(owner.revealCount, 1, "one reveal, not one per row")
            compare(view.rowCount, root.windowSize)
            compare(hiddenShells().length, 0)
            compare(values()[0], root.chunk)
        }

        // A provider that never answers must not leave the window oversized and
        // both directions disabled for good. The slide completes - flags cleared,
        // far end trimmed - and the rows that never came stay staged.
        function test_aProviderThatNeverAnswersStillCompletesTheSlide() {
            ignoreWarning(/WindowedView: nothing arrived in/)
            provider.mute = true

            verify(view.requestMoreBottom())

            tryVerify(() => owner.revealCount === 1, 8000,
                      "the watchdog ended the wait and completed the slide")
            compare(view.loadingBottom, false)
            compare(view.rowCount, root.windowSize, "the far end was trimmed anyway")
            compare(hiddenShells().length, root.chunk,
                    "and the rows that never arrived are still staged, not shown")
        }
    }

    TestCase {
        id: stickToBottomTests

        name: "WindowedView.StickToBottom"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
        }

        // The groups share one view, so the flag has to be handed back or it
        // leaks into everything that runs after this.
        function cleanup() {
            view.stickToBottom = false
        }

        // Emptied first, and waited for: refilling 60 rows with 60 rows leaves
        // the Column exactly as tall as it was, so no height change fires and
        // contentY keeps whatever the previous test left it at. Each of these
        // tests is about a *first* load, so it has to start from nothing.
        function fill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0 && view.contentY === 0, 2000,
                      "starting from an empty view at the top")

            owner.reset(count)
            tryVerify(() => settled(count), 5000, "rows laid out")
        }

        // Present is not the same as positioned: a Column places its children on
        // a polish, so the row has to be waited for by the space it takes up.
        function appendLiveRow() {
            const before = view.contentHeight

            owner.appendLive()
            tryVerify(() => settled(view.rowCount) && view.contentHeight > before,
                      5000, "the live row landed and was laid out")
        }

        function bottomY() {
            return view.contentHeight - view.height
        }

        function lastShell() {
            return view.itemAtRow(view.rowCount - 1)
        }

        function verifyLastRowSitsOnTheBottomEdge() {
            const last = lastShell()

            verify(!!last && last.visible, "the last row is shown")
            fuzzyCompare(last.y + last.height - view.contentY, view.height, 0.5,
                         "its bottom edge is the viewport's bottom edge")
        }

        function test_theInitialFillEndsAtTheBottom() {
            view.stickToBottom = true
            fill(60)

            fuzzyCompare(view.contentY, bottomY(), 0.5, "parked at the bottom")
            verifyLastRowSitsOnTheBottomEdge()
        }

        function test_withoutTheFlagTheFillStaysAtTheTop() {
            fill(60)

            compare(view.stickToBottom, false, "off unless asked for")
            compare(view.contentY, 0, "still top-anchored")
        }

        function test_aLiveRowAtTheEndKeepsTheViewAtTheBottom() {
            view.stickToBottom = true
            fill(60)

            appendLiveRow()

            compare(view.rowCount, 61)
            fuzzyCompare(view.contentY, bottomY(), 0.5, "followed it down")
            compare(lastShell().model.value, owner.liveValue,
                    "and it is the row at the bottom")
            verifyLastRowSitsOnTheBottomEdge()
        }

        function test_aLiveRowDoesNotPullTheViewDownWhenScrolledUp() {
            view.stickToBottom = true
            fill(60)

            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            verify(view.contentY > 50, "there is room to scroll")

            const before = topRow()
            const contentY = view.contentY

            appendLiveRow()

            compare(view.rowCount, 61)
            fuzzyCompare(view.contentY, contentY, 0.5,
                         "the user's position stays the user's")
            fuzzyCompare(offsetOf(before.value), before.offset, 0.5,
                         "and nothing moved under them")
        }

        // Both rules could apply here and they disagree: the slide puts ten
        // rows below the viewport and takes ten from above it. The anchor wins,
        // so the new rows wait below rather than dragging the viewport onto
        // themselves.
        function test_aSlideAtTheEndIsGovernedByTheAnchorNotTheEnd() {
            view.stickToBottom = true
            fill(60)

            const before = topRow()

            verify(view.requestMoreBottom())
            tryVerify(() => !view.busy, 5000)

            const after = offsetOf(before.value)
            verify(!isNaN(after), "the anchor row survived")
            fuzzyCompare(after, before.offset, 0.5, "content stayed still")
            verify(view.contentY < bottomY() - 1,
                   "and the view did not jump to the new bottom: "
                   + view.contentY + " of " + bottomY())
        }
    }


    // ------------------------------------------------------------------
    // The one integration case: the real IndexWindowSource and the real
    // ItemPool, wired to the view the way the page wires them. Everything
    // above mocks those two seams on purpose; this is the only thing that would
    // notice them no longer fitting together.
    //
    // The row is defined here rather than borrowed from the storybook's message
    // delegate. These are StatusQ components, and the page's delegate would add
    // an avatar, an image grid and remote URLs that prove nothing about the
    // wiring - while the one property of it that mattered, a Layout-driven
    // height, is what `layoutDelegate` above already covers head-on.
    // ------------------------------------------------------------------

    ListModel {
        id: sourceRows

        Component.onCompleted: {
            const batch = []

            for (let i = 0; i < 200; ++i)
                batch.push({ key: "m" + i, messageText: "message " + i })

            sourceRows.append(batch)
        }
    }

    SQUtils.IndexWindowSource {
        id: windowSource

        sourceModel: sourceRows
        size: 30
    }

    // Message-shaped: wrapped text whose height arrives through a Layout, so a
    // recycled row reports a stale height until the next polish - exactly the
    // case the reveal has to survive.
    Component {
        id: smokeDelegate

        Item {
            id: smokeRow

            property string text

            implicitHeight: smokeColumn.height + 16

            ColumnLayout {
                id: smokeColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8

                Text {
                    Layout.fillWidth: true

                    text: smokeRow.text
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    SQUtils.ItemPool {
        id: itemPool

        delegate: smokeDelegate
        asynchronous: false
    }

    WindowedView {
        id: smokeView

        // Beside the mock view rather than on top of it, and still inside the
        // window, so it is laid out and polished like any other item.
        x: root.width
        width: root.width
        height: root.height

        model: windowSource.model

        moreAvailableTop: windowSource.moreAvailableStart
        moreAvailableBottom: windowSource.moreAvailableEnd

        acquireDelegate: (parent, row, modelRow, cb) => itemPool.acquire(parent, (obj) => {
            obj.width = Qt.binding(() => (parent ? parent.width : undefined) ?? 0)
            obj.text = Qt.binding(() => (modelRow ? modelRow.messageText : undefined) ?? "")
            cb(obj)
        }, true)

        releaseDelegate: (obj) => {
            obj.text = ""
            obj.width = 0
            itemPool.release(obj)
        }

        onMoreRequestedTop: {
            windowSource.growStart(10)
            smokeView.moreLoadedTop()
        }

        onMoreRequestedBottom: {
            windowSource.growEnd(10)
            smokeView.moreLoadedBottom()
        }

        onBatchRevealed: windowSource.trim()
    }

    TestCase {
        id: integrationTests

        name: "WindowedView.Integration"
        when: windowShown

        function initTestCase() {
            waitForRendering(smokeView)
            tryVerify(() => !smokeView.busy && smokeView.rowCount === 30
                            && smokeView.contentHeight > smokeView.height, 10000,
                      "the real source and pool filled the window")
        }

        function offsetOfKey(key) {
            for (let i = 0; i < smokeView.rowCount; ++i) {
                const shell = smokeView.itemAtRow(i)

                if (shell && shell.visible && shell.model.key === key)
                    return shell.y - smokeView.contentY
            }

            return NaN
        }

        function test_oneRoundTripThroughTheRealStack() {
            // Anchored on a row the slide cannot take away - growing at the end
            // trims the first ten - so this asserts where the content sits, not
            // which rows the row height happened to put on screen.
            const anchor = smokeView.itemAtRow(12)
            verify(!!anchor, "the window is deep enough to anchor inside")

            smokeView.contentY = Math.min(anchor.y, smokeView.contentHeight
                                                    - smokeView.height)
            verify(smokeView.contentY > 50, "there is room to scroll")

            const anchorKey = anchor.model.key
            const offsetBefore = offsetOfKey(anchorKey)
            const firstBefore = windowSource.first

            verify(smokeView.requestMoreBottom(), "the request was taken")
            tryVerify(() => !smokeView.busy, 10000)

            compare(windowSource.first, firstBefore + 10,
                    "the source window moved and was trimmed on reveal")
            compare(smokeView.rowCount, 30, "the window kept its size")

            const offsetAfter = offsetOfKey(anchorKey)
            verify(!isNaN(offsetAfter), "the anchor row " + anchorKey + " survived")
            fuzzyCompare(offsetAfter, offsetBefore, 0.5,
                         "and stayed where the user was looking")
        }
    }
}
