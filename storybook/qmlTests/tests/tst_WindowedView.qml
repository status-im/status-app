pragma ComponentBehavior: Bound

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

    // Every flick the view starts, its own restores included.
    property int flickStarts: 0

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

    // Height that grows as the row narrows, the way wrapped text does. The
    // plain row above is width-independent, so a resize changes nothing about it
    // and there is nothing to hold still.
    Component {
        id: reflowDelegate

        Item {
            id: reflowRow

            property int value: 0

            implicitHeight: 40 + (reflowRow.value % 5) * 20
                            + Math.ceil(30000 / Math.max(1, reflowRow.width))
        }
    }

    // Reports no height at all when there is no room to lay anything out, the
    // way wrapped text does at zero width.
    Component {
        id: collapsingDelegate

        Item {
            id: collapsingRow

            property int value: 0

            implicitHeight: collapsingRow.width <= 0
                            ? 0
                            : 40 + (collapsingRow.value % 5) * 20
                              + Math.ceil(30000 / collapsingRow.width)
        }
    }

    // One row taller than the whole viewport, and still re-flowing: the case
    // where nothing on screen starts on screen.
    Component {
        id: giantReflowDelegate

        Item {
            id: giantRow

            property int value: 0

            implicitHeight: 200 + Math.ceil(300000 / Math.max(1, giantRow.width))
        }
    }

    // Tall rows, so the content is long enough for a flick to still be running
    // when it reaches a band. With the short rows above, a flick across the whole
    // window is over in a few frames.
    Component {
        id: tallDelegate

        Item {
            property int value: 0

            implicitHeight: 300 + (value % 5) * 100
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

    Component {
        id: messageShapedDelegate

        MouseArea {
            id: msg

            property int value: 0

            implicitHeight: msgColumn.height + msgColumn.y + 16

            Image {
                id: msgAvatar
                x: 16; y: 16
                width: 40; height: 40
                layer.enabled: true
            }

            ColumnLayout {
                id: msgColumn

                anchors.top: msgAvatar.top
                anchors.left: msgAvatar.right
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                RowLayout {
                    Text { text: "michalc"; font.bold: true; wrapMode: Text.Wrap }
                    Text { Layout.fillWidth: true; font.pixelSize: 12
                           text: "12/03/2026, 10:44"; wrapMode: Text.Wrap }
                }

                TextEdit {
                    Layout.fillWidth: true
                    readOnly: true
                    wrapMode: Text.Wrap
                    textFormat: Text.MarkdownText
                    text: "message " + msg.value + " with enough words in it to "
                          + "wrap onto a second line at this width, **bold** too"
                }

                GridLayout {
                    columns: 2
                    Repeater {
                        model: msg.value % 11 === 0 ? 2 : 0
                        delegate: Item {
                            Layout.preferredWidth: 300
                            Layout.preferredHeight: 300
                        }
                    }
                }
            }
        }
    }

    // What the tests put in a slot: a banner whose height they move, so the
    // space a slot takes can grow and shrink under the rows.
    property real bannerHeight: 40

    Component {
        id: headerComponent

        Rectangle {
            objectName: "headerBanner"

            implicitHeight: root.bannerHeight
            color: "#8844aaff"
        }
    }

    Component {
        id: footerComponent

        Rectangle {
            objectName: "footerBanner"

            implicitHeight: root.bannerHeight
            color: "#88ffaa44"
        }
    }

    QtObject {
        id: placeholderProbe

        property int created: 0
        property int reparents: 0
        property Item item: null
    }

    Component {
        id: skeletonPlaceholder

        Item {
            id: skeletonRoot

            Component.onCompleted: {
                placeholderProbe.created++
                placeholderProbe.item = skeletonRoot
            }

            // Counted here rather than in the view: moving between placements is
            // the one cost this design has to keep down.
            onParentChanged: placeholderProbe.reparents++

            Rectangle {
                anchors.fill: parent
                color: "#eeeeee"
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

                // A row removed while its answer was owed reads its roles as
                // undefined - answering it anyway is the case under test.
                item.value = modelRow.value ?? -1
                item.parent = parent
                // Bound at acquire, exactly as a real consumer does it: the item
                // goes from its parked width to the row width here, which is what
                // makes wrapped text and nested layouts recompute.
                item.width = Qt.binding(() => (parent ? parent.width : undefined) ?? 0)
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

            item.width = 0
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

        // Every owed answer, now, in this turn - before anything deferred to
        // the event loop has had a chance to run.
        function flush() {
            const due = queue

            clear()

            for (let i = 0; i < due.length; ++i)
                due[i].callback()
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

        // How many more chunks each end is willing to give. Large by default, so
        // availability is effectively infinite unless a test says otherwise.
        property int startBudget: 1000
        property int endBudget: 1000

        // Two shapes of a late owner. holdAnswer admits at once and confirms
        // later - an index window that has the rows already. holdAdmit does
        // neither until answer() is called - a backend fetch, where nothing
        // exists until the reply lands.
        property bool holdAnswer: false
        property bool holdAdmit: false

        // Which screen edge the view is owed an answer at.
        property bool answerOwedAtTop: false
        property bool answerOwed: false

        function bottomUp() {
            return view.verticalLayoutDirection
                    === WindowedView.VerticalLayoutDirection.BottomToTop
        }

        // Rows into the model at one of its ends. Everything below counts in
        // model rows; only the two request handlers translate.
        function admit(atModelStart, count) {
            if (atModelStart)
                owner.admitStart(count)
            else
                owner.admitEnd(count)
        }

        function answer() {
            if (!owner.answerOwed)
                return

            owner.answerOwed = false

            if (owner.answerOwedAtTop) {
                if (owner.holdAdmit)
                    owner.admit(!owner.bottomUp(), root.chunk)

                view.moreLoadedTop()
            } else {
                if (owner.holdAdmit)
                    owner.admit(owner.bottomUp(), root.chunk)

                view.moreLoadedBottom()
            }
        }

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
            owner.holdAnswer = false
            owner.holdAdmit = false
            owner.answerOwed = false
            owner.startBudget = 1000
            owner.endBudget = 1000

            if (initial > 0)
                rows.append(rows.make(0, initial))
            owner.nextEnd = initial
        }

        function admitEnd(count) {
            owner.endBudget = Math.max(0, owner.endBudget - 1)

            rows.append(rows.make(owner.nextEnd, count))
            owner.nextEnd += count
            owner.admitted = count
            owner.admittedAtStart = false
        }

        function admitStart(count) {
            owner.startBudget = Math.max(0, owner.startBudget - 1)

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

        // Off by default here: this owner never runs out, so a view that paged
        // itself would page forever. The AutoRequest group turns it on against
        // a budgeted owner.
        autoRequest: false

        onFlickStarted: root.flickStarts++

        acquireDelegate: (parent, row, modelRow, cb) =>
                provider.acquire(parent, row, modelRow, cb)
        releaseDelegate: (item) => provider.release(item)

        // The view asks by screen edge, the owner hands rows over by model end.
        // Which of the two lines up with which depends on the layout direction:
        // rendered bottom-up, what belongs above the top row is the model's end.
        onMoreRequestedTop: {
            const atModelStart = !owner.bottomUp()

            if (!owner.holdAdmit)
                owner.admit(atModelStart, root.chunk)

            if (owner.holdAnswer || owner.holdAdmit) {
                owner.answerOwed = true
                owner.answerOwedAtTop = true
            } else {
                view.moreLoadedTop()
            }
        }

        onMoreRequestedBottom: {
            const atModelStart = owner.bottomUp()

            if (!owner.holdAdmit)
                owner.admit(atModelStart, root.chunk)

            if (owner.holdAnswer || owner.holdAdmit) {
                owner.answerOwed = true
                owner.answerOwedAtTop = false
            } else {
                view.moreLoadedBottom()
            }
        }

        onBatchRevealed: {
            owner.revealCount++
            owner.sumAtReveal = revealedContentSum()
            owner.dropFarEnd()
        }

        ScrollBar.vertical: ScrollBar { id: scrollBar }
    }

    SignalSpy {
        id: positionedSpy

        target: view
        signalName: "rowPositioned"
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

    // The topmost visible row not entirely above the viewport. Picked by
    // position rather than by order: shells() walks model rows, and rendering
    // bottom-up makes those run up the screen instead of down it. Identical
    // either way while the two agree.
    function topRow() {
        let best = null

        for (const shell of shells())
            if (shell.visible && shell.content
                    && shell.y + shell.height > view.contentY + 0.01
                    && (!best || shell.y < best.y))
                best = shell

        return best ? { value: best.content.value, offset: best.y - view.contentY }
                    : { value: -9999, offset: 0 }
    }

    // Which placement currently holds the one placeholder instance, by
    // objectName; "" when it is parked or has never been built.
    function host() {
        const item = placeholderProbe.item

        return item && item.parent ? item.parent.objectName : ""
    }

    // The values the rows carry, in the order they are drawn down the screen.
    function renderedValues() {
        return shells().filter(shell => shell.visible && shell.content)
                       .sort((a, b) => a.y - b.y)
                       .map(shell => shell.content.value)
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

        // A held answer outlives a failing test, and nothing else ever clears
        // loading* - so without this one failure here wedges every group that
        // runs after it, and the real cause is buried.
        function cleanup() {
            owner.holdAnswer = false
            owner.holdAdmit = false
            owner.answer()
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

        // Two phases, not one: waiting for the owner to answer, and then making
        // the batch it admitted ready to show. A synchronous owner skips the
        // first entirely, which is why they are reported separately.
        function test_stagingAndLoadingAreSeparatePhases() {
            provider.delay = 60
            owner.holdAnswer = true

            verify(view.requestMoreBottom())
            compare(view.loadingBottom, true, "the owner has not answered yet")
            compare(view.staging, true, "though the rows it admitted are staged")

            owner.answer()
            compare(view.loadingBottom, false, "the owner is done")
            compare(view.staging, true, "but the batch is still not on screen")

            tryVerify(() => !view.busy, 5000)
            compare(view.staging, false, "cleared by the reveal")
            compare(view.loadingBottom, false)
        }

        // The stall detector watches the provider. Once every admitted row has
        // its content there is nothing left for it to watch, and an owner that
        // takes its time is not a stall - firing there would reveal a batch the
        // owner is still entitled to add to.
        function test_aCompleteBatchWaitsForTheOwnerPastTheStallInterval() {
            provider.delay = 40
            owner.holdAnswer = true

            const reveals = owner.revealCount

            verify(view.requestMoreBottom())
            tryVerify(() => view.rowCount === root.windowSize + root.chunk, 2000)

            // Well past the detector's 1000 ms, asserted continuously rather
            // than waited out: the claim is that nothing happens in here.
            const deadline = Date.now() + 1500

            while (Date.now() < deadline) {
                compare(view.staging, true, "the batch is still staged")
                compare(view.loadingBottom, true, "the owner still owes an answer")
                compare(owner.revealCount, reveals, "and nothing was revealed")
                waitForRendering(view)
            }

            owner.answer()
            tryVerify(() => !view.busy, 5000)

            compare(owner.revealCount, reveals + 1, "revealed once, on the answer")
            compare(view.rowCount, root.windowSize)
            compare(hiddenShells().length, 0)
        }

        // An owner that goes away to fetch has nothing to stage yet, so the two
        // phases follow one another instead of overlapping: waiting for the
        // reply, then making what it brought ready to show.
        function test_theTwoPhasesAreSequentialForAFetchingOwner() {
            provider.delay = 40
            owner.holdAdmit = true

            verify(view.requestMoreBottom())
            compare(view.loadingBottom, true, "waiting on the owner")
            compare(view.staging, false, "with nothing admitted to stage")
            compare(view.rowCount, root.windowSize, "and no rows yet")

            owner.answer()
            compare(view.loadingBottom, false, "the reply landed")
            compare(view.staging, true, "and what it brought is now staging")

            tryVerify(() => !view.busy, 5000)
            compare(view.staging, false)
            compare(view.rowCount, root.windowSize)
        }

        // The detector must still be watching after a late admission: it had
        // nothing to watch while the owner was away.
        function test_aSilentProviderAfterALateAdmitIsStillCaught() {
            ignoreWarning(/WindowedView: nothing arrived in/)
            owner.holdAdmit = true

            const reveals = owner.revealCount

            verify(view.requestMoreBottom())

            // let the detector lapse over the fetch, then admit into silence
            const deadline = Date.now() + 1400

            while (Date.now() < deadline)
                waitForRendering(view)

            provider.mute = true
            owner.answer()

            tryVerify(() => owner.revealCount === reveals + 1, 10000,
                      "the watchdog ended the wait")
            compare(view.loadingBottom, false)
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
        id: batchTests

        name: "WindowedView.Batch"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            owner.reset(root.windowSize)
            positionedSpy.clear()
            tryVerify(() => settled(root.windowSize), 5000, "rows laid out")
        }

        // An open batch outlives a failing test just as a held answer does.
        function cleanup() {
            view.endBatch()
            owner.holdAnswer = false
            owner.answer()
            tryVerify(() => !view.busy, 5000)
        }

        function test_rowsAddedInsideTheBatchRevealTogether() {
            provider.delay = 40
            const reveals = owner.revealCount

            view.beginBatch()
            verify(view.busy, "busy while the batch is open")

            rows.append(rows.make(100, 5))
            compare(hiddenShells().length, 5, "the rows are staged")

            view.endBatch()
            compare(hiddenShells().length, 5, "and stay staged until ready")

            tryVerify(() => !view.busy, 5000)
            compare(owner.revealCount, reveals + 1, "revealed once")
            compare(hiddenShells().length, 0)
            compare(view.rowCount, root.windowSize + 5)
        }

        // The point of the pair: the owner may take as long as it likes, and
        // rows arriving long after beginBatch() still belong to the batch.
        function test_aLateBatchWaitsForTheOwner() {
            provider.delay = 40
            const reveals = owner.revealCount

            view.beginBatch()

            // past the stall detector's interval, with nothing arrived
            let deadline = Date.now() + 1500

            while (Date.now() < deadline) {
                compare(view.busy, true, "still waiting on the owner")
                compare(owner.revealCount, reveals, "and nothing was revealed")
                waitForRendering(view)
            }

            rows.append(rows.make(100, 5))

            // every row has its content, but the owner has not said it is done
            deadline = Date.now() + 300

            while (Date.now() < deadline) {
                compare(hiddenShells().length, 5, "the late rows are staged")
                waitForRendering(view)
            }

            view.endBatch()
            tryVerify(() => !view.busy, 5000)
            compare(owner.revealCount, reveals + 1, "revealed once, on endBatch()")
            compare(hiddenShells().length, 0)
        }

        function test_anEmptyBatchLeavesNoState() {
            const reveals = owner.revealCount

            view.beginBatch()
            view.endBatch()

            compare(view.busy, false)
            compare(view.initialLoading, false)
            compare(owner.revealCount, reveals, "nothing to reveal")

            verify(view.requestMoreBottom(), "paging works afterwards")
            tryVerify(() => !view.busy, 5000)
        }

        function test_requestsAreRefusedWhileABatchIsOpen() {
            view.beginBatch()
            compare(view.requestMoreBottom(), false)
            compare(view.requestMoreTop(), false)
            view.endBatch()

            compare(view.busy, false)
            verify(view.requestMoreBottom(), "and taken again once it is closed")
            tryVerify(() => !view.busy, 5000)
        }

        // Opened while a request is outstanding, the batch joins it: one reveal,
        // and only once both the owner's answer and endBatch() have arrived.
        function test_aBatchOpenedDuringARequestJoinsIt() {
            provider.delay = 40
            owner.holdAnswer = true
            const reveals = owner.revealCount

            verify(view.requestMoreBottom())
            view.beginBatch()
            rows.append(rows.make(500, 3))

            owner.answer()
            compare(view.loadingBottom, false, "the request is answered")

            const deadline = Date.now() + 300

            while (Date.now() < deadline) {
                compare(view.busy, true, "but the batch is still open")
                compare(owner.revealCount, reveals)
                waitForRendering(view)
            }

            view.endBatch()
            tryVerify(() => !view.busy, 5000)

            compare(owner.revealCount, reveals + 1, "one reveal for both")
            compare(hiddenShells().length, 0)
            verify(values().indexOf(500) !== -1, "the batch's rows are shown")
            compare(values()[0], root.chunk, "and the request's far end trimmed")
        }

        function test_replacingEveryRowInsideABatchIsAFreshFill() {
            provider.delay = 40
            const reveals = owner.revealCount

            view.beginBatch()
            rows.clear()
            rows.append(rows.make(200, root.windowSize))
            verify(view.initialLoading, "the replacement is a fresh population")

            view.endBatch()
            tryVerify(() => !view.busy, 5000)

            compare(view.initialLoading, false)
            compare(owner.revealCount, reveals + 1, "revealed in one step")
            compare(values()[0], 200)
        }

        // A jump whose window move only slides some rows in: the rows surviving
        // the move mean the view is not showing nothing, so without the batch
        // the new rows would reveal one by one with no batchRevealed() to
        // complete the jump in.
        function test_aSlidingJumpLandsInTheReveal() {
            provider.delay = 30
            const reveals = owner.revealCount

            let asked = false

            function onRevealed() {
                asked = true
                view.positionViewAtRow(view.rowForKey("k20"),
                                       WindowedView.PositionMode.Center)
            }

            view.batchRevealed.connect(onRevealed)

            view.beginBatch()
            rows.remove(0, root.chunk)
            rows.append(rows.make(root.windowSize, root.chunk))
            compare(view.rowForKey("k20"), root.windowSize - root.chunk,
                    "the target is held, staged")
            view.endBatch()

            tryVerify(() => !view.busy && positionedSpy.count === 1, 8000,
                      "the jump was honoured")
            view.batchRevealed.disconnect(onRevealed)
            waitForRendering(view)

            verify(asked)
            compare(owner.revealCount, reveals + 1, "in a single reveal")

            const item = view.itemAtRow(view.rowForKey("k20"))

            fuzzyCompare(item.y - view.contentY + item.height / 2,
                         view.height / 2, 1.0, "and centred")
        }
    }

    TestCase {
        id: revealAtEdgeTests

        name: "WindowedView.RevealAtEdge"
        when: windowShown

        // The shared delegates size rows by `value % 5`, which is negative for
        // the negative values a request at the model's start hands out - and
        // a batch of negative heights cannot land anywhere meaningful.
        Component {
            id: edgeRowDelegate

            Item {
                property int value: 0

                implicitHeight: 20 + (Math.abs(value) % 5) * 30
            }
        }

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            provider.delegate = edgeRowDelegate
            view.autoRequest = false

            // Taller than the 400px view, so the viewport can sit wholly
            // inside a band with no row on screen.
            view.placeholder = skeletonPlaceholder
            view.placeholderHeight = 600
        }

        function cleanup() {
            view.placeholder = null
            view.placeholderHeight = 100
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.TopToBottom
        }

        function fill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0, 2000, "emptied")
            owner.reset(count)
            tryVerify(() => settled(count), 8000, "rows laid out")
        }

        function revealed(shell) {
            return shell.visible && !!shell.content
        }

        // The row next to the content's top or bottom edge on screen, whatever
        // the layout direction - the one a reveal at that edge lands against.
        function outermostValue(atTop) {
            let best = null

            for (const shell of shells())
                if (revealed(shell) && (!best || (atTop ? shell.y < best.y
                                                        : shell.y > best.y)))
                    best = shell

            return best.content.value
        }

        function heightOf(value) {
            for (const shell of shells())
                if (revealed(shell) && shell.content.value === value)
                    return shell.height

            return NaN
        }

        function scrollTo(y) {
            view.contentY = y
            waitForRendering(view)
        }

        function topReveal() {
            provider.delay = 40
            verify(view.requestMoreTop(), "the request was taken")
            tryVerify(() => !view.busy, 8000, "revealed")
        }

        function test_aTopRevealSeenOnlyAsPlaceholderEndsAtTheViewportBottom() {
            fill(30)
            scrollTo(50)        // inside the top band, no row on screen

            const adjacent = outermostValue(true)

            topReveal()

            fuzzyCompare(offsetOf(adjacent), view.height, 0.5,
                         "the batch ends exactly at the viewport's bottom edge")
            verify(values().indexOf(-1) !== -1, "with the batch above it")
        }

        function test_aBottomRevealSeenOnlyAsPlaceholderStartsAtTheViewportTop() {
            fill(30)
            scrollTo(view.contentHeight - view.height)   // inside the bottom band

            const adjacent = outermostValue(false)

            provider.delay = 40
            verify(view.requestMoreBottom(), "the request was taken")
            tryVerify(() => !view.busy, 8000, "revealed")

            fuzzyCompare(offsetOf(adjacent) + heightOf(adjacent), 0, 0.5,
                         "the batch starts exactly at the viewport's top edge")
        }

        function test_aRevealWithARowOnScreenStillHoldsItStill() {
            fill(30)
            scrollTo(view.placeholderHeight - 100)   // the band and the first rows

            const adjacent = outermostValue(true)
            const before = offsetOf(adjacent)

            verify(before > 0 && before < view.height, "a row is on screen")

            topReveal()

            fuzzyCompare(offsetOf(adjacent), before, 0.5,
                         "the row on screen did not move")
        }

        // The chat's direction: the top band stands for the model's end.
        function test_bottomUpTopRevealEndsAtTheViewportBottom() {
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.BottomToTop
            fill(30)
            scrollTo(50)

            const adjacent = outermostValue(true)

            topReveal()

            fuzzyCompare(offsetOf(adjacent), view.height, 0.5,
                         "the batch ends exactly at the viewport's bottom edge")
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

        // A removed row's shell outlives its removal: the Repeater releases
        // it at once but deletes it later. An answer landing in between must
        // still come back, or the item is lost with the shell.
        function test_anAnswerToARemovedRowIsHandedBack() {
            provider.delay = 1000

            rows.append(rows.make(100, 5))
            rows.remove(rows.count - 5, 5)

            deliveryTimer.flush()

            compare(provider.acquiredCount, view.rowCount,
                    "the late answers were handed straight back")
            compare(provider.acquiredCount + provider.availableCount,
                    provider.builtCount, "and none was lost")

            waitForRendering(view)
            compare(provider.acquiredCount + provider.availableCount,
                    provider.builtCount, "nor after the shells were deleted")
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

            // The initial fill is a reveal of its own; these tests count the
            // slide's, so the baseline is taken once the view is settled.
            owner.revealCount = 0
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

        // Whoever owns the data reads this to tell a row that should simply be
        // shown from one that should be announced.
        function test_atEndReportsWhereTheViewportIs() {
            view.stickToBottom = true
            fill(60)

            compare(view.atBottom, true, "parked at the bottom")

            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            waitForRendering(view)
            compare(view.atBottom, false, "and not once scrolled away")

            view.contentY = view.contentHeight - view.height
            waitForRendering(view)
            compare(view.atBottom, true, "back again")
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

    TestCase {
        id: initialLoadTests

        name: "WindowedView.InitialLoad"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
        }

        function cleanup() {
            view.keyRole = "key"
            view.model = rows       // a test may have re-pointed it
        }

        // owner.reset() clears and refills in one turn, which from a populated
        // view is exactly a jump: every row removed, every row replaced.
        function startFill(count) {
            owner.reset(count)
        }

        // A first load proper. Emptying is waited for, because the Column only
        // collapses on a polish: fill straight from a populated view and the
        // old content height is still standing when the new rows arrive.
        function freshFill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0
                            && view.contentHeight === view.height, 2000,
                      "starting from an empty view")
            startFill(count)
        }

        function finishFill(count) {
            tryVerify(() => settled(count), 8000, "rows laid out")
        }

        function test_theWholeFillIsRevealedAtOnce() {
            provider.delay = 40
            freshFill(40)
            finishFill(40)

            compare(owner.revealCount, 1, "one reveal for the whole population")
            compare(values().length, 40, "and every row is in it")
            compare(hiddenShells().length, 0)
        }

        function test_nothingIsVisibleUntilTheFillCompletes() {
            provider.delay = 60         // several frames to sample across
            freshFill(40)

            const heights = new Set()
            let frames = 0

            while (view.initialLoading && frames < 300) {
                compare(hiddenShells().length, view.rowCount, "nothing shown yet")

                for (const shell of shells())
                    compare(shell.height, 0, "and nothing takes up space")

                heights.add(view.contentHeight)
                ++frames
                waitForRendering(view)
            }

            verify(frames >= 2, "sampled more than once: " + frames)
            verify(frames < 300, "the fill finished")
            finishFill(40)

            compare(heights.size, 1,
                    "contentHeight never moved: " + Array.from(heights))
        }

        function test_initialLoadingIsSetForTheWholeFill() {
            provider.delay = 60
            freshFill(40)

            compare(view.initialLoading, true, "set by the first row arriving")
            compare(view.busy, true)

            let frames = 0

            while (view.initialLoading && frames < 300) {
                compare(view.busy, true, "busy for as long as the fill runs")
                ++frames
                waitForRendering(view)
            }

            verify(frames >= 2, "the flag outlived more than one frame: " + frames)
            verify(frames < 300, "the fill finished")
            finishFill(40)
            compare(view.initialLoading, false, "cleared by the reveal")
            compare(view.busy, false)
        }

        function test_moreCannotBeRequestedDuringTheFill() {
            provider.delay = 60
            freshFill(40)

            // Sampled here on purpose: the keys are captured but no shell has
            // claimed one yet, so the wave is empty and only initialLoading
            // stands between this and a request that would orphan the batch.
            compare(view.requestMoreTop(), false, "refused before the wave exists")
            compare(view.requestMoreBottom(), false)

            let frames = 0

            while (view.initialLoading && frames < 300) {
                compare(view.requestMoreBottom(), false, "still refused mid-fill")
                ++frames
                waitForRendering(view)
            }

            finishFill(40)
            verify(view.requestMoreBottom(), "and accepted once the fill is done")
            tryVerify(() => !view.busy, 5000)
        }

        // The rule is "showing nothing", not "has never shown anything": a jump
        // that replaces every row has to look like a first load again.
        function test_aJumpReplacingEveryRowBehavesLikeAFirstLoad() {
            provider.delay = 20
            freshFill(40)
            finishFill(40)
            compare(owner.revealCount, 1)

            // Straight from the populated view, with no emptying in between:
            // that is what a jump is.
            startFill(30)
            compare(view.initialLoading, true,
                    "a wholesale replacement is a fresh population too")

            finishFill(30)
            compare(owner.revealCount, 1, "revealed in one shot as well")
            compare(values().length, 30)
        }

        function test_aLiveRowAfterTheFillStillRevealsAlone() {
            provider.delay = 20
            freshFill(40)
            finishFill(40)

            const reveals = owner.revealCount

            owner.appendLive()
            tryVerify(() => settled(41), 5000, "the live row landed")

            compare(view.initialLoading, false, "a live row is no fresh population")
            compare(owner.revealCount, reveals, "and it is not a batch")
            verify(values().indexOf(owner.liveValue) !== -1)
        }

        // The documented degradation: without the key role there is no batch to
        // gather, so rows reveal one by one. What must not happen is the view
        // announcing a fill that nothing can ever complete and refusing to page
        // from then on.
        function test_aModelWithoutTheKeyRoleStillRevealsAndStillPages() {
            ignoreWarning(/WindowedView: no "absent" role on the model/)
            view.keyRole = "absent"
            provider.delay = 20

            freshFill(20)
            compare(view.initialLoading, false, "no batch was ever claimed")

            tryVerify(() => settled(20), 8000, "the rows revealed anyway")
            compare(view.busy, false)
            verify(view.requestMoreBottom(), "and paging still works")
            tryVerify(() => !view.busy, 5000)
        }

        // Every staged row leaving before it arrives completes no wave, so
        // nothing would clear the flag through the reveal.
        function test_rowsRemovedMidFillDoNotWedgeTheView() {
            provider.mute = true

            freshFill(20)
            compare(view.initialLoading, true)

            rows.remove(0, rows.count)
            provider.mute = false

            tryVerify(() => !view.initialLoading && !view.busy, 5000,
                      "the fill ended with the rows")
            verify(view.requestMoreBottom(), "and paging works again")
            tryVerify(() => !view.busy, 5000)
        }

        // The case no model signal can catch, and the one the real page hits on
        // open: the rows are already in the model and the shells are built from
        // scratch. A proxy windowing a large model delivers its first page as a
        // reset, and a Repeater answers a reset by destroying what it built and
        // regenerating - so the rows that end up on screen arrive with no signal
        // of their own. Only a shell asking on its own behalf notices.
        function test_aPopulationRebuiltWithNoSignalIsStillStaged() {
            provider.delay = 40
            freshFill(40)
            finishFill(40)

            view.model = null
            tryVerify(() => view.rowCount === 0, 2000, "torn down")
            owner.revealCount = 0

            // The rows never left the model; only the shells did.
            view.model = rows
            compare(view.initialLoading, true, "the first shell opened a batch")

            finishFill(40)
            compare(owner.revealCount, 1, "revealed in one shot")
            compare(values().length, 40)
            compare(hiddenShells().length, 0)
        }

        function test_aProviderThatNeverAnswersStillEndsTheFill() {
            ignoreWarning(/WindowedView: nothing arrived in/)
            provider.mute = true
            provider.delay = 0

            freshFill(20)
            compare(view.initialLoading, true)

            tryVerify(() => !view.initialLoading, 8000, "the watchdog ended it")
            compare(owner.revealCount, 1, "the fill completed, with nothing to show")
            compare(hiddenShells().length, 20,
                    "and the rows that never arrived are still staged")
        }
    }

    TestCase {
        id: resizeTests

        name: "WindowedView.Resize"
        when: windowShown

        readonly property int wide: 500
        readonly property int narrow: 320
        readonly property int tall: 400
        readonly property int short: 260

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            provider.delegate = reflowDelegate

            // The view fills the root, so the root is what gets resized -
            // assigning view.width directly is simply overridden by the anchor.
            root.width = resizeTests.wide
        }

        function cleanup() {
            view.stickToBottom = false
            view.autoRequest = false
            view.placeholder = null
            view.moreAvailableTop = true
            root.width = resizeTests.wide
            root.height = resizeTests.tall
            provider.delegate = plainDelegate
        }

        function fill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0, 2000, "emptied")
            owner.reset(count)
            tryVerify(() => settled(count), 8000, "rows laid out")
        }

        function narrowIt() {
            root.width = resizeTests.narrow
            waitForRendering(view)
            waitForRendering(view)

            compare(view.width, resizeTests.narrow, "the view really narrowed")
        }

        // The topmost row the reader can see the start of.
        function topVisible() {
            for (const shell of shells()) {
                if (!shell.visible || !shell.content)
                    continue

                if (shell.y >= view.contentY + view.height)
                    break           // below the viewport entirely

                if (shell.y >= view.contentY - 0.5)
                    return { value: shell.content.value,
                             offset: shell.y - view.contentY }
            }

            return { value: -9999, offset: 0 }
        }

        function test_theTopVisibleRowKeepsItsPlace() {
            fill(40)

            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            waitForRendering(view)

            const before = topVisible()
            verify(before.value !== -9999, "there is a row to hold")

            narrowIt()

            verify(view.contentHeight > 0)
            const after = offsetOf(before.value)

            verify(!isNaN(after), "the row is still there")
            fuzzyCompare(after, before.offset, 0.5,
                         "and sits where it sat: " + after + " vs " + before.offset)
        }

        // Positioned so a row is half above the viewport top: the one below it
        // is what the reader is reading from the start.
        function test_aRowClippedAtTheTopIsNotTheAnchor() {
            fill(40)

            const third = view.itemAtRow(3)

            verify(!!third)
            view.contentY = third.y + third.height / 2
            waitForRendering(view)

            const before = topVisible()

            compare(before.value, view.itemAtRow(4).content.value,
                    "the clipped row is not the one held")
            verify(before.offset >= -0.5, "its top edge is visible")

            narrowIt()

            fuzzyCompare(offsetOf(before.value), before.offset, 0.5,
                         "and it is what stayed put")
        }

        function test_atTheEndItStaysAtTheEnd() {
            view.stickToBottom = true
            fill(40)

            fuzzyCompare(view.contentY, view.contentHeight - view.height, 0.5,
                         "parked at the bottom to begin with")

            narrowIt()

            fuzzyCompare(view.contentY, view.contentHeight - view.height, 0.5,
                         "and still parked there once it re-wrapped")
        }

        function test_atTheEndWithoutStickToEndItHoldsTheRow() {
            fill(40)

            view.contentY = view.contentHeight - view.height
            waitForRendering(view)

            const before = topVisible()

            verify(before.value !== -9999)

            narrowIt()

            fuzzyCompare(offsetOf(before.value), before.offset, 0.5,
                         "the row rule applies at the bottom too")
        }

        function test_aSingleTallRowHoldsItsOffset() {
            provider.delegate = giantReflowDelegate
            fill(10)

            const covering = view.itemAtRow(1)

            verify(!!covering)
            verify(covering.height > view.height,
                   "the row covers the viewport: " + covering.height)

            view.contentY = covering.y + 40       // nothing starts on screen
            waitForRendering(view)
            compare(topVisible().value, -9999, "no row has its top edge visible")

            const offsetBefore = covering.y - view.contentY

            narrowIt()

            fuzzyCompare(covering.y - view.contentY, offsetBefore, 0.5,
                         "the covering row holds its offset")
        }

        // What a slide anchors is the row nearest the *bottom* edge - growing at
        // the end trims at the start, so that is the row it guarantees. The top
        // row is not it, and is free to move as the rows between them re-wrap.
        function nearestToBottomEdge() {
            const edge = view.contentY + view.height

            let best = null
            let bestDistance = Number.MAX_VALUE

            for (const shell of shells()) {
                if (!shell.visible || !shell.content)
                    continue

                const distance = Math.abs(shell.y - edge)

                if (distance < bestDistance) {
                    bestDistance = distance
                    best = shell
                }
            }

            return best ? { value: best.content.value,
                            offset: best.y - view.contentY }
                        : { value: -9999, offset: 0 }
        }

        // Shrinking moves the bottom *down*, so asking whether the view was at
        // the end against the height it has already been given reads false and
        // the pin never fires. Growing moves the bottom up and hides the bug,
        // which is why only one direction broke.
        function test_shrinkingTheViewportStaysAtTheEnd() {
            view.stickToBottom = true
            fill(40)

            fuzzyCompare(view.contentY, view.contentHeight - view.height, 0.5,
                         "at the bottom to begin with")

            root.height = resizeTests.short
            waitForRendering(view)
            waitForRendering(view)

            compare(view.height, resizeTests.short, "the view really shrank")
            fuzzyCompare(view.contentY, view.contentHeight - view.height, 0.5,
                         "and is still at the bottom")
        }

        function test_growingTheViewportStaysAtTheEnd() {
            view.stickToBottom = true
            root.height = resizeTests.short
            fill(40)

            fuzzyCompare(view.contentY, view.contentHeight - view.height, 0.5,
                         "at the bottom to begin with")

            root.height = resizeTests.tall
            waitForRendering(view)
            waitForRendering(view)

            compare(view.height, resizeTests.tall, "the view really grew")
            fuzzyCompare(view.contentY, view.contentHeight - view.height, 0.5,
                         "and is still at the bottom")
        }

        // Widening shortens every row, so a viewport near the end is carried
        // into it by the content shrinking under it. Landing there is not
        // enough - it has to be *following* the end again, or the next row to
        // arrive leaves it behind.
        function test_wideningIntoTheEndStartsFollowingItAgain() {
            view.stickToBottom = true
            root.width = resizeTests.narrow
            fill(40)

            view.contentY = view.contentHeight - view.height - 20
            waitForRendering(view)
            compare(view.atBottom, false, "near the end, but not at it")

            root.width = resizeTests.wide
            waitForRendering(view)
            waitForRendering(view)

            fuzzyCompare(view.contentY, view.contentHeight - view.height, 0.5,
                         "the shrinking content carried it to the end")

            // The real question: is it stuck there, or just sitting there?
            //
            // Enough rows that the end moves past the position the stale anchor
            // was holding. One row is not enough: the clamp keeps the view at
            // the bottom anyway, and the test would pass with or without the
            // anchor being handed back.
            const endBefore = view.contentHeight - view.height

            rows.append(rows.make(9000, 4))

            // Waited for by the end actually moving. settled() only wants the
            // rows present and laid out at all - the Column's height catches up
            // a polish later, and comparing against it too early compares two
            // stale numbers that trivially agree.
            tryVerify(() => settled(44)
                            && view.contentHeight - view.height > endBefore + 100,
                      5000, "the rows landed and the end moved past the anchor")

            fuzzyCompare(view.contentY, view.contentHeight - view.height, 0.5,
                         "new rows keep it at the end")
        }

        // At zero width the rows report no height, the content shrinks to
        // nothing and every band reads as on screen - which walked the window to
        // the far end one batch at a time, and left the view somewhere else
        // entirely once the width came back.
        function test_collapsingToZeroWidthKeepsThePosition() {
            provider.delegate = collapsingDelegate
            fill(40)

            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            waitForRendering(view)

            const before = topVisible()

            verify(before.value !== -9999, "there is a row to hold")

            // Auto-paging armed against a budget, so a walking window shows up
            // as the budget being spent. The placeholder matters: without one
            // there are no bands at all, and nothing could be asked for however
            // broken the collapse is.
            view.placeholder = skeletonPlaceholder
            view.placeholderHeight = 100
            owner.startBudget = 5
            view.moreAvailableTop = Qt.binding(() => owner.startBudget > 0)
            view.autoRequest = true

            root.width = 0

            for (let i = 0; i < 6; ++i)
                waitForRendering(view)

            compare(view.width, 0, "the view really collapsed")
            compare(view.contentHeight, view.height, "and the rows with it")
            compare(owner.startBudget, 5, "nothing was asked for meanwhile")

            root.width = resizeTests.wide
            waitForRendering(view)
            waitForRendering(view)

            const after = offsetOf(before.value)

            verify(!isNaN(after), "the row is still there")
            fuzzyCompare(after, before.offset, 0.5,
                         "and back where it was: " + after + " vs " + before.offset)
        }

        function test_aResizeDoesNotDisturbASlide() {
            fill(40)

            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            waitForRendering(view)

            provider.delay = 60

            const anchored = nearestToBottomEdge()

            verify(anchored.value !== -9999, "there is a row for it to anchor")

            verify(view.requestMoreBottom())
            verify(view.busy, "the batch is in flight")

            narrowIt()

            tryVerify(() => !view.busy, 8000)

            const after = offsetOf(anchored.value)

            verify(!isNaN(after), "the slide's anchor row survived")
            fuzzyCompare(after, anchored.offset, 0.5,
                         "and the slide kept it where it was")
        }

        // The anchor suppresses the stickToBottom pin, so it must not outlive the
        // reader's next move.
        function test_scrollingAfterAResizeReleasesTheAnchor() {
            view.stickToBottom = true
            fill(40)

            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            waitForRendering(view)

            narrowIt()

            view.contentY = view.contentHeight - view.height   // a user move
            waitForRendering(view)

            owner.appendLive()
            tryVerify(() => settled(41), 5000, "the live row landed")

            fuzzyCompare(view.contentY, view.contentHeight - view.height, 0.5,
                         "stickToBottom follows again")
        }
    }

    TestCase {
        id: autoRequestTests

        name: "WindowedView.AutoRequest"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            view.placeholder = skeletonPlaceholder
            view.placeholderHeight = 100

            // Off while filling: the start band lands in the viewport the
            // moment the rows do, so a view that paged itself would never
            // settle at the count the fill asked for.
            view.autoRequest = false
        }

        function cleanup() {
            // A test that fails mid-drag never reaches its own release, and a
            // button left held breaks every later test that uses the mouse.
            mouseRelease(view, 0, 0, Qt.LeftButton)
            mouseRelease(scrollBar, 0, 0, Qt.LeftButton)

            // A release leaves the view flicking, which outlives the test.
            view.cancelFlick()

            view.autoRequest = false
            view.prefetchMargin = 0
            view.placeholder = null
            view.placeholderHeight = 100
            view.moreAvailableTop = true
            view.moreAvailableBottom = true
        }

        function freshFill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0, 2000, "emptied")
            owner.reset(count)
            tryVerify(() => settled(count), 8000, "rows laid out")
        }

        // A budgeted owner: without one, an end that is always available pages
        // for ever. Armed after the fill, because owner.reset() restores the
        // budgets along with everything else.
        function arm(chunks) {
            owner.startBudget = chunks
            owner.endBudget = chunks
            view.moreAvailableTop = Qt.binding(() => owner.startBudget > 0)
            view.moreAvailableBottom = Qt.binding(() => owner.endBudget > 0)
            view.autoRequest = true
        }

        function toStartBand() {
            view.contentY = 0
            waitForRendering(view)
        }

        function quiet(frames) {
            for (let i = 0; i < frames; ++i)
                waitForRendering(view)
        }

        function test_aBandInTheViewportAsksForMore() {
            provider.delay = 0
            freshFill(40)
            arm(3)

            const before = values()[0]

            toStartBand()

            tryVerify(() => owner.startBudget < 3, 3000, "it asked")
            tryVerify(() => !view.busy, 8000)
            verify(values()[0] < before, "and older rows arrived")
        }

        // The start band sits above the rows, so contentY is how far below
        // the band's bottom edge the viewport starts. Armed far from the band,
        // then scrolled to the spot under test: the scroll renders a frame,
        // and the deferred request has run by the time it does.
        function scrollWithin(offset) {
            view.contentY = view.placeholderHeight + 400
            waitForRendering(view)
            arm(3)

            view.contentY = view.placeholderHeight + offset
            waitForRendering(view)
        }

        function test_aBandWithinTheMarginAsksForMore() {
            provider.delay = 0
            freshFill(40)

            scrollWithin(50)
            compare(owner.startBudget, 3, "off screen and no margin: nothing asked")

            view.prefetchMargin = 100

            tryVerify(() => owner.startBudget < 3, 3000, "within the margin: asked")
            tryVerify(() => !view.busy, 8000)
        }

        function test_aBandBeyondTheMarginDoesNotAsk() {
            provider.delay = 0
            freshFill(40)

            view.prefetchMargin = 100
            scrollWithin(300)

            compare(owner.startBudget, 3, "beyond the margin: nothing asked")
        }

        function test_nothingIsAskedWhileTheHandleIsHeld() {
            provider.delay = 0
            freshFill(40)
            arm(3)

            // Start at the bottom, with the handle under the cursor, and drag
            // it all the way up - letting the scrollbar drive contentY, as a
            // real drag does, rather than jumping the view underneath it.
            view.contentY = view.contentHeight - view.height
            waitForRendering(view)

            const x = scrollBar.width / 2

            mousePress(scrollBar, x, scrollBar.height - 4)
            verify(scrollBar.pressed, "the handle is held")

            for (let i = 5; i >= 0; --i) {
                mouseMove(scrollBar, x, scrollBar.height * i / 6)
                waitForRendering(view)
                compare(owner.startBudget, 3, "held: nothing asked")
            }

            verify(view.contentY < view.placeholderHeight,
                   "the drag reached the start band: " + view.contentY)

            mouseRelease(scrollBar, x, 0)

            tryVerify(() => owner.startBudget < 3, 3000, "asked on release")
            tryVerify(() => !view.busy, 8000)
        }

        // A content drag no longer defers anything: Qt shifts the drag's origin
        // by whatever the position was moved by underneath it, so the batch can
        // land mid-gesture without the content snapping back on the next move.
        function test_theRequestGoesOutWhileDragging() {
            provider.delay = 0
            freshFill(40)
            arm(3)

            view.contentY = view.placeholderHeight * 3
            waitForRendering(view)

            const x = view.width / 2

            mousePress(view, x, 20)

            // The first move only crosses the drag threshold; the Flickable is
            // not dragging until the one after it. The button has to be named:
            // mouseMove() holds none by default, and a Flickable only drags for
            // a held button.
            mouseMove(view, x, 60, 16, Qt.LeftButton)
            waitForRendering(view)

            let askedWhileDragging = false

            for (let i = 2; i <= 8; ++i) {
                mouseMove(view, x, 20 + i * 40, 16, Qt.LeftButton)
                waitForRendering(view)

                if (view.dragging && owner.startBudget < 3)
                    askedWhileDragging = true
            }

            verify(view.contentY < view.placeholderHeight,
                   "the drag reached the start band: " + view.contentY)
            verify(askedWhileDragging, "asked without waiting for the release")

            mouseRelease(view, x, 20 + 8 * 40, Qt.LeftButton)
            tryVerify(() => !view.busy, 8000)
        }

        // Qt's own compensation, asserted rather than assumed: the row under the
        // cursor must not move when rows are inserted above it mid-drag.
        function test_aDragIsNotDisturbedByTheReveal() {
            provider.delay = 40
            freshFill(40)
            arm(3)

            view.contentY = view.placeholderHeight * 3
            waitForRendering(view)

            const x = view.width / 2

            mousePress(view, x, 20)
            mouseMove(view, x, 60, 16, Qt.LeftButton)
            waitForRendering(view)

            const anchor = topRow()

            let jump = NaN

            for (let i = 2; i <= 8; ++i) {
                const budget = owner.startBudget
                const before = offsetOf(anchor.value)

                mouseMove(view, x, 20 + i * 40, 16, Qt.LeftButton)
                waitForRendering(view)

                // the step the batch landed on is the only one that can show a
                // discontinuity, and comparing across it alone keeps the drag's
                // own resistance near the boundary out of the measurement
                if (owner.startBudget < budget)
                    jump = offsetOf(anchor.value) - before
            }

            verify(!isNaN(jump), "a batch landed during the drag")

            // one 40 px step, give or take; without the compensation it would be
            // the height of the ten rows that arrived above - hundreds of px
            verify(Math.abs(jump) < 120,
                   "the row moved with the cursor, not with the batch: " + jump)

            mouseRelease(view, x, 20 + 8 * 40, Qt.LeftButton)
            tryVerify(() => !view.busy, 8000)
        }

        function test_theRequestGoesOutWhileFlicking() {
            provider.delay = 0
            freshFill(40)
            arm(3)

            // positive velocity scrolls toward the top, so toward the start band
            view.contentY = view.placeholderHeight * 4
            waitForRendering(view)
            view.flick(0, 2000)
            verify(view.flickingVertically, "flicking")

            let askedWhileFlicking = false
            let frames = 0

            while (view.flickingVertically && frames < 300) {
                if (owner.startBudget < 3)
                    askedWhileFlicking = true

                ++frames
                waitForRendering(view)
            }

            verify(askedWhileFlicking, "asked without waiting for the flick to end")
            tryVerify(() => !view.busy, 8000)
        }

        // The reveal writes contentY, which cancels the flick outright, and the
        // view has to be moving still once it has landed - not merely restarted
        // once. completeWave() writes the position several times over, and an
        // earlier version restored after the first write and was killed by the
        // next; counting restarts alone did not notice, so what is checked here
        // is the motion itself.
        //
        // Tall rows on purpose: with the short ones a flick across the whole
        // window is over in a few frames, and the batch lands after the view has
        // already stopped.
        function test_aFlickSurvivesTheReveal() {
            provider.delay = 40
            provider.delegate = tallDelegate
            view.placeholderHeight = 300
            freshFill(40)
            arm(3)

            // flickDeceleration's default is platform-dependent - measured at
            // about 2700 px/s^2 here, so v=3000 carries roughly 1700 px. Start
            // inside that, and the band is still reached at some speed.
            view.contentY = 1200
            waitForRendering(view)

            view.flick(0, 3000)             // positive scrolls toward the top
            verify(view.flickingVertically, "flicking")

            tryVerify(() => owner.startBudget < 3, 6000,
                      "a batch was asked for during the flick")
            verify(view.flickingVertically,
                   "and the view was still flicking when it asked")

            tryVerify(() => !view.busy, 8000, "the batch landed")

            verify(view.flickingVertically,
                   "still flicking after the reveal, not stopped by it")

            // Movement rather than verticalVelocity: that is smoothed, and
            // immediately after a restore it has had no frame to catch up and
            // reads as nothing - which is the very effect that made the naive
            // implementation lose the flick.
            const at = view.contentY

            waitForRendering(view)
            waitForRendering(view)

            verify(view.contentY < at,
                   "and still travelling the same way: " + view.contentY
                   + " from " + at)
        }

        // Counted rather than read off `flickingVertically`: a correction can
        // leave the view slightly out of bounds, and the rebound Qt animates
        // back reports as flicking too. What must not happen is this view
        // starting one.
        function test_aFlickIsNotStartedWhenTheViewWasAtRest() {
            provider.delay = 0
            freshFill(40)
            arm(3)

            compare(view.flickingVertically, false)
            root.flickStarts = 0

            toStartBand()
            tryVerify(() => owner.startBudget < 3, 3000, "it asked")
            tryVerify(() => !view.busy, 8000)

            compare(root.flickStarts, 0,
                    "a correction at rest starts no flick of its own")
        }

        // One batch per reveal, however many times the condition rises.
        function test_requestsDoNotStack() {
            provider.delay = 40
            freshFill(40)
            arm(3)

            toStartBand()

            let frames = 0

            while (owner.startBudget > 0 && frames < 900) {
                verify(view.rowCount <= 40 + root.chunk,
                       "never more than one chunk over the window: "
                       + view.rowCount)
                ++frames
                waitForRendering(view)
            }

            tryVerify(() => !view.busy, 8000)
            compare(owner.startBudget, 0, "spent one chunk at a time")
        }

        function test_itStopsWhenNothingIsLeft() {
            provider.delay = 0
            freshFill(40)
            arm(3)

            toStartBand()

            tryVerify(() => owner.startBudget === 0 && !view.busy, 10000,
                      "walked to the end of what the owner had")
            compare(view.moreAvailableTop, false)

            const rows = view.rowCount

            quiet(6)

            compare(view.rowCount, rows, "nothing more was asked for")
            compare(view.busy, false)
        }

        function test_nothingIsAskedDuringTheInitialFill() {
            provider.delay = 60

            owner.reset(0)
            tryVerify(() => view.rowCount === 0, 2000, "emptied")
            arm(3)
            owner.reset(40)         // resets the budgets, hence arm() again
            arm(3)

            let frames = 0

            while (view.initialLoading && frames < 600) {
                compare(view.rowCount, 40, "the first paint is never disturbed")
                compare(owner.startBudget, 3)
                ++frames
                waitForRendering(view)
            }

            verify(frames >= 2, "sampled more than once: " + frames)
            tryVerify(() => !view.busy, 10000)
        }

        function test_autoRequestOffAsksForNothing() {
            provider.delay = 0
            freshFill(40)
            arm(3)
            view.autoRequest = false

            toStartBand()
            quiet(6)

            compare(owner.startBudget, 3, "the flag gates it")
        }

        function test_noPlaceholderMeansNoAutoRequest() {
            provider.delay = 0
            freshFill(40)
            arm(3)
            view.placeholder = null

            toStartBand()
            quiet(6)

            compare(owner.startBudget, 3, "no band, no trigger area")
        }
    }

    TestCase {
        id: placeholderTests

        name: "WindowedView.Placeholder"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)

            // Before any placement has wanted one. The instance is kept for the
            // view's life once built, so this is the only moment the claim can
            // be made.
            compare(placeholderProbe.created, 0,
                    "nothing is built until a placement wants it")
        }

        function init() {
            provider.reset()
            view.placeholder = skeletonPlaceholder
            view.placeholderHeight = 100
        }

        function cleanup() {
            view.placeholder = null
            view.moreAvailableTop = true
            view.moreAvailableBottom = true
            view.stickToBottom = false
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.TopToBottom
            owner.holdAnswer = false
            view.header = null
            view.footer = null
            view.autoRequest = false
        }

        function renderBottomUp() {
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.BottomToTop
        }

        function freshFill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0, 2000, "emptied")
            owner.reset(count)
        }

        // The Column only collapses the old content on a polish, so the viewport
        // placeholder standing alone is a state to wait for, not to assume.
        function fillingAlone() {
            tryVerify(() => view.initialLoading
                            && view.contentHeight === view.height, 3000,
                      "the placeholder is the only content")
        }

        function finishFill(count) {
            tryVerify(() => settled(count), 8000, "rows laid out")
        }

        // settled() wants content taller than the viewport, which short content
        // never is.
        function finishShortFill(count) {
            tryVerify(() => !view.busy && view.rowCount === count
                            && hiddenShells().length === 0, 8000, "rows laid out")
            waitForRendering(view)
        }

        function rowsHeight() {
            let sum = 0

            for (const shell of shells())
                sum += shell.height

            return sum
        }

        function test_theViewportIsFilledWhileTheFirstPopulationLoads() {
            provider.delay = 60
            freshFill(40)
            fillingAlone()

            compare(host(), "fillPlaceholder")

            const item = placeholderProbe.item
            verify(item.visible, "and it is shown")
            verify(item.parent.clip,
                   "the band clips, so an oversized placeholder cannot draw"
                   + " over the rows")
            compare(item.height, view.height, "covering the viewport")
            compare(item.width, view.width)
            compare(view.contentHeight, view.height,
                    "so there is nothing to scroll while it fills")
            compare(view.initialLoading, true)
            compare(hiddenShells().length, view.rowCount, "no row is shown yet")

            finishFill(40)
        }

        // The collapse of the viewport placeholder and the rows appearing are one
        // layout pass, so contentHeight goes straight from the viewport to the
        // content with nothing in between.
        function test_theHandoverToRealContentIsOneStep() {
            provider.delay = 60
            freshFill(40)
            fillingAlone()

            const heights = new Set()
            let frames = 0

            // Sampling has to span the handover itself: stop at it and an extra
            // step taken *during* the reveal - the placeholder coming down after
            // the rows went up - is never seen.
            while (frames < 400 && (view.initialLoading || view.busy
                                    || hiddenShells().length > 0)) {
                heights.add(view.contentHeight)
                ++frames
                waitForRendering(view)
            }

            verify(frames >= 2, "sampled more than once: " + frames)
            verify(frames < 400, "the fill finished")

            for (let i = 0; i < 3; ++i) {
                heights.add(view.contentHeight)
                waitForRendering(view)
            }

            compare(heights.size, 2,
                    "the viewport, then the content, and nothing in between: "
                    + Array.from(heights))
            verify(heights.has(view.height), "one of them is the bare viewport")
            compare(view.initialLoading, false)
            verify(host() !== "fillPlaceholder", "the viewport placement is empty")
        }

        function test_spaceIsReservedAtBothEnds() {
            provider.delay = 0
            freshFill(10)
            finishFill(10)

            compare(view.contentHeight, rowsHeight() + 2 * view.placeholderHeight,
                    "a band's worth at each end")
        }

        function test_theInstanceFollowsTheViewportBetweenEnds() {
            provider.delay = 0
            freshFill(40)
            finishFill(40)

            view.contentY = 0
            waitForRendering(view)
            compare(host(), "topPlaceholder", "at the top it takes the top band")

            view.contentY = view.contentHeight - view.height
            waitForRendering(view)
            compare(host(), "bottomPlaceholder", "at the bottom, the bottom one")

            compare(placeholderProbe.created, 1, "and it was never rebuilt")
        }

        function test_itIsParkedWhenNeitherEndIsOnScreen() {
            view.moreAvailableTop = false
            view.moreAvailableBottom = false
            provider.delay = 0
            freshFill(40)
            finishFill(40)

            compare(host(), "", "no placement wants it")
            compare(placeholderProbe.item.visible, false, "so it is not drawn")
            compare(view.contentHeight, rowsHeight(), "and reserves no space")
        }

        // Availability and loading are separate reasons to show a band: the last
        // batch can be in flight with nothing left beyond it.
        function test_loadingAtAnEndShowsItWithNothingAvailable() {
            provider.delay = 0
            freshFill(40)
            finishFill(40)

            owner.holdAnswer = true
            view.contentY = 0
            verify(view.requestMoreTop(), "a request is outstanding")
            compare(view.loadingTop, true)

            view.moreAvailableTop = false      // that was the last of it
            waitForRendering(view)

            compare(host(), "topPlaceholder",
                    "still shown, because a batch is on its way")

            owner.answer()
            tryVerify(() => !view.busy, 5000)
        }

        function test_oneEndHoldsItWhenBothAreOnScreen() {
            view.placeholderHeight = 40
            provider.delay = 0
            freshFill(2)            // short enough that both bands fit on screen
            finishShortFill(2)

            verify(view.contentHeight <= view.height,
                   "the whole window is on screen: " + view.contentHeight)

            const where = host()
            verify(where === "topPlaceholder" || where === "bottomPlaceholder",
                   "exactly one band holds it, not both: " + where)
            compare(placeholderProbe.created, 1, "and no second instance was made")
        }

        // The start band sits above every row, so it appearing has to be paid for
        // out of contentY or the rows all shift under the user.
        function test_theStartBandAppearingDoesNotMoveTheContent() {
            view.moreAvailableTop = false
            provider.delay = 0
            freshFill(40)
            finishFill(40)

            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            verify(view.contentY > 50, "there is room to scroll")

            const before = topRow()

            view.moreAvailableTop = true
            waitForRendering(view)

            const after = offsetOf(before.value)
            verify(!isNaN(after), "the row is still there")
            fuzzyCompare(after, before.offset, 0.5, "and did not move")
        }

        function test_theStartBandDisappearingDoesNotMoveTheContent() {
            provider.delay = 0
            freshFill(40)
            finishFill(40)

            view.contentY = Math.round((view.contentHeight - view.height) / 2)
            const before = topRow()

            view.moreAvailableTop = false
            waitForRendering(view)

            const after = offsetOf(before.value)
            verify(!isNaN(after), "the row is still there")
            fuzzyCompare(after, before.offset, 0.5, "and did not move")
        }

        // Scrolling the length of the content must not make the placeholder bounce
        // between the two ends: the host is chosen once per crossing, not per
        // frame. (This cannot pin the early return in applyPlaceholder itself -
        // Qt ignores a reparent to the same parent, so a missing guard costs
        // binding churn rather than a move.)
        function test_scrollingDoesNotBounceItBetweenEnds() {
            provider.delay = 0
            freshFill(40)
            finishFill(40)

            view.contentY = 0
            waitForRendering(view)

            const before = placeholderProbe.reparents
            const bottom = view.contentHeight - view.height

            // twenty steps from one end to the other: two host changes at most,
            // start -> parked -> end
            for (let i = 1; i <= 20; ++i) {
                view.contentY = Math.round(bottom * i / 20)
                waitForRendering(view)
            }

            compare(host(), "bottomPlaceholder")
            verify(placeholderProbe.reparents - before <= 3,
                   "moved at most once per host change, not per frame: "
                   + (placeholderProbe.reparents - before))
        }

        // The last batch at an end is the awkward one: the owner answers inside
        // the signal, so loading* is already false again, and "nothing more
        // beyond this" lands at the same moment. The band still has to stand
        // until the rows that replace it are on screen, and then go in the same
        // step as they appear.
        function slideOutTheLastBatch(atTop) {
            provider.delay = 0
            freshFill(40)
            finishFill(40)

            view.contentY = atTop ? 0 : view.contentHeight - view.height
            waitForRendering(view)

            const band = atTop ? "topPlaceholder" : "bottomPlaceholder"
            compare(host(), band)

            const heightBefore = view.contentHeight

            provider.delay = 60     // long enough for the batch to stay staged
            verify(atTop ? view.requestMoreTop() : view.requestMoreBottom())

            // that was the last of it
            if (atTop)
                view.moreAvailableTop = false
            else
                view.moreAvailableBottom = false

            let frames = 0

            while (view.busy && frames < 300) {
                compare(host(), band, "the band still stands")
                compare(view.contentHeight, heightBefore,
                        "and still occupies exactly its space")
                ++frames
                waitForRendering(view)
            }

            verify(frames >= 2, "sampled more than once: " + frames)
            verify(frames < 300, "the batch was revealed")
            verify(host() !== band, "and it went when the rows replaced it")
        }

        function test_theStartBandStandsUntilItsReplacementIsRevealed() {
            slideOutTheLastBatch(true)
        }

        function test_theEndBandStandsUntilItsReplacementIsRevealed() {
            slideOutTheLastBatch(false)
        }

        function test_noPlaceholderMeansNoReservedSpace() {
            view.placeholder = null
            provider.delay = 0
            freshFill(10)
            finishFill(10)

            compare(view.contentHeight, rowsHeight(), "exactly the rows")
            compare(view.initialLoading, false)
        }

        // The bands are the screen's in both directions: moreAvailableTop puts
        // one above the first row drawn, whichever model end the owner means by
        // it.
        // A slot and a band are both content above the rows, and they have to
        // stack in that order: the slot outside, the band next to the rows.
        function test_theBandStaysBetweenAHeaderAndTheRows() {
            view.moreAvailableTop = true
            provider.delay = 0
            freshFill(30)
            finishFill(30)

            view.header = headerComponent
            tryVerify(() => !!view.itemAtRow(0), 2000, "rows are up")
            waitForRendering(view)

            const slot = named("topSlot")
            const band = named("topPlaceholder")
            const firstRow = view.itemAtRow(0)

            verify(slot && slot.visible, "the slot is up")
            verify(band && band.visible, "and so is the band")
            verify(slot.y < band.y, "the slot is above the band")
            verify(band.y < firstRow.y, "and the band above the rows")

            view.header = null
        }

        // What the bands drive keeps working with slots in the column.
        function test_aBandStillAsksForMoreWithSlotsUp() {
            provider.delay = 0
            freshFill(30)
            finishFill(30)

            view.header = headerComponent
            view.footer = footerComponent
            waitForRendering(view)

            owner.startBudget = 3
            owner.endBudget = 3
            view.moreAvailableTop = Qt.binding(() => owner.startBudget > 0)
            view.moreAvailableBottom = Qt.binding(() => owner.endBudget > 0)
            view.autoRequest = true

            view.contentY = 0
            waitForRendering(view)

            tryVerify(() => owner.startBudget < 3, 3000,
                      "the band in the viewport asked for more")
            tryVerify(() => !view.busy, 8000, "and the batch landed")

            view.autoRequest = false
            view.header = null
            view.footer = null
        }

        // Finds an item by objectName, for the placements the view names.
        function named(name, obj) {
            const from = obj || view

            if (from.objectName === name)
                return from

            const kids = from.children

            for (let i = 0; kids && i < kids.length; ++i) {
                const found = named(name, kids[i])

                if (found)
                    return found
            }

            return null
        }

        function test_bottomUpTheTopBandIsStillAtTheTop() {
            renderBottomUp()
            view.moreAvailableTop = true
            view.moreAvailableBottom = false
            provider.delay = 0
            freshFill(30)
            finishFill(30)

            view.contentY = 0
            waitForRendering(view)

            compare(host(), "topPlaceholder")

            // bottom-up the first row drawn is the model's last
            const firstDrawn = view.itemAtRow(rows.count - 1)

            compare(firstDrawn.content.value, renderedValues()[0])
            verify(firstDrawn.y >= view.placeholderHeight - 0.5,
                   "the band reserved space above it")
        }

        // The chat case: a message arriving at model row 0 lands at the bottom,
        // inside the content, so there is nothing to announce.
        function test_bottomUpARowAtModelRowZeroPutsUpNoBand() {
            renderBottomUp()
            view.stickToBottom = true
            view.moreAvailableTop = false
            view.moreAvailableBottom = false
            provider.delay = 0
            freshFill(30)
            finishFill(30)

            view.contentY = view.contentHeight - view.height
            waitForRendering(view)
            verify(view.atBottom, "parked at the newest row")

            const before = view.contentHeight

            rows.insert(0, rows.make(owner.liveValue, 1))
            tryVerify(() => settled(31) && view.contentHeight > before, 5000,
                      "the row landed and was laid out")

            compare(host(), "", "no band was put up for it")
            compare(renderedValues()[30], owner.liveValue,
                    "it is simply drawn at the bottom")
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

        // The integration case is about the seams, not about paging policy.
        autoRequest: false

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

    // ------------------------------------------------------------------
    // The other row source: the C++ DelegatePool hands out pre-built rows and
    // RowBinder dresses them, where everything above binds roles by hand. The
    // view is the same; what differs is all on this side of acquireDelegate.
    // ------------------------------------------------------------------

    SQUtils.IndexWindowSource {
        id: pooledWindowSource

        sourceModel: sourceRows
        size: 30
    }

    PooledRowPool {
        id: pooledRowPool
    }

    QtObject {
        id: pooled

        // The pool never builds on demand - acquire() hands back what exists
        // or nothing - so a request that finds it dry waits here for an item
        // to be built or released. The view tolerates a late answer.
        property var queue: []
        property int starved: 0
        property int inUse: 0

        // Every item this group has ever seen dressed, so a test can tell a
        // reused row from a newly built one.
        property var seen: []

        function acquire(shell, row, modelRow, cb) {
            const item = pooledRowPool.acquire(pooledRowPool.kind)

            if (!item) {
                pooled.queue.push({ shell, cb })
                pooled.starved++
                return
            }

            pooled.dress(item, shell, row)
            cb(item)
        }

        function dress(item, shell, row) {
            // Width is not a role, so the binder does not do it.
            item.width = Qt.binding(() => (shell ? shell.width : undefined) ?? 0)
            item.binder.bind(pooledWindowSource.model, row)

            // acquire() only un-parks the item; until it is put in the shell it
            // stays a child of the pool's container, dressed and drawn nowhere.
            item.parent = shell

            if (pooled.seen.indexOf(item) === -1)
                pooled.seen.push(item)

            pooled.inUse++
        }

        function drain() {
            while (pooled.queue.length > 0) {
                const waiting = pooled.queue[0]

                // A row that left the window while it waited never had content
                // to hand back, so nothing was said about it - a destroyed
                // shell reads as null from JS, which is the only notice there
                // is.
                if (!waiting.shell) {
                    pooled.queue.shift()
                    continue
                }

                const item = pooledRowPool.acquire(pooledRowPool.kind)

                if (!item)
                    return

                pooled.queue.shift()
                pooled.dress(item, waiting.shell, waiting.shell.row)
                waiting.cb(item)
            }
        }

        function release(item) {
            item.binder.detach()
            // breaks the width binding without disturbing the value
            item.width = item.width
            pooledRowPool.release(item)
            pooled.inUse--
        }
    }

    Connections {
        target: pooledRowPool

        function onAvailabilityChanged(kind, readyCount) {
            if (kind === pooledRowPool.kind && readyCount > 0)
                pooled.drain()
        }
    }

    WindowedView {
        id: pooledView

        // Beside the other two, inside the window so it is laid out for real.
        x: 2 * root.width
        width: root.width
        height: root.height

        model: pooledWindowSource.model

        moreAvailableTop: pooledWindowSource.moreAvailableStart
        moreAvailableBottom: pooledWindowSource.moreAvailableEnd

        autoRequest: false

        acquireDelegate: pooled.acquire
        releaseDelegate: pooled.release

        onMoreRequestedTop: {
            pooledWindowSource.growStart(10)
            moreLoadedTop()
        }

        onMoreRequestedBottom: {
            pooledWindowSource.growEnd(10)
            moreLoadedBottom()
        }

        onBatchRevealed: pooledWindowSource.trim()
    }

    TestCase {
        id: headerFooterTests

        name: "WindowedView.HeaderFooter"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            root.bannerHeight = 40
        }

        // The groups share one view, so everything this touches goes back.
        function cleanup() {
            view.header = null
            view.footer = null
            view.topPadding = 0
            view.bottomPadding = 0
            view.stickToBottom = false
            view.placeholder = null
            view.autoRequest = false
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.TopToBottom
            view.moreAvailableTop = true
            view.moreAvailableBottom = true
            root.bannerHeight = 40
            root.width = 500
            owner.answerOwed = false
        }

        function fill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0, 2000, "emptied")

            owner.reset(count)
            tryVerify(() => settled(count), 8000, "rows laid out")
        }

        // The live slot content, wherever it has been placed.
        function named(name, obj) {
            const from = obj || view

            if (from.objectName === name)
                return from

            const kids = from.children

            for (let i = 0; kids && i < kids.length; ++i) {
                const found = named(name, kids[i])

                if (found)
                    return found
            }

            return null
        }

        function show(slot, component, name) {
            view[slot] = component
            tryVerify(() => !!named(name), 2000, name + " loaded")
            // the Loader has its item the moment the component is assigned; the
            // column only re-lays out on the next polish
            waitForRendering(view)
            return named(name)
        }

        function topInViewport(item) {
            return item.mapToItem(view, 0, 0).y
        }

        // The topmost row the reader can see the start of. Same shape as the
        // Resize group's, which is where the idea comes from.
        function topVisible() {
            for (const shell of shells()) {
                if (!shell.visible || !shell.content)
                    continue

                if (shell.y >= view.contentY + view.height)
                    break           // below the viewport entirely

                if (shell.y >= view.contentY - 0.5)
                    return { value: shell.content.value,
                             offset: shell.y - view.contentY }
            }

            return { value: -9999, offset: 0 }
        }

        // A slot's height lands on the item at once and in the column a polish
        // later, so a test that measures geometry has to wait for both.
        function resizeSlot(name, height) {
            root.bannerHeight = height
            tryVerify(() => Math.abs(named(name).height - height) < 0.5, 2000,
                      name + " took its new height")
            waitForRendering(view)
        }

        function wholeOnScreen(item) {
            const top = topInViewport(item)

            return top >= -0.5 && top + item.height <= view.height + 0.5
        }

        function bottomEdge() {
            return Math.max(0, view.contentHeight - view.height)
        }

        // ---- placement -------------------------------------------------

        function test_theSlotsFollowTheLayoutDirection() {
            fill(root.windowSize)

            const header = show("header", headerComponent, "headerBanner")
            const footer = show("footer", footerComponent, "footerBanner")

            compare(header.parent.objectName, "topSlot",
                    "top-down, the header is at the screen top")
            compare(footer.parent.objectName, "bottomSlot")

            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.BottomToTop
            tryVerify(() => settled(root.windowSize), 8000, "redrawn upside down")

            compare(named("headerBanner").parent.objectName, "bottomSlot",
                    "bottom-up, the header is at the screen bottom - under the "
                    + "model's first row, where ListView puts it")
            compare(named("footerBanner").parent.objectName, "topSlot")
        }

        function test_aSlotIsNotARow() {
            fill(root.windowSize)

            const rows = view.rowCount
            const key = view.keyAtRow(0)
            const without = view.contentHeight

            show("footer", footerComponent, "footerBanner")

            tryVerify(() => Math.abs(view.contentHeight
                                     - (without + root.bannerHeight)) < 0.5,
                      2000, "the content grew by the slot's height")
            compare(view.rowCount, rows, "the row count is untouched")
            compare(view.rowForKey(key), 0, "and so is addressing")
        }

        // ---- the rows must not move ------------------------------------

        // Space appearing above the viewport moves every row unless contentY
        // moves with it, which is what the view already does for the start
        // band. A slot there is the same thing.
        function test_aSlotAboveTheRowsDoesNotMoveThem() {
            fill(60)

            view.contentY = 300
            waitForRendering(view)

            const before = topVisible()

            show("header", headerComponent, "headerBanner")

            let after = topVisible()

            compare(after.value, before.value, "the same row is at the top")
            fuzzyCompare(after.offset, before.offset, 0.5,
                         "at the same offset, after the slot appeared")

            resizeSlot("headerBanner", 140)

            after = topVisible()
            compare(after.value, before.value, "still the same row")
            fuzzyCompare(after.offset, before.offset, 0.5, "after it grew")

            resizeSlot("headerBanner", 20)

            after = topVisible()
            compare(after.value, before.value)
            fuzzyCompare(after.offset, before.offset, 0.5, "after it shrank")

            view.header = null
            tryVerify(() => !named("headerBanner"), 2000, "the slot went away")
            waitForRendering(view)

            after = topVisible()
            compare(after.value, before.value)
            fuzzyCompare(after.offset, before.offset, 0.5, "after it went")
        }

        // ---- sticking to the end ---------------------------------------

        // ---- padding ---------------------------------------------------

        function rowTopInViewport(row) {
            return view.itemAtRow(row).mapToItem(view, 0, 0).y
        }

        function rowBottomInViewport(row) {
            const item = view.itemAtRow(row)

            return item.mapToItem(view, 0, item.height).y
        }

        function pad(top, bottom) {
            view.topPadding = top
            view.bottomPadding = bottom
            waitForRendering(view)
        }

        function test_thePaddingIsSpaceAtTheContentEdges() {
            fill(60)
            pad(16, 24)

            view.positionViewAtBeginning()
            waitForRendering(view)
            fuzzyCompare(rowTopInViewport(0), 16, 0.5,
                         "the first row starts below the top padding")

            view.positionViewAtEnd()
            waitForRendering(view)
            fuzzyCompare(rowBottomInViewport(59), view.height - 24, 0.5,
                         "and the last ends above the bottom padding")
        }

        function test_thePaddingIsOutsideTheSlots() {
            fill(60)
            const header = show("header", headerComponent, "headerBanner")
            const footer = show("footer", footerComponent, "footerBanner")
            pad(16, 24)

            view.positionViewAtBeginning()
            waitForRendering(view)
            fuzzyCompare(topInViewport(header), 16, 0.5, "the header is inside it")

            view.positionViewAtEnd()
            waitForRendering(view)
            fuzzyCompare(topInViewport(footer) + footer.height, view.height - 24,
                         0.5, "and so is the footer")
        }

        // Rendered bottom-up, model row 0 is the bottom row, and the screen's
        // bottom padding is still below it.
        function test_thePaddingIsTheScreensBottomUp() {
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.BottomToTop
            fill(60)
            pad(16, 24)

            view.positionViewAtBeginning()
            waitForRendering(view)
            fuzzyCompare(rowBottomInViewport(0), view.height - 24, 0.5,
                         "the model's first row rests on the bottom padding")
        }

        function test_changingTheTopPaddingDoesNotMoveTheRows() {
            fill(60)

            view.contentY = 300
            waitForRendering(view)

            const before = topVisible()

            pad(40, 0)

            const after = topVisible()

            compare(after.value, before.value, "the same row at the top")
            fuzzyCompare(after.offset, before.offset, 0.5, "at the same offset")
        }

        function test_stickingToTheEndKeepsTheBottomPadding() {
            view.stickToBottom = true
            fill(root.windowSize)
            pad(0, 24)

            view.positionViewAtEnd()
            tryVerify(() => view.atBottom, 2000, "at the bottom to begin with")

            owner.appendLive()

            const last = view.rowCount - 1

            tryVerify(() => view.itemAtRow(last).visible, 2000, "the row arrived")
            tryVerify(() => Math.abs(rowBottomInViewport(last)
                                     - (view.height - 24)) < 0.5, 2000,
                      "it shows above the padding, which stays in view")
        }

        function test_stickingToTheEndHoldsThroughABottomSlot() {
            view.stickToBottom = true
            fill(root.windowSize)

            view.contentY = bottomEdge()
            tryVerify(() => view.atBottom, 2000, "at the bottom to begin with")

            const footer = show("footer", footerComponent, "footerBanner")

            tryVerify(() => Math.abs(view.contentY - bottomEdge()) < 0.5, 2000,
                      "still at the bottom once the slot is there")
            verify(view.atBottom, "and the view says so")
            verify(wholeOnScreen(footer), "with the slot wholly in view")

            resizeSlot("footerBanner", 160)
            tryVerify(() => Math.abs(view.contentY - bottomEdge()) < 0.5, 2000,
                      "still at the bottom after it grew")
            verify(wholeOnScreen(named("footerBanner")))

            resizeSlot("footerBanner", 25)
            tryVerify(() => Math.abs(view.contentY - bottomEdge()) < 0.5, 2000,
                      "and after it shrank")
            verify(wholeOnScreen(named("footerBanner")))

            view.footer = null
            tryVerify(() => !named("footerBanner"), 2000, "the slot went away")
            waitForRendering(view)
            tryVerify(() => Math.abs(view.contentY - bottomEdge()) < 0.5, 2000,
                      "and the bottom is still the bottom")
            verify(view.atBottom)
        }

        // The chat's case: bottom-up, so the thing pinned at the screen bottom
        // is the *header*.
        function test_stickingToTheEndHoldsThroughTheHeaderBottomUp() {
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.BottomToTop
            view.stickToBottom = true
            fill(root.windowSize)

            view.contentY = bottomEdge()
            tryVerify(() => view.atBottom, 2000, "at the bottom")

            const header = show("header", headerComponent, "headerBanner")

            compare(header.parent.objectName, "bottomSlot")
            tryVerify(() => Math.abs(view.contentY - bottomEdge()) < 0.5, 2000,
                      "still at the bottom")
            verify(wholeOnScreen(header), "with the header in view")

            resizeSlot("headerBanner", 150)
            tryVerify(() => Math.abs(view.contentY - bottomEdge()) < 0.5, 2000,
                      "and after it grew")
            verify(wholeOnScreen(named("headerBanner")))
        }

        function test_aRowArrivingKeepsTheBottomSlotInView() {
            view.stickToBottom = true
            fill(root.windowSize)

            const footer = show("footer", footerComponent, "footerBanner")

            view.contentY = bottomEdge()
            tryVerify(() => view.atBottom, 2000, "at the bottom")

            owner.appendLive()
            tryVerify(() => view.rowCount === root.windowSize + 1, 5000,
                      "the row arrived")
            tryVerify(() => Math.abs(view.contentY - bottomEdge()) < 0.5, 2000,
                      "and the view followed it")

            verify(wholeOnScreen(named("footerBanner")),
                   "the slot is still in view")

            const last = view.itemAtRow(view.rowCount - 1)

            verify(topInViewport(last) + last.height
                   <= topInViewport(named("footerBanner")) + 0.5,
                   "and the new row sits above it, not behind it")
        }

        function test_theFirstFillWithASlotLandsAtTheBottomEdge() {
            view.stickToBottom = true
            show("footer", footerComponent, "footerBanner")

            fill(root.windowSize)

            tryVerify(() => Math.abs(view.contentY - bottomEdge()) < 0.5, 5000,
                      "the fill landed at the bottom of the content")
            verify(wholeOnScreen(named("footerBanner")),
                   "with the slot in view rather than below the fold")
        }

        // Reading mid-history, a slot appearing at either end must not drag the
        // reader to it - the pin is for a view that was already at the bottom.
        function test_aSlotDoesNotPullTheReaderToTheEnd() {
            view.stickToBottom = true
            fill(60)

            view.contentY = 200
            waitForRendering(view)

            const before = topVisible()

            show("footer", footerComponent, "footerBanner")

            const after = topVisible()

            compare(after.value, before.value, "the same row is at the top")
            fuzzyCompare(after.offset, before.offset, 0.5, "at the same offset")
            verify(!view.atBottom, "and the view did not jump to the end")
        }

        // The pin is for a view that is at the bottom; a slot growing past the
        // viewport takes the bottom away from it, and the view has to say so
        // rather than claim it is still there.
        function test_atBottomGoesFalseWhenASlotGrowsPastTheViewport() {
            fill(60)

            const footer = show("footer", footerComponent, "footerBanner")

            view.contentY = bottomEdge()
            waitForRendering(view)
            verify(view.atBottom, "at the bottom to begin with")

            const before = topVisible()

            resizeSlot("footerBanner", view.height + 80)

            verify(!view.atBottom,
                   "the slot pushed the end below the viewport")

            const after = topVisible()

            compare(after.value, before.value,
                    "and nothing above the viewport moved")
            fuzzyCompare(after.offset, before.offset, 0.5)
        }

        // ---- positioning -----------------------------------------------

        function test_positioningARowIgnoresTheSlots() {
            fill(60)

            verify(view.positionViewAtRow(30,
                                          WindowedView.PositionMode.Beginning),
                   "accepted")
            waitForRendering(view)

            const without = topInViewport(view.itemAtRow(30))

            show("header", headerComponent, "headerBanner")
            show("footer", footerComponent, "footerBanner")

            verify(view.positionViewAtRow(30,
                                          WindowedView.PositionMode.Beginning))
            waitForRendering(view)

            fuzzyCompare(topInViewport(view.itemAtRow(30)), without, 0.5,
                         "the row still lands at the viewport top")

            verify(view.positionViewAtRow(30, WindowedView.PositionMode.Center))
            waitForRendering(view)

            const item = view.itemAtRow(30)

            fuzzyCompare(topInViewport(item) + item.height / 2,
                         view.height / 2, 1.0, "and centres on the viewport")
        }

        function test_theOffsetRoundTripSurvivesTheSlots() {
            fill(60)
            show("header", headerComponent, "headerBanner")
            show("footer", footerComponent, "footerBanner")

            view.contentY = 400
            waitForRendering(view)

            const row = 25
            const captured = view.viewportOffsetToRow(row)

            verify(!isNaN(captured), "captured an offset")

            view.positionViewAtEnd()
            waitForRendering(view)
            verify(Math.abs(view.viewportOffsetToRow(row) - captured) > 20,
                   "the position is genuinely lost")

            verify(view.positionViewAtRowOffset(row, captured), "accepted")
            tryVerify(() => Math.abs(view.viewportOffsetToRow(row) - captured)
                            < 0.5, 5000, "and restored to the pixel")
        }

        // Content edges, so they include the slots - ListView's do too.
        function test_theContentEdgesIncludeTheSlots() {
            fill(60)

            const header = show("header", headerComponent, "headerBanner")
            const footer = show("footer", footerComponent, "footerBanner")

            view.positionViewAtBeginning()
            waitForRendering(view)

            fuzzyCompare(view.contentY, 0, 0.5, "the beginning is the content's")
            verify(wholeOnScreen(header),
                   "which is where the header is, above the first row")

            view.positionViewAtEnd()
            waitForRendering(view)

            fuzzyCompare(view.contentY, bottomEdge(), 0.5)
            verify(wholeOnScreen(footer), "and the footer is at the end")
        }

        function test_theResizeAnchorHoldsWithSlots() {
            provider.delegate = layoutDelegate
            fill(60)
            show("header", headerComponent, "headerBanner")
            show("footer", footerComponent, "footerBanner")

            view.contentY = 300
            waitForRendering(view)

            const before = topVisible()

            root.width = 380
            tryVerify(() => !view.busy, 5000, "the re-wrap settled")
            waitForRendering(view)

            const after = topVisible()

            compare(after.value, before.value,
                    "the same row is at the viewport top")
            fuzzyCompare(after.offset, before.offset, 1.0,
                         "and at the same offset")
        }
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

        // moveTo() replaces every row in the window. Whether the view sees that
        // as a removal followed by an insertion - which is what makes it look
        // like a fresh population - is SortFilterProxyModel's business, so it
        // is asserted here rather than assumed.
        function test_aJumpThroughTheRealSourceLooksLikeAFreshPopulation() {
            const firstBefore = windowSource.first

            windowSource.moveTo(firstBefore + 90)

            compare(smokeView.initialLoading, true, "staged as one population")

            tryVerify(() => !smokeView.busy && smokeView.rowCount === 30
                            && smokeView.contentHeight > smokeView.height, 10000,
                      "and revealed")

            compare(windowSource.first, firstBefore + 90)
            compare(smokeView.initialLoading, false)
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

    TestCase {
        id: cppPoolTests

        name: "WindowedView.CppPool"
        when: windowShown

        function initTestCase() {
            waitForRendering(pooledView)
        }

        function init() {
            // Whatever the last test left queued belongs to rows that are
            // still alive, so it is drained rather than dropped: a dropped
            // answer leaves its row staged for ever.
            pooledRowPool.target = 60
            pooledRowPool.boost(pooledRowPool.kind, 30)
            pooledWindowSource.size = 30
            pooledWindowSource.moveTo(0)

            tryVerify(() => pooled.queue.length === 0 && !pooledView.busy
                            && pooledView.rowCount === 30, 30000,
                      "the window filled from the pool")
            waitForRendering(pooledView)

            pooledRowPool.clearBoost(pooledRowPool.kind)
            pooled.starved = 0
        }

        function cleanup() {
            pooledView.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.TopToBottom
        }

        function dressedRows() {
            let dressed = 0

            for (let row = 0; row < pooledView.rowCount; ++row) {
                const shell = pooledView.itemAtRow(row)

                if (shell && shell.content)
                    ++dressed
            }

            return dressed
        }

        function sourceRowOf(row) {
            // what the window holds at that row, in the source model's terms
            return pooledWindowSource.first + row
        }

        function test_everyRowOfTheFillIsDressedFromThePool() {
            compare(dressedRows(), pooledView.rowCount,
                    "every row has an item")

            // Dressed is not drawn: an item the pool handed over is still its
            // own child until someone puts it in the shell.
            for (let row = 0; row < pooledView.rowCount; ++row) {
                const shell = pooledView.itemAtRow(row)

                compare(shell.content.parent, shell,
                        "row " + row + "'s item sits in its shell")
            }

            const first = pooledView.itemAtRow(0)

            verify(first.content.width > 0 && first.content.height > 0,
                   "and has a size")
            compare(pooled.inUse, pooledView.rowCount,
                    "one item per row, none left over")
            verify(pooled.seen.length >= pooledView.rowCount,
                   "and they were all built: " + pooled.seen.length)
        }

        // The binder is told a model row; the item has to end up showing that
        // row's data, whichever way the view lays the rows out.
        function test_theBinderDressesTheRowTheViewSaysItIs() {
            for (let row = 0; row < pooledView.rowCount; ++row) {
                const shell = pooledView.itemAtRow(row)

                verify(!!shell && !!shell.content, "row " + row + " is dressed")
                compare(shell.content.messageText,
                        "message " + sourceRowOf(row),
                        "row " + row + " shows its own message")
            }
        }

        function test_theBinderIsRightBottomUpToo() {
            pooledView.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.BottomToTop
            tryVerify(() => !pooledView.busy && pooledView.rowCount === 30,
                      20000, "refilled upside down")
            waitForRendering(pooledView)

            for (let row = 0; row < pooledView.rowCount; ++row) {
                const shell = pooledView.itemAtRow(row)

                verify(!!shell && !!shell.content, "row " + row + " is dressed")
                compare(shell.content.messageText,
                        "message " + sourceRowOf(row),
                        "model row " + row + " still shows its own message")
            }

            // and the model's first row is the one at the bottom
            verify(pooledView.itemAtRow(0).y
                   > pooledView.itemAtRow(pooledView.rowCount - 1).y)
        }

        // The pool answers with nothing when it is dry, which is not an error:
        // the request waits, and the row is dressed once an item exists.
        function test_aDryPoolMakesTheRowWaitAndThenDressesIt() {
            // Three times the window in one go. The thirty items in use are
            // not coming back, the pool has at most thirty more parked, and
            // its target forbids building the rest - so some rows have to
            // wait.
            pooledWindowSource.size = 90

            tryVerify(() => pooled.starved > 0, 10000,
                      "rows found the pool dry")

            const waiting = pooled.queue.length

            verify(waiting > 0, "and are queued: " + waiting)
            verify(dressedRows() < pooledView.rowCount,
                   "so some rows are holding their place without an item")

            // Room to build the rest, and priority while it does.
            pooledRowPool.target = 120
            pooledRowPool.boost(pooledRowPool.kind, 120)

            tryVerify(() => pooled.queue.length === 0, 30000,
                      "the queue drained")
            tryVerify(() => !pooledView.busy && pooledView.rowCount === 90,
                      30000, "and the view settled")

            compare(dressedRows(), pooledView.rowCount,
                    "every row that waited is dressed")
        }

        function test_slidingReusesItemsAndLeaksNone() {
            const seenBefore = pooled.seen.length

            for (let i = 0; i < 5; ++i) {
                verify(pooledView.requestMoreBottom(), "slide " + i)
                tryVerify(() => !pooledView.busy, 20000)
            }

            compare(pooledView.rowCount, 30, "the window kept its size")
            compare(dressedRows(), pooledView.rowCount, "and is fully dressed")

            // A slide overlaps - the new chunk exists before the far end is
            // dropped - so the pool grows by at most a chunk, not by a window
            // per slide.
            verify(pooled.seen.length <= seenBefore + 10,
                   "no new items beyond one chunk: " + seenBefore + " -> "
                   + pooled.seen.length)

            compare(pooled.seen.filter(item => !!item).length,
                    pooled.seen.length,
                    "no item was destroyed between the shell dying and the "
                    + "pool taking it back")
            compare(pooled.inUse, pooledView.rowCount,
                    "and the view holds exactly as many as it has rows")
        }

        // A row can leave the window while its request is still queued. It is
        // never told anything - it had no content to hand back - so the drain
        // is what has to notice.
        function test_aRowLeavingWhileStarvedDoesNotWedgeTheDrain() {
            // Starve a batch: the whole source model at once, which no pool
            // the earlier tests could have grown is able to supply.
            pooledWindowSource.size = 200
            tryVerify(() => pooled.queue.length > 0, 10000, "rows queued")

            // Away again before anything could answer them: these shells die
            // without ever having had content to hand back.
            pooledWindowSource.size = 30
            pooledWindowSource.moveTo(0)

            pooledRowPool.boost(pooledRowPool.kind, 30)
            tryVerify(() => pooled.queue.length === 0, 20000,
                      "the drain got through the dead shells")
            tryVerify(() => !pooledView.busy && pooledView.rowCount === 30,
                      20000, "and the window is whole")

            compare(dressedRows(), pooledView.rowCount,
                    "with every row dressed")
            compare(pooled.seen.filter(item => !!item).length,
                    pooled.seen.length, "and nothing lost on the way")
        }
    }

    TestCase {
        id: addressingTests

        name: "WindowedView.Addressing"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
        }

        function cleanup() {
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.TopToBottom
        }

        function fill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0, 2000, "emptied")

            owner.reset(count)
            tryVerify(() => settled(count), 5000, "rows laid out")
        }

        function test_rowForKeyAndKeyAtRowAreInverses() {
            fill(20)

            for (let row = 0; row < view.rowCount; ++row) {
                const key = view.keyAtRow(row)

                compare(key, "k" + row, "the harness stamps keys from the value")
                compare(view.rowForKey(key), row, "and the lookup comes back")
            }
        }

        // Model rows, like itemAtRow(): rendering bottom-up moves row 0 to the
        // bottom, it does not renumber it.
        function test_bothAnswerInModelRowsWhenRenderingBottomUp() {
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.BottomToTop
            fill(20)

            compare(view.rowForKey("k0"), 0)
            compare(view.keyAtRow(0), "k0")
            compare(view.itemAtRow(0).content.value, 0,
                    "and all three agree on which row that is")

            const first = view.itemAtRow(0)
            const last = view.itemAtRow(19)

            verify(first.y > last.y, "while row 0 is the one drawn lowest")
        }

        function test_aRowTheViewDoesNotHold() {
            fill(10)

            compare(view.rowForKey("k99"), -1)
            compare(view.rowForKey(""), -1)
            compare(view.keyAtRow(10), undefined)
            compare(view.keyAtRow(-1), undefined)
        }

        // Held is not the same as visible: a staged row has no content and no
        // height yet, and must still be addressable - that is what lets an
        // owner resolve a jump target in the frame a batch is revealed.
        function test_aStagedRowIsStillFound() {
            provider.delay = 60
            fill(20)

            owner.removeOnReveal = false
            verify(view.requestMoreBottom(), "the request was taken")
            tryVerify(() => view.staging, 2000, "a batch is staged")

            // the owner admits values 20.. at the model's end, so k20 is the
            // first row of the batch
            compare(view.rowForKey("k20"), 20, "the staged row answers")
            compare(view.keyAtRow(20), "k20")

            const shell = view.itemAtRow(20)

            verify(shell, "its shell exists")
            verify(!shell.visible, "and is not on screen yet")

            tryVerify(() => !view.busy, 8000, "the batch was revealed")
            compare(view.rowForKey("k20"), 20, "and still answers after it")
            owner.removeOnReveal = true
        }

        function test_withoutAModel() {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0, 2000, "emptied")

            compare(view.rowForKey("k0"), -1)
            compare(view.keyAtRow(0), undefined)
        }
    }

    TestCase {
        id: positioningTests

        name: "WindowedView.Positioning"
        when: windowShown

        readonly property int beginning: WindowedView.PositionMode.Beginning
        readonly property int centre: WindowedView.PositionMode.Center
        readonly property int atEnd: WindowedView.PositionMode.End
        readonly property int contain: WindowedView.PositionMode.Contain

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            positionedSpy.clear()
        }

        function cleanup() {
            view.stickToBottom = false
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.TopToBottom
            owner.removeOnReveal = true
            owner.answerOwed = false
        }

        function fill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0, 2000, "emptied")

            owner.reset(count)
            tryVerify(() => settled(count), 8000, "rows laid out")
        }

        function bottomY() {
            return view.contentHeight - view.height
        }

        // Where a row's top sits in the viewport, which is what every mode here
        // is expressed in.
        function topOf(row) {
            const item = view.itemAtRow(row)

            return item.mapToItem(view, 0, 0).y
        }

        function test_beginningPutsTheRowsTopAtTheViewportTop() {
            fill(40)

            verify(view.positionViewAtRow(20, beginning))
            waitForRendering(view)

            fuzzyCompare(topOf(20), 0, 0.5)
        }

        function test_centreCentresIt() {
            fill(40)

            verify(view.positionViewAtRow(20, centre))
            waitForRendering(view)

            const item = view.itemAtRow(20)

            fuzzyCompare(topOf(20) + item.height / 2, view.height / 2, 0.5)
        }

        function test_endPutsItsBottomAtTheViewportBottom() {
            fill(40)

            verify(view.positionViewAtRow(20, atEnd))
            waitForRendering(view)

            const item = view.itemAtRow(20)

            fuzzyCompare(topOf(20) + item.height, view.height, 0.5)
        }

        // The point of Contain is to leave a reader where they are.
        function test_containLeavesAWhollyVisibleRowAlone() {
            fill(40)

            verify(view.positionViewAtRow(20, centre))
            waitForRendering(view)

            const before = view.contentY
            const offset = topOf(20)

            verify(view.positionViewAtRow(20, contain))
            waitForRendering(view)

            compare(view.contentY, before, "the view did not move")
            fuzzyCompare(topOf(20), offset, 0.5)
        }

        function test_containScrollsARowThatIsNotWhollyVisible() {
            fill(40)

            verify(view.positionViewAtRow(20, beginning))
            waitForRendering(view)

            // one row further down is partly or wholly below the viewport
            const far = 20 + Math.max(1, Math.floor(view.height / 60))

            verify(view.positionViewAtRow(far, contain))
            waitForRendering(view)

            const item = view.itemAtRow(far)

            verify(topOf(far) >= -0.5, "it is on screen")
            verify(topOf(far) + item.height <= view.height + 0.5,
                   "and wholly so")
        }

        function test_aRowTheViewDoesNotHoldIsRefused() {
            fill(20)

            const before = view.contentY

            compare(view.positionViewAtRow(20, centre), false)
            compare(view.positionViewAtRow(-1, centre), false)
            compare(view.positionViewAtRowOffset(99, 10), false)
            compare(view.contentY, before, "and nothing moved")
        }

        function test_rowPositionedFiresOnceForAJump() {
            fill(40)

            verify(view.positionViewAtRow(20, centre))
            tryVerify(() => positionedSpy.count === 1, 2000, "it reported")
            compare(positionedSpy.signalArguments[0][0], 20,
                    "in model rows, like the request")

            wait(50)
            compare(positionedSpy.count, 1, "and only once")
        }

        // The restore primitive must pass unnoticed, so it does not report.
        function test_theOffsetFormDoesNotReport() {
            fill(40)

            verify(view.positionViewAtRowOffset(20, 30))
            waitForRendering(view)

            fuzzyCompare(topOf(20), -30, 0.5, "the viewport top is 30px into it")
            compare(positionedSpy.count, 0)
        }

        function test_viewportOffsetToRowIsNaNWithoutGeometry() {
            fill(20)

            verify(isNaN(view.viewportOffsetToRow(20)), "no such row")
            verify(!isNaN(view.viewportOffsetToRow(0)), "but this one has it")
        }

        // The window record in miniature: capture an offset, lose the position,
        // put it back.
        function test_captureAndRestoreHoldToThePixel() {
            fill(60)

            verify(view.positionViewAtRow(30, centre))
            waitForRendering(view)

            const key = view.keyAtRow(30)
            const captured = view.viewportOffsetToRow(30)

            verify(!isNaN(captured))

            // somewhere else entirely
            view.contentY = 0
            waitForRendering(view)
            verify(Math.abs(view.viewportOffsetToRow(30) - captured) > 10,
                   "the position is genuinely lost")

            const row = view.rowForKey(key)

            compare(row, 30, "found again by key")
            verify(view.positionViewAtRowOffset(row, captured))
            waitForRendering(view)

            fuzzyCompare(view.viewportOffsetToRow(30), captured, 0.5,
                         "and back to the pixel")
        }

        function test_bothEndsInBothDirections() {
            fill(40)

            view.positionViewAtBeginning()
            waitForRendering(view)
            fuzzyCompare(view.contentY, 0, 0.5, "top-down the model starts up")

            view.positionViewAtEnd()
            waitForRendering(view)
            fuzzyCompare(view.contentY, bottomY(), 0.5)

            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.BottomToTop
            tryVerify(() => settled(40), 8000, "rebuilt bottom-up")

            view.positionViewAtBeginning()
            waitForRendering(view)
            fuzzyCompare(view.contentY, bottomY(), 0.5,
                         "bottom-up the model starts at the bottom")

            view.positionViewAtEnd()
            waitForRendering(view)
            fuzzyCompare(view.contentY, 0, 0.5)
        }

        // Accepted is not done: a staged row has no geometry, and the request
        // is honoured when the reveal gives it some.
        function test_aRequestForAStagedRowWaitsForTheReveal() {
            provider.delay = 60
            fill(30)

            owner.removeOnReveal = false
            verify(view.requestMoreBottom())
            tryVerify(() => view.staging, 2000, "a batch is staged")

            const shell = view.itemAtRow(30)

            verify(shell && !shell.visible, "its row is held but not shown")
            verify(view.positionViewAtRow(30, beginning), "accepted anyway")
            compare(positionedSpy.count, 0, "but not yet honoured")

            tryVerify(() => positionedSpy.count === 1, 8000,
                      "the reveal honoured it")
            waitForRendering(view)
            fuzzyCompare(topOf(30), 0, 0.5)
        }

        // A jump wins over stick-to-bottom: asked for a row while parked at
        // the bottom with the pin on, the view ends up at the row.
        function test_aJumpWinsOverStickToBottom() {
            provider.delay = 60
            view.stickToBottom = true
            fill(30)

            view.contentY = bottomY()
            waitForRendering(view)
            verify(view.atBottom)

            owner.removeOnReveal = false
            verify(view.requestMoreBottom())
            tryVerify(() => view.staging, 2000, "a batch is staged")
            verify(view.positionViewAtRow(5, beginning))

            tryVerify(() => positionedSpy.count === 1, 8000, "honoured")
            waitForRendering(view)

            fuzzyCompare(topOf(5), 0, 0.5, "where it was asked for")
            verify(!view.atBottom, "not dragged back to the bottom")
        }

        // Handed to the anchor afterwards, so later content changes hold the row
        // where the jump put it.
        function test_theAnchorHoldsTheRowAfterwards() {
            fill(40)

            verify(view.positionViewAtRow(20, centre))
            waitForRendering(view)

            const offset = view.viewportOffsetToRow(20)

            owner.removeOnReveal = false
            provider.delay = 0
            rows.insert(0, rows.make(500, 5))
            tryVerify(() => settled(45), 8000, "rows went in above")

            const row = view.rowForKey("k20")

            fuzzyCompare(view.viewportOffsetToRow(row), offset, 0.5,
                         "the row the jump chose stayed put")
        }

        // What the clamp-retry is for: an exact offset the content is currently
        // too short to honour is kept, not spent landing at the clamp, and is
        // honoured once there is content enough.
        function test_anUnsatisfiableOffsetWaitsForTheContentToGrow() {
            fill(20)

            const last = view.rowCount - 1
            const far = 400

            verify(view.positionViewAtRowOffset(last, far), "accepted")
            waitForRendering(view)

            verify(Math.abs(view.viewportOffsetToRow(last) - far) > 1,
                   "it cannot be honoured yet")
            fuzzyCompare(view.contentY, bottomY(), 1.0,
                         "so the view sits at the clamp meanwhile")

            provider.delay = 0
            rows.append(rows.make(100, 20))
            tryVerify(() => settled(40), 8000, "the content grew")

            // the retry lands on the relayout that follows, so the outcome is
            // the thing to wait for
            tryVerify(() => Math.abs(view.viewportOffsetToRow(last) - far) < 0.5,
                      5000, "and the offset is honoured exactly")
        }

        // Where an owner that had to move its window resolves a jump: inside
        // the reveal, which fires before the batch is laid out. The request has
        // to be positioned against the new layout, not the previous one - the
        // rows have heights by then but the Column has not placed them.
        function test_aRequestMadeFromTheRevealUsesTheNewLayout() {
            provider.delay = 30
            fill(30)

            let asked = false

            function onRevealed() {
                if (asked)
                    return

                asked = true

                const row = view.rowForKey("k35")

                if (row >= 0)
                    view.positionViewAtRow(row,
                                           WindowedView.PositionMode.Center)
            }

            view.batchRevealed.connect(onRevealed)
            owner.removeOnReveal = false
            verify(view.requestMoreBottom(), "the request was taken")
            tryVerify(() => !view.busy && positionedSpy.count === 1, 8000,
                      "the jump was honoured")
            view.batchRevealed.disconnect(onRevealed)
            waitForRendering(view)

            verify(asked, "the reveal is where the jump was asked for")

            const item = view.itemAtRow(35)

            verify(item, "the row arrived with the batch")
            fuzzyCompare(topOf(35) + item.height / 2, view.height / 2, 1.0,
                         "and is centred against the laid-out batch")
        }

        function test_aUserScrollAbandonsAPendingRequest() {
            provider.delay = 60
            fill(30)

            owner.removeOnReveal = false
            verify(view.requestMoreBottom())
            tryVerify(() => view.staging, 2000, "a batch is staged")
            verify(view.positionViewAtRow(30, beginning))

            // the user has other ideas
            view.contentY = 40
            waitForRendering(view)

            tryVerify(() => !view.busy, 8000, "the batch was revealed")
            compare(positionedSpy.count, 0, "the jump was abandoned")
        }
    }

    TestCase {
        id: bottomUpTests

        name: "WindowedView.BottomToTop"
        when: windowShown

        function initTestCase() {
            waitForRendering(view)
        }

        function init() {
            provider.reset()
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.BottomToTop
        }

        // The groups share one view, so the direction has to be handed back or
        // it leaks into everything that runs after this.
        function cleanup() {
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.TopToBottom
            view.stickToBottom = false
            view.moreAvailableTop = true
            view.moreAvailableBottom = true
            owner.answerOwed = false
        }

        function fill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0 && view.contentY === 0, 2000,
                      "starting from an empty view at the top")

            owner.reset(count)
            tryVerify(() => settled(count), 8000, "rows laid out")
        }

        function test_modelRowZeroIsDrawnAtTheBottom() {
            fill(20)

            const first = view.itemAtRow(0)
            const last = view.itemAtRow(19)

            verify(first && last)
            compare(first.content.value, 0, "itemAtRow(0) is still model row 0")
            compare(last.content.value, 19)
            verify(first.y > last.y,
                   "and model row 0 is drawn below the last row")
        }

        function test_theRowsRunUpTheScreen() {
            fill(20)

            const drawn = renderedValues()

            compare(drawn.length, 20)
            compare(drawn[0], 19, "the last model row is drawn first")
            compare(drawn[19], 0, "and model row 0 last")

            for (let i = 1; i < drawn.length; ++i)
                compare(drawn[i], drawn[i - 1] - 1,
                        "the order is exactly reversed, with no gaps")
        }

        function test_theRowCountIsStillTheModelsOwn() {
            fill(20)

            compare(view.rowCount, 20)
            compare(view.rowCount, rows.count)
        }

        function test_itemAtRowOutsideTheModelIsNull() {
            fill(10)

            verify(!view.itemAtRow(10))
            verify(!view.itemAtRow(-1))
        }

        // The chat case: a message arrives at model row 0, which bottom-up is
        // the bottom of the screen. The user is already there, so it should
        // simply appear. (That no band goes up for it is checked in the
        // Placeholder group, which owns the one placeholder instance.)
        function test_aRowAtModelRowZeroJoinsTheBottom() {
            view.stickToBottom = true
            view.moreAvailableTop = false
            view.moreAvailableBottom = false

            fill(30)

            view.contentY = view.contentHeight - view.height
            waitForRendering(view)
            verify(view.atBottom, "parked at the newest row")

            const before = view.contentHeight

            rows.insert(0, rows.make(owner.liveValue, 1))
            tryVerify(() => settled(31) && view.contentHeight > before, 5000,
                      "the row landed and was laid out")

            compare(view.itemAtRow(0).content.value, owner.liveValue,
                    "the new row is model row 0")
            compare(renderedValues()[30], owner.liveValue,
                    "and it is drawn last, at the bottom")
            verify(view.atBottom, "the viewport followed it")
        }

        // The mirror: a request at the top has to be answered from the
        // model's end, because bottom-up that is what lies above the viewport.
        function test_aRequestAtTheTopIsAnsweredFromTheModelsEnd() {
            fill(30)

            view.contentY = 0
            waitForRendering(view)

            const before = topRow()

            provider.delay = 30
            owner.revealCount = 0
            owner.removeOnReveal = false

            verify(view.requestMoreTop(), "the request was taken")
            tryVerify(() => settled(40), 8000, "the batch was revealed")

            compare(owner.revealCount, 1, "one reveal for the whole batch")
            compare(owner.admittedAtStart, false,
                    "the harness crossed: admitted at the model's end")
            compare(renderedValues()[0], 39,
                    "and the newest of them is drawn at the very top")

            const offsetAfter = offsetOf(before.value)

            verify(!isNaN(offsetAfter), "the row the user was reading survived")
            fuzzyCompare(offsetAfter, before.offset, 0.5, "and did not move")

            owner.removeOnReveal = true
        }

        function test_aRemovalTranslates() {
            fill(20)

            rows.remove(0, 1)       // model row 0: the bottom row
            tryVerify(() => settled(19), 5000, "the row went away")

            compare(view.itemAtRow(0).content.value, 1,
                    "model row 0 is now what was row 1")
            compare(renderedValues()[18], 1, "drawn at the bottom")
            verify(renderedValues().indexOf(0) === -1, "and 0 is gone")
        }

        // atBottom and stickToBottom are the screen's, in both directions.
        function test_atBottomStillMeansTheBottomOfTheScreen() {
            fill(40)

            view.contentY = 0
            waitForRendering(view)
            verify(!view.atBottom, "at the top of the content")

            view.contentY = view.contentHeight - view.height
            waitForRendering(view)
            verify(view.atBottom)
        }

        // settled() insists the content overflows the viewport, which is the one
        // thing the two tests below are about it not doing.
        function shortFill(count) {
            owner.reset(0)
            tryVerify(() => view.rowCount === 0 && view.contentY === 0, 2000,
                      "starting from an empty view at the top")

            owner.reset(count)
            tryVerify(() => !view.busy && view.rowCount === count
                            && hiddenShells().length === 0
                            && view.itemAtRow(0).height > 0, 5000,
                      "rows laid out")
        }

        // Where a row sits in the viewport, which is not its y: the Column is
        // offset when it holds less than a screenful of bottom-up rows.
        function viewportTopOf(shell) {
            return shell.mapToItem(view, 0, 0).y
        }

        // Qt's BottomToTop rests short content on the bottom edge rather than
        // hanging it from the top, and a chat wants exactly that.
        function test_contentShorterThanTheViewportSitsAtTheBottom() {
            shortFill(2)

            compare(view.contentHeight, view.height,
                    "nothing to scroll: the content is the viewport")

            const bottomRow = view.itemAtRow(0)      // model row 0, drawn last
            const topRow = view.itemAtRow(1)

            verify(bottomRow.height + topRow.height < view.height,
                   "and the rows are genuinely shorter than it")

            fuzzyCompare(viewportTopOf(bottomRow) + bottomRow.height,
                         view.height, 0.5,
                         "the last row drawn ends on the bottom edge")
            verify(viewportTopOf(topRow) > 0,
                   "and the first one starts below the top edge")
            compare(renderedValues(), [1, 0], "still drawn bottom-up")
        }

        function test_shortContentTopDownStillSitsAtTheTop() {
            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.TopToBottom
            shortFill(2)

            compare(view.contentHeight, view.height)
            fuzzyCompare(viewportTopOf(view.itemAtRow(0)), 0, 0.5,
                         "the first row starts at the top edge")
            compare(renderedValues(), [0, 1])
        }

        function test_switchingDirectionReplacesTheContent() {
            fill(20)

            compare(renderedValues()[0], 19)

            view.verticalLayoutDirection
                    = WindowedView.VerticalLayoutDirection.TopToBottom
            tryVerify(() => settled(20), 8000, "the rows were rebuilt")

            verify(!view.busy, "and the view is idle again, not wedged")
            compare(renderedValues()[0], 0, "now drawn the other way up")
            compare(view.itemAtRow(0).content.value, 0,
                    "and itemAtRow still answers in model rows")
        }

        // The number is the *model* row, not the rendered one: rendering
        // bottom-up moves row 0 to the bottom, it does not renumber it.
        // How much a model arriving costs, in acquires per row.
        function remodelAcquires(bottomUp) {
            view.verticalLayoutDirection = bottomUp
                    ? WindowedView.VerticalLayoutDirection.BottomToTop
                    : WindowedView.VerticalLayoutDirection.TopToBottom
            owner.reset(20)
            tryVerify(() => !view.busy && view.rowCount === 20, 8000, "filled")

            view.model = null
            tryVerify(() => view.rowCount === 0, 2000, "emptied")
            provider.forgetDressing()

            view.model = rows
            tryVerify(() => !view.busy && view.rowCount === 20, 8000,
                      "filled again")

            return provider.dressedCount
        }

        // A Repeater handed a proxy that has no source yet builds every row
        // against its empty shape, throws them away and builds them all again
        // when the source lands. Rendering bottom-up puts such a proxy between
        // the model and the rows, so the view has to keep it to itself until it
        // has a source - and a model arriving then costs what it costs
        // top-down, where there is no proxy at all.
        function test_aModelArrivingBuildsEachRowOnce() {
            const bottomUp = remodelAcquires(true)
            const topDown = remodelAcquires(false)

            compare(topDown, 20, "top-down: one acquire per row")
            compare(bottomUp, topDown, "bottom-up: the same, not twice over")
        }

        function test_theProviderIsToldTheModelRow() {
            provider.forgetDressing()
            fill(20)

            compare(provider.dressedCount, 20, "one acquire per row")

            for (let row = 0; row < 20; ++row) {
                const shell = view.itemAtRow(row)

                compare(provider.dressedAt[row], shell,
                        "row " + row + " was dressed as row " + row)
                compare(shell.row, row, "and the shell says the same")
            }

            compare(provider.dressedAt[0].content.value, 0,
                    "row 0 is the model's first row")
            verify(provider.dressedAt[0].y > provider.dressedAt[19].y,
                   "and it is the one drawn at the bottom")
        }
    }

}
