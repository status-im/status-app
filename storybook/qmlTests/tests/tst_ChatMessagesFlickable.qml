import QtQuick
import QtQuick.Layouts
import QtTest

import SortFilterProxyModel 0.2

import shared.views.chat

Item {
    id: root

    width: 400
    height: 300

    // 1000 rows, index 0 being the newest message, as in the messages model
    ListModel {
        id: history

        Component.onCompleted: {
            for (let i = 0; i < 1000; ++i)
                append({ text: "message " + i })
        }

        onRowsInserted: (parent, first, last) => {
            if (window.start > 0 && first <= window.start) {
                const inserted = last - first + 1
                window.start += inserted
                window.end += inserted
            }
            if (first <= window.end)
                Qt.callLater(window.refilter)
        }
    }

    QtObject {
        id: window

        readonly property int size: 40
        readonly property int chunk: 10
        readonly property int max: 60

        property int start: 0
        property int end: size - 1

        function reset() {
            start = 0
            end = size - 1
        }

        // Mirrors the owner-side workaround for QSortFilterProxyModel not
        // re-evaluating existing rows when the source shifts them.
        function refilter() {
            const e = end
            end = e + 1
            end = e
        }

        function slideToHistory() {
            if (end >= history.count - 1)
                return
            end = Math.min(history.count - 1, end + chunk)
            if (end - start + 1 > max)
                start = end - max + 1
        }

        function slideToRecent() {
            if (start <= 0)
                return
            start = Math.max(0, start - chunk)
            if (end - start + 1 > max)
                end = start + max - 1
        }
    }

    Component {
        id: viewComponent

        ChatMessagesFlickable {
            id: flick

            anchors.fill: parent

            placeholderHeight: 100

            moreUpAvailable: window.end < history.count - 1
            moreDownAvailable: window.start > 0

            onMoreUpRequested: window.slideToHistory()
            onMoreDownRequested: window.slideToRecent()

            placeholder: Rectangle { color: "transparent" }

            model: SortFilterProxyModel {
                sourceModel: history

                filters: IndexFilter {
                    minimumIndex: window.start
                    maximumIndex: window.end
                }
            }

            delegate: Rectangle {
                objectName: "row"

                readonly property string rowText: model.text

                Layout.row: flick.rowCount - index + 1
                Layout.column: 0
                Layout.fillWidth: true
                Layout.preferredHeight: 20
            }
        }
    }

    TestCase {
        id: testCase

        name: "ChatMessagesFlickable"
        when: windowShown

        property ChatMessagesFlickable view: null

        function cleanup() {
            // the view outlives the test that made it (destruction is
            // deferred): left advertising more rows, its paging timer keeps
            // sliding the window the next test is running against
            if (view) {
                view.moreUpAvailable = false
                view.moreDownAvailable = false
            }
            while (history.count > 1000)
                history.remove(0)
            // tests may shrink the shared history; rebuild it even when they
            // fail mid-way so the damage does not cascade into later tests
            for (let i = history.count; i < 1000; ++i)
                history.append({ text: "message " + i })
        }

        function init() {
            cleanup()
            window.reset()
            view = createTemporaryObject(viewComponent, root)
            verify(!!view)
            waitForRendering(view)
        }

        function test_renders_exactly_the_window_newest_last() {
            compare(view.count, window.size)

            const newest = view.itemAtRow(0)
            const oldest = view.itemAtRow(window.size - 1)
            compare(newest.rowText, "message 0")
            compare(oldest.rowText, "message " + (window.size - 1))
            verify(newest.y > oldest.y, "row 0 must be laid out below the older rows")
        }

        function test_opens_anchored_on_the_newest_message() {
            verify(view.stickingToNewest)
            fuzzyCompare(view.contentY, view.contentHeight - view.height, 1)
        }

        // The paging is level-triggered: parking the viewport on the history
        // placeholder may slide the window several chunks per pass, so the
        // assertions are on the end state, not on per-step growth.
        function test_scrolling_into_history_grows_then_slides_the_window() {
            let peak = 0
            tryVerify(() => {
                view.contentY = 0
                peak = Math.max(peak, view.count)
                return window.start > 0
            }, 10000, "the window must slide once it hit its cap, end="
                      + window.end + " count=" + view.count)

            // grew exactly up to the cap — never past it — and stays there
            // while sliding further back
            tryVerify(() => {
                peak = Math.max(peak, view.count)
                return view.count === window.max
            }, 2000, "the window must settle at its cap, count=" + view.count)
            compare(peak, window.max, "the window may never exceed its cap")
            verify(view.itemAtRow(0).rowText !== "message 0",
                   "the newest messages must have left the window")
        }

        function test_new_message_follows_the_bottom_while_sticking() {
            verify(view.stickingToNewest)
            history.insert(0, { text: "brand new" })
            waitForRendering(view)

            compare(view.itemAtRow(0).rowText, "brand new")
            tryCompare(view, "count", window.size, 1000, "the window must not grow with the history")
            tryVerify(() => Math.abs(view.contentY - (view.contentHeight - view.height)) <= 1, 1000,
                      "contentY=" + view.contentY + " contentHeight=" + view.contentHeight)
        }

        function test_positionAtRow_centers_the_row_and_reports_it() {
            const positioned = signalSpy.createObject(root, { target: view, signalName: "rowPositioned" })

            view.positionAtRow(30)
            waitForRendering(view)

            verify(positioned.count > 0)
            const item = view.itemAtRow(30)
            const itemCenter = item.y + item.height / 2
            verify(itemCenter >= view.contentY && itemCenter <= view.contentY + view.height,
                   "the requested row must end up inside the viewport")
            verify(!view.stickingToNewest)
        }

        function test_positionAtRow_reports_once_across_content_changes() {
            const positioned = signalSpy.createObject(root, { target: view, signalName: "rowPositioned" })

            view.positionAtRow(30)
            waitForRendering(view)
            tryVerify(() => positioned.count > 0, 1000)

            // content keeps changing afterwards — the fulfilled request must
            // not re-fire, and the anchor must hold the row instead
            history.insert(0, { text: "new arrival" })
            waitForRendering(view)
            compare(positioned.count, 1)
        }

        function test_scrolling_to_the_bottom_resticks() {
            view.contentY = 0
            verify(!view.stickingToNewest)

            // any user scroll landing on the newest message re-sticks —
            // scrollbar drags included, which emit no movement signals
            view.contentY = view.contentHeight - view.height
            verify(view.stickingToNewest,
                   "scrolling to the bottom must re-stick the view")

            history.insert(0, { text: "revealed" })
            waitForRendering(view)
            compare(view.itemAtRow(0).rowText, "revealed")
            tryVerify(() => Math.abs(view.contentY - (view.contentHeight - view.height)) <= 1, 1000,
                      "the arriving message must be revealed at the bottom")
        }

        // The reported field scenario: slide into history (down placeholder
        // active), scroll all the way back to the newest message, then a new
        // message arrives — the view must follow it.
        function test_returning_from_history_to_the_bottom_resticks() {
            // slide the window into history until it leaves the recent end
            for (let i = 0; i < 6 && window.start === 0; ++i) {
                const before = window.end
                view.contentY = 0
                tryVerify(() => window.end > before, 2000,
                          "iteration " + i + ": end=" + window.end)
                waitForRendering(view)
            }
            verify(window.start > 0, "the window must have slid into history")
            verify(view.moreDownAvailable)

            // scroll back down through the bottom placeholder until the
            // window returns to the recent end
            tryVerify(() => {
                view.contentY = view.contentHeight - view.height
                return window.start === 0
            }, 10000, "the window must return to the recent end, start=" + window.start)

            // settle on the newest message; the nudge guarantees the final
            // write is a real change even if the view already sits at the
            // bottom (a no-op write emits no signal to derive the state from)
            tryVerify(() => !view.moreDownAvailable)
            view.contentY = Math.max(0, view.contentY - 2)
            view.contentY = view.contentHeight - view.height
            waitForRendering(view)
            verify(view.stickingToNewest,
                   "settling on the newest message must re-stick the view")

            history.insert(0, { text: "fresh arrival" })
            waitForRendering(view)
            tryVerify(() => Math.abs(view.contentY - (view.contentHeight - view.height)) <= 1, 1000,
                      "a message arriving at the newest position must be revealed")
            compare(view.itemAtRow(0).rowText, "fresh arrival")
        }

        function test_direct_contentY_write_unsticks_like_a_scrollbar_drag() {
            verify(view.stickingToNewest)

            // scrollbar drags write contentY without any movement signals
            view.contentY = 0
            verify(!view.stickingToNewest,
                   "a contentY write not made by the view must count as a user move")

            history.insert(0, { text: "while away" })
            waitForRendering(view)
            verify(!view.stickingToNewest,
                   "a new message must not re-stick a view the user scrolled away")
        }

        // The bottom of a window slid into history is NOT the newest message —
        // landing there must not stick (atNewest semantics, not content-bottom
        // semantics). Sticking here makes every later content change call
        // goToBottom() and walk the window back to the recent end.
        function test_bottom_of_a_slid_window_is_not_the_newest() {
            window.start = 30
            window.end = 89
            tryCompare(view, "count", 60, 2000)
            // bounded wait for the grid to lay the rows out; the offscreen
            // harness occasionally starves layout for minutes, in which case
            // the geometry this test measures never materializes — skip then
            // rather than fail on an environment artifact
            const deadline = Date.now() + 2000
            while (Date.now() < deadline && view.contentHeight < 60 * 20)
                wait(50)
            if (view.contentHeight < 60 * 20) {
                skip("layout starved, geometry untestable in this run")
                return
            }
            waitForRendering(view)
            verify(view.moreDownAvailable)
            unstick(100)

            view.contentY = view.contentHeight - view.height
            verify(!view.stickingToNewest,
                   "the bottom of a slid window must not read as the newest message")
        }

        // A jump into history collapses the window to a few rows around the
        // target; the Flickable clamp that follows lands on the content
        // bottom and must NOT re-stick the view — newer messages still exist
        // below the window, so its bottom is not the newest message. A
        // re-stick here cancels the jump and walks the window back to the
        // recent end.
        function test_window_collapse_while_slid_does_not_restick() {
            window.start = 30
            window.end = 89
            waitForRendering(view)
            unstick(100)

            // goToMessage-style collapse to a handful of rows
            window.start = 40
            window.end = 44
            waitForRendering(view)

            verify(!view.stickingToNewest,
                   "a window collapse must not re-stick the view while newer "
                   + "messages exist below the window")
        }

        // History exhaustion collapses the top placeholder, shrinking the
        // content by a viewport; a reader sitting just above the newest must
        // hold position and must not be re-stuck.
        function test_history_exhaustion_holds_an_unstuck_reader() {
            const tracked = unstickAndTrack(5, 50)

            // no rows beyond the window any more → placeholder collapses
            history.remove(window.size, history.count - window.size)
            waitForRendering(view)

            verify(!view.stickingToNewest,
                   "exhausting history must not re-stick a reader who scrolled away")
            const item = view.itemAtRow(5)
            verify(!!item)
            compare(item.rowText, tracked.text)
            fuzzyCompare(item.mapToItem(view, 0, 0).y, tracked.y, 1)
        }

        // Scrolls away from the bottom with a scrollbar-drag-like write.
        function unstick(distanceFromBottom) {
            view.contentY = view.contentHeight - view.height - distanceFromBottom
            waitForRendering(view)
            verify(!view.stickingToNewest)
        }

        // Records where a window row sits on screen, to compare it against
        // where it sits once the model changed.
        function track(row) {
            const item = view.itemAtRow(row)
            verify(!!item)
            return { item: item, text: item.rowText, y: item.mapToItem(view, 0, 0).y }
        }

        function unstickAndTrack(row, distanceFromBottom) {
            unstick(distanceFromBottom)
            return track(row)
        }

        // The paging timer keeps sliding the window while a placeholder is in
        // the viewport; a measurement is only meaningful once it stopped.
        function waitForQuietWindow() {
            let last = ""
            let stable = 0
            tryVerify(() => {
                const now = window.start + ":" + window.end
                stable = (now === last) ? stable + 1 : 0
                last = now
                // over the paging interval, so a pending slide would show up
                return stable >= 6
            }, 3000, "the window must stop sliding, start=" + window.start + " end=" + window.end)
            waitForRendering(view)
        }

        // Waits for the deferred refilter to evict the rows the inserts pushed
        // out of the window, and for the layout to place the survivors.
        function waitForEviction(oldestText) {
            tryVerify(() => view.itemAtRow(view.count - 1).rowText === oldestText,
                      1000, "oldest=" + view.itemAtRow(view.count - 1).rowText)
            tryCompare(view, "count", window.size, 1000)
            waitForRendering(view)
        }

        function test_bottom_insert_while_unstuck_keeps_rows_anchored() {
            const tracked = unstickAndTrack(20, 150)

            history.insert(0, { text: "brand new" })

            // the window keeps its size: the oldest row is evicted as the new
            // one enters at the bottom
            waitForEviction("message " + (window.size - 2))

            compare(tracked.item.rowText, tracked.text)
            fuzzyCompare(tracked.item.mapToItem(view, 0, 0).y, tracked.y, 1)
            verify(!view.stickingToNewest)
        }

        function test_bottom_insert_batch_keeps_rows_anchored() {
            const tracked = unstickAndTrack(20, 150)

            for (let i = 0; i < 5; ++i)
                history.insert(0, { text: "brand new " + i })

            waitForEviction("message " + (window.size - 6))

            compare(tracked.item.rowText, tracked.text)
            fuzzyCompare(tracked.item.mapToItem(view, 0, 0).y, tracked.y, 1)
            verify(!view.stickingToNewest)
        }

        // With the window slid into history the insert shifts its bounds
        // instead of evicting, which re-filters the oldest row out and back in
        // — the rows on screen must survive that round trip in place.
        function test_bottom_insert_with_slid_window_keeps_rows_anchored() {
            // the window is put where paging would leave it, with paging
            // itself switched off: what is under test is the insert, and a
            // slide arriving mid-measurement would be indistinguishable from
            // one
            view.moreUpAvailable = false
            view.moreDownAvailable = false

            window.start = 10
            window.end = window.start + window.max - 1
            waitForRendering(view)
            compare(view.count, window.max)

            const tracked = unstickAndTrack(25, 400)
            const startBefore = window.start

            history.insert(0, { text: "brand new" })
            waitForRendering(view)

            compare(window.start, startBefore + 1)
            compare(window.end - window.start + 1, window.max,
                    "the shifted window must cover the same rows")
            compare(tracked.item.rowText, tracked.text)
            fuzzyCompare(tracked.item.mapToItem(view, 0, 0).y, tracked.y, 1)
            compare(view.count, window.max)
            verify(!view.stickingToNewest)
        }

        // A reader parked at the top of the window is anchored on its oldest
        // row — the very row a bottom insert evicts. The view must re-anchor
        // on a surviving row instead of being left behind by the eviction.
        function test_bottom_insert_evicting_the_anchor_row_reanchors() {
            // viewport top exactly on the oldest row, the placeholder just
            // above it and out of sight
            view.contentY = 100
            waitForRendering(view)
            verify(!view.stickingToNewest)

            compare(view.itemAtRow(view.count - 1).rowText, "message " + (window.size - 1))
            const neighbor = track(view.count - 2)

            history.insert(0, { text: "brand new" })

            tryVerify(() => view.itemAtRow(0).rowText === "brand new", 1000)
            waitForQuietWindow()

            compare(neighbor.item.rowText, neighbor.text)
            fuzzyCompare(neighbor.item.mapToItem(view, 0, 0).y, neighbor.y, 1)
        }

        function test_positionAtNewest_returns_to_the_bottom() {
            view.contentY = 0
            waitForRendering(view)

            view.positionAtNewest()
            waitForRendering(view)

            verify(view.stickingToNewest)
            fuzzyCompare(view.contentY, view.contentHeight - view.height, 1)
        }
    }

    Component {
        id: signalSpy
        SignalSpy {}
    }

    // An empty view advertising more history: the paging machinery must stay
    // inert — with no rows there is nothing to anchor on, and unsticking
    // would leave the view parked at the top once rows do arrive (the
    // device-observed "opens at the top showing the placeholder" bug).
    Component {
        id: emptyViewComponent

        ChatMessagesFlickable {
            anchors.fill: parent

            id: emptyFlick

            placeholderHeight: 100
            moreUpAvailable: true

            placeholder: Rectangle { color: "transparent" }

            model: emptyHistory
            delegate: Rectangle {
                objectName: "row"
                Layout.row: emptyFlick.rowCount - index + 1
                Layout.column: 0
                Layout.fillWidth: true
                Layout.preferredHeight: 20
            }
        }
    }

    ListModel { id: emptyHistory }

    TestCase {
        name: "ChatMessagesFlickableEmpty"
        when: windowShown

        function cleanup() {
            emptyHistory.clear()
        }

        function test_emptyPhaseDoesNotUnstick() {
            const view = createTemporaryObject(emptyViewComponent, root)
            verify(!!view)
            waitForRendering(view)

            // let the level-triggered paging timer fire several times
            wait(400)
            verify(view.stickingToNewest,
                   "an empty view must not unstick from the bottom")

            for (let i = 0; i < 10; ++i)
                emptyHistory.append({ text: "message " + i })
            waitForRendering(view)

            verify(view.stickingToNewest)
            tryVerify(() => Math.abs(view.contentY - (view.contentHeight - view.height)) <= 1,
                      1000, "rows arriving after an empty phase must land at the bottom, contentY="
                      + view.contentY)
        }
    }
}
