pragma ComponentBehavior: Bound

import QtQuick

import SortFilterProxyModel
import QtModelsToolkit

/*
  A window over a large model, shaped for WindowedView's data contract.

  The view never sees the window: it renders `model`, learns from
  moreAvailableStart/End whether anything lies beyond it, and asks for more.
  This answers by moving the window's bounds.

  The two ends deliberately do not move together here. Growing admits rows the
  view stages and holds hidden; the opposite end is only trimmed when the view
  reveals them, which is what keeps the content height from changing twice. So
  `grow*` records what the far end owes and `trim()` collects it, and the view
  calls `trim()` from inside its reveal.

  `first` and `last` are therefore read-only: a direct write would leave the
  owed trim pointing at bounds that had moved underneath it, and the next
  trim() would silently shrink the window. Position changes go through
  moveTo(), which clears what is owed; the steady size is `size`.
*/
QObject {
    id: root

    property var sourceModel: null

    // The size the window returns to once a batch has been revealed. Writing it
    // while a trim is owed takes effect at the trim rather than immediately, so
    // a resize mid-batch is deferred, never lost and never half-applied.
    property int size: 60

    readonly property int first: d.first
    readonly property int last: d.last

    readonly property int sourceRowCount:
        root.sourceModel ? root.sourceModel.ModelCount.count : 0

    readonly property bool moreAvailableStart: d.first > 0
    readonly property bool moreAvailableEnd: d.last < root.sourceRowCount - 1

    // True between a grow and its trim: the window is transiently oversized.
    readonly property bool growing: d.owedStart > 0 || d.owedEnd > 0

    // What the view renders.
    readonly property var model: windowModel

    SortFilterProxyModel {
        id: windowModel

        sourceModel: root.sourceModel

        filters: IndexFilter {
            id: windowFilter

            minimumIndex: d.first
            maximumIndex: d.last
        }

        // IndexFilter judges a row by its position, and QSortFilterProxyModel
        // never re-tests a row it has already judged: an insertion renumbers
        // the rows after it, so accepted rows stay accepted past maximumIndex
        // and rejected rows never come back into range. The filter therefore
        // has to be re-run whenever the source changes shape.
        //
        // Wired from the proxy's own sourceModelChanged rather than from a
        // handler on the model, because the order matters: re-filtering from a
        // slot that runs before the proxy has processed the same change is at
        // best undone, and on a removal leaves empty rows behind.
        onSourceModelChanged: d.rewire()
    }

    // Grows the window at the start, remembering what the far end owes.
    // Returns how far it actually grew.
    function growStart(count) {
        const n = Math.min(count, d.first)

        if (n <= 0)
            return 0

        d.owedEnd += n
        d.first -= n
        return n
    }

    function growEnd(count) {
        const n = Math.min(count, root.sourceRowCount - 1 - d.last)

        if (n <= 0)
            return 0

        d.owedStart += n
        d.last += n
        return n
    }

    // Collects whatever the ends owe. Called from inside the view's reveal, so
    // the rows leaving and the rows appearing change the content in one frame.
    function trim() {
        if (d.owedStart > 0) {
            d.first += d.owedStart
            d.owedStart = 0
        }

        if (d.owedEnd > 0) {
            d.last -= d.owedEnd
            d.owedEnd = 0
        }

        // The invariant, restated rather than assumed: at rest the window is
        // exactly `size` rows. This is also what applies a resize that arrived
        // while the batch was in flight.
        d.last = d.first + Math.max(1, root.size) - 1
    }

    // Places the window to start at `first`, at the steady size, and forgets
    // anything owed - a deliberate jump, not a paged move.
    function moveTo(first) {
        d.owedStart = 0
        d.owedEnd = 0
        d.first = Math.max(0, first)
        d.last = d.first + Math.max(1, root.size) - 1
    }

    onSizeChanged: {
        // Mid-batch the bounds belong to the owed trim; trim() applies this.
        if (root.growing)
            return

        d.last = d.first + Math.max(1, root.size) - 1
    }

    QtObject {
        id: d

        property int first: 0
        property int last: 59

        // How many rows each end owes once the view has revealed the batch.
        property int owedStart: 0
        property int owedEnd: 0

        property var wiredModel: null

        function rewire() {
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
    }

    Component.onCompleted: {
        // Wired here as well as from the proxy's sourceModelChanged: that
        // signal does not reach us for the model the binding supplies at
        // construction, and without this the filter keeps its first verdicts
        // for good - an insertion above the window then shifts which rows it
        // shows without the window ever re-testing them. rewire() disconnects
        // before it connects, so calling it twice is harmless.
        d.rewire()
        root.moveTo(d.first)
    }
}
