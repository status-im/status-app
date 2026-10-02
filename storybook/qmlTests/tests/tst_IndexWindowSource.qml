import QtQuick
import QtTest

import StatusQ.Core.Utils

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: componentUnderTest

        IndexWindowSource {
            id: source

            size: 10

            sourceModel: ListModel {
                Component.onCompleted: {
                    const rows = []

                    for (let i = 0; i < 50; i++)
                        rows.push({ key: "k" + i, value: i })

                    append(rows)
                }
            }
        }
    }

    // A source with no model at all, to check it stays inert rather than
    // throwing or reporting rows it does not have.
    Component {
        id: emptyComponent

        IndexWindowSource {
            size: 10
        }
    }

    TestCase {
        name: "IndexWindowSource"

        // The values the window currently exposes, which is the only thing a
        // consumer sees.
        function values(source) {
            const out = []

            for (let i = 0; i < source.model.count; i++)
                out.push(source.model.get(i).value)

            return out
        }

        function test_initialWindow() {
            const source = createTemporaryObject(componentUnderTest, root)

            compare(source.first, 0)
            compare(source.last, 9)
            compare(source.model.count, 10)
            compare(values(source)[0], 0)
            compare(values(source)[9], 9)
            compare(source.sourceRowCount, 50)
            compare(source.growing, false)
        }

        function test_moreAvailableReflectsTheEnds() {
            const source = createTemporaryObject(componentUnderTest, root)

            compare(source.moreAvailableStart, false, "nothing before the first row")
            compare(source.moreAvailableEnd, true)

            source.moveTo(40)
            compare(source.moreAvailableStart, true)
            compare(source.moreAvailableEnd, false, "nothing after the last row")
        }

        // Growing admits rows without giving anything up: the consumer stages
        // them while the far end still shows what it showed before.
        function test_growEndDefersTheTrim() {
            const source = createTemporaryObject(componentUnderTest, root)

            compare(source.growEnd(4), 4, "reports how far it grew")
            compare(source.model.count, 14, "transiently oversized")
            compare(source.first, 0, "the far end has not moved")
            compare(source.growing, true)
            compare(values(source)[13], 13)

            source.trim()
            compare(source.model.count, 10)
            compare(source.first, 4)
            compare(source.last, 13)
            compare(source.growing, false)
            compare(values(source)[0], 4)
        }

        function test_growStartDefersTheTrim() {
            const source = createTemporaryObject(componentUnderTest, root)

            source.moveTo(20)
            compare(source.growStart(4), 4)
            compare(source.model.count, 14)
            compare(source.last, 29, "the far end has not moved")
            compare(values(source)[0], 16)

            source.trim()
            compare(source.model.count, 10)
            compare(source.first, 16)
            compare(source.last, 25)
        }

        function test_growClampsToWhatIsLeft() {
            const source = createTemporaryObject(componentUnderTest, root)

            compare(source.growStart(5), 0, "nothing before the start")
            compare(source.growing, false, "a refused grow owes nothing")

            // A window may overhang the end of the model rather than being
            // clamped back: it simply shows fewer rows, and fills up again if
            // the model grows into it.
            source.moveTo(46)
            compare(source.last, 55, "the bounds are not clamped")
            compare(source.model.count, 4, "but only what exists is shown")
            compare(source.growEnd(5), 0, "nothing after the end")

            source.moveTo(0)
            compare(source.growEnd(1000), 40, "grows only as far as the model goes")
        }

        // The size a consumer asks for while a batch is in flight belongs to
        // the window it will settle at, not to the oversized one.
        function test_resizeWhileGrowingIsDeferredToTheTrim() {
            const source = createTemporaryObject(componentUnderTest, root)

            compare(source.growEnd(4), 4)
            const lastWhileGrowing = source.last

            source.size = 6
            compare(source.last, lastWhileGrowing, "not applied mid-batch")
            compare(source.model.count, 14)

            source.trim()
            compare(source.first, 4, "the owed trim landed")
            compare(source.last, 9, "and the deferred resize with it")
            compare(source.model.count, 6)
        }

        function test_resizeAtRestAppliesImmediately() {
            const source = createTemporaryObject(componentUnderTest, root)

            source.size = 20
            compare(source.first, 0)
            compare(source.last, 19)
            compare(source.model.count, 20)

            source.size = 5
            compare(source.model.count, 5)
        }

        function test_moveToForgetsWhatIsOwed() {
            const source = createTemporaryObject(componentUnderTest, root)

            compare(source.growEnd(4), 4)
            compare(source.growing, true)

            source.moveTo(30)
            compare(source.growing, false, "a jump is not a paged move")
            compare(source.first, 30)
            compare(source.last, 39)

            // the forgotten trim must not surface later
            source.trim()
            compare(source.first, 30)
            compare(source.last, 39)
            compare(source.model.count, 10)
        }

        // IndexFilter judges a row by its position and QSortFilterProxyModel
        // never re-tests a row it has already judged, so without the source's
        // re-filtering an insertion would leave the window permanently
        // oversized and a removal permanently short.
        function test_windowKeepsItsSizeAcrossSourceInsertions() {
            const source = createTemporaryObject(componentUnderTest, root)

            source.moveTo(10)
            compare(source.model.count, 10)

            compare(values(source)[0], 10)

            source.sourceModel.insert(0, [{ key: "new0", value: -1 },
                                          { key: "new1", value: -2 }])
            compare(source.model.count, 10, "still exactly the window size")

            source.sourceModel.insert(12, [{ key: "mid", value: -3 }])
            compare(source.model.count, 10)

            // The window is defined by index, so rows inserted before it shift
            // which rows it shows. Pinning it to the same rows is the
            // consumer's business, not this component's - but the size is this
            // component's, and re-filtering is what keeps it.
            compare(source.first, 10, "the bounds themselves do not move")
            // two of the three inserts landed before the window, one inside it
            compare(values(source)[0], 8, "but the rows behind them did")
        }

        function test_windowKeepsItsSizeAcrossSourceRemovals() {
            const source = createTemporaryObject(componentUnderTest, root)

            source.moveTo(10)
            source.sourceModel.remove(0, 3)
            compare(source.model.count, 10, "refilled from the rows that shifted in")

            // near the end there is simply less to show
            source.moveTo(40)
            compare(source.model.count, 7, "47 rows left, window starts at 40")
        }

        function test_withoutASourceModelItStaysInert() {
            const source = createTemporaryObject(emptyComponent, root)

            compare(source.sourceRowCount, 0)
            compare(source.moreAvailableStart, false)
            compare(source.moreAvailableEnd, false)
            compare(source.growStart(5), 0)
            compare(source.growEnd(5), 0)
            compare(source.growing, false)
        }
    }
}
