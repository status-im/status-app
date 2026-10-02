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

  The window is defined by the rows it holds, not by arithmetic against a
  moving count. A change made to the source from outside never changes which
  rows the window shows - the bounds move with them - except at the end the
  view is actively following, where the window keeps its end on the source's
  end so a row arriving there is shown rather than announced.
*/
QObject {
    id: root

    property var sourceModel: null

    // Keep the window's end on the source's end, so a row arriving there lands
    // inside the window and is simply shown, instead of falling beyond it and
    // being announced by a placeholder. Set from the view's own at-end state:
    // following while the user is reading older rows would slide content out
    // from under them.
    property bool followsEnd: false

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

    // Nothing here changes what the source holds - it reacts to someone else
    // changing it. The window is positional, so rows inserted before it
    // renumber its contents, and rows appended past it put the newest row out
    // of reach behind a placeholder.
    Connections {
        target: root.sourceModel

        // Asked before the insert lands, while the counts still describe the
        // world the window was placed in.
        function onRowsAboutToBeInserted(parent, first, last) {
            d.wasAtSourceEnd = d.last >= root.sourceRowCount - 1

            // Whether the window was over anything at all. Filling an empty
            // model is not a change to rows the window was showing - there were
            // none - and treating it as one walks the window off its position
            // by the size of the population.
            d.wasOverRows = root.sourceRowCount > d.first
        }

        function onRowsInserted(parent, first, last) {
            // Mid-batch the bounds belong to the owed trim, and re-pinning them
            // would leave it pointing at bounds that had moved. The next insert
            // picks this up.
            if (!d.wasOverRows)
                return

            const inserted = last - first + 1

            // The window covered the source's last row, so it still should:
            // whatever was inserted, the last index moved by exactly this much.
            // Counted from the signal rather than read back from the model -
            // sourceRowCount follows ModelCount, which has not necessarily
            // caught up by the time this runs.
            //
            // Both bounds move, so the window slides rather than grows and the
            // size is kept. Doing it for any insert at or before the end, not
            // just an append, is what covers a row landing *inside* the window:
            // that pushes the newest one out past `last` just the same.
            if (root.followsEnd && d.wasAtSourceEnd && !root.growing) {
                d.first += inserted
                d.last += inserted
                return
            }

            if (first <= d.first) {
                d.first += inserted
                d.last += inserted
            }
        }

        // The mirror. Nothing is done about the window hanging past a source
        // that just got shorter: overhanging the end is allowed by design, and
        // the filter simply yields the rows that are left.
        function onRowsRemoved(parent, first, last) {
            const removedBefore = Math.min(last, d.first - 1) - first + 1

            if (removedBefore <= 0)
                return

            d.first -= removedBefore
            d.last -= removedBefore
        }
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

        // Sampled before an insert moves the count: whether the window covered
        // the source's last row, and whether it was over any rows at all.
        property bool wasAtSourceEnd: false
        property bool wasOverRows: false

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
