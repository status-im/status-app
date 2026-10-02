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
        // The window is positional, so rows inserted before it renumber its
        // contents. Moving the bounds with them is what keeps it on the same
        // rows - and is this component's job, since it is the only thing that
        // knows what the indices mean.
        function test_insertsBeforeTheWindowKeepItOnTheSameRows() {
            const source = createTemporaryObject(componentUnderTest, root)

            source.moveTo(10)
            compare(values(source)[0], 10)

            source.sourceModel.insert(0, [{ key: "new0", value: -1 },
                                          { key: "new1", value: -2 }])

            compare(source.first, 12, "the bounds moved with the rows")
            compare(source.last, 21)
            compare(source.model.count, 10, "still exactly the window size")
            compare(values(source)[0], 10, "and it shows what it showed before")
        }

        function test_removalsBeforeTheWindowKeepItOnTheSameRows() {
            const source = createTemporaryObject(componentUnderTest, root)

            source.moveTo(10)
            source.sourceModel.remove(0, 3)

            compare(source.first, 7, "the bounds moved with the rows")
            compare(source.model.count, 10, "still exactly the window size")
            compare(values(source)[0], 10, "and it shows what it showed before")
        }

        // Not following: a row past the end is something to announce, which is
        // what moreAvailableEnd is for.
        function test_insertsAfterTheWindowAreAnnounced() {
            const source = createTemporaryObject(componentUnderTest, root)

            source.moveTo(40)       // 50 rows, so the window ends at the source
            compare(source.moreAvailableEnd, false)

            source.sourceModel.append([{ key: "newest", value: 999 }])

            compare(source.moreAvailableEnd, true, "there is now more beyond it")
            compare(source.first, 40, "and the window did not move")
            compare(values(source).indexOf(999), -1, "the new row is outside it")
        }

        // Following: the same insert lands inside the window instead, so the
        // view shows it rather than putting a placeholder where it should be.
        function test_followingTheEndAbsorbsANewLastRow() {
            const source = createTemporaryObject(componentUnderTest, root)

            source.moveTo(40)
            source.followsEnd = true

            source.sourceModel.append([{ key: "newest", value: 999 }])

            compare(source.moreAvailableEnd, false, "nothing is beyond it")
            compare(source.model.count, 10, "and it kept its size")
            compare(source.first, 41, "by sliding, not growing")
            compare(values(source)[9], 999, "the new row is the last one shown")
        }

        // An insert anywhere at or before the end pushes the newest row out past
        // the window just as an append does, so following has to cover it too.
        function test_followingTheEndAbsorbsAnInsertInsideTheWindow() {
            const source = createTemporaryObject(componentUnderTest, root)

            source.moveTo(40)
            source.followsEnd = true

            source.sourceModel.insert(45, [{ key: "mid", value: 888 }])

            compare(source.moreAvailableEnd, false, "nothing is beyond it")
            compare(source.model.count, 10)
            compare(source.first, 41)
            compare(values(source).indexOf(888) !== -1, true, "and it is shown")
        }

        // Mid-batch the bounds belong to the owed trim; re-pinning them would
        // leave it pointing at bounds that had moved underneath it.
        function test_followingIsSkippedWhileABatchIsInFlight() {
            const source = createTemporaryObject(componentUnderTest, root)

            // At the source end, so following would otherwise fire, and growing
            // at the same time.
            source.moveTo(40)
            source.followsEnd = true
            source.growStart(4)
            compare(source.growing, true)
            compare(source.first, 36)
            compare(source.last, 49)

            source.sourceModel.append([{ key: "newest", value: 999 }])

            compare(source.first, 36, "the grow is untouched")
            compare(source.last, 49)

            // growStart moved the window toward the start; the trim collects
            // the four it owes from the far end, leaving it where the grow put
            // it and exactly `size` rows long.
            source.trim()
            compare(source.first, 36, "and the owed trim still lands")
            compare(source.last, 45)
            compare(source.model.count, 10)
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
