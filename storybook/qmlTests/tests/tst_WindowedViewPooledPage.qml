import QtQuick
import QtTest

/*
  The page's own wiring of the C++ row source, which the component suite cannot
  see: WindowedView is given a provider that only ever hands out items the pool
  has already built, so the page is responsible for the pool being able to
  cover the window. It was not, and a target left below the window size by the
  panel stranded the rows: the pool stopped at its target, the boost cleared
  itself for want of anything to build, and the view revealed what had arrived
  and held the rest - a skeleton vanishing into an empty view.
*/
Item {
    id: root

    width: 1000
    height: 700

    Loader {
        id: loader

        anchors.fill: parent
        source: Qt.resolvedUrl("../../pages/WindowedViewPage.qml")
    }

    TestCase {
        name: "WindowedViewPage.PooledSource"
        when: windowShown

        function findWhere(obj, test) {
            if (!obj)
                return null

            if (test(obj))
                return obj

            const kids = obj.children

            for (let i = 0; kids && i < kids.length; ++i) {
                const found = findWhere(kids[i], test)

                if (found)
                    return found
            }

            return null
        }

        function labelled(page, text) {
            return findWhere(page, o => o.text === text)
        }

        function startsWith(page, prefix) {
            return findWhere(page, o => typeof o.text === "string"
                                       && o.text.indexOf(prefix) === 0)
        }

        function viewOf(page) {
            return findWhere(page, o => o.verticalLayoutDirection !== undefined
                                       && o.moreAvailableTop !== undefined)
        }

        function spinBoxBesideLabel(page, text) {
            const label = labelled(page, text)
            const siblings = label ? label.parent.children : []

            for (let i = 0; i < siblings.length; ++i)
                if (siblings[i].stepSize !== undefined)
                    return siblings[i]

            return null
        }

        function dressedRows(view) {
            let dressed = 0

            for (let row = 0; row < view.rowCount; ++row) {
                const shell = view.itemAtRow(row)

                if (shell && shell.content)
                    ++dressed
            }

            return dressed
        }

        function test_aWindowBiggerThanThePanelAsksForIsStillFilled() {
            tryVerify(() => loader.status === Loader.Ready, 20000, "page loaded")

            const page = loader.item
            const view = viewOf(page)

            verify(view, "found the view")
            tryVerify(() => !view.busy && view.rowCount > 0, 30000, "filled")

            // The panel asks for far less than the window needs, which is the
            // state a stored setting can leave the page in.
            const target = spinBoxBesideLabel(page, "Target")

            verify(target, "found the pool target control")
            target.value = 10
            target.valueModified()

            // Over to the pool, which now has to cover sixty rows from a
            // target of ten.
            const source = findWhere(page, o => o.currentText !== undefined
                                               && o.count === 2
                                               && o.currentText.indexOf("Pool") > 0)

            verify(source, "found the row-source control")
            source.currentIndex = 1

            tryVerify(() => !view.busy && view.rowCount > 0
                            && dressedRows(view) === view.rowCount, 30000,
                      "every row of the window is dressed from the pool")

            // And now a window far larger than anything the pool was ever told
            // to hold - the state a stored target leaves the page in, reached
            // from the other side. Without a target that follows the window,
            // the rows beyond it wait for an item that is never built.
            const size = spinBoxBesideLabel(page, "Size")

            verify(size, "found the window size control")
            size.value = 200
            size.valueModified()

            tryVerify(() => !view.busy && view.rowCount === 200
                            && dressedRows(view) === view.rowCount, 60000,
                      "the bigger window is dressed too")

            // Dressed is not drawn: the pool hands back an item still
            // parented to its own container, so whoever dresses it has to put
            // it in the shell. Without that the rows have content, the right
            // heights and nothing on screen.
            for (let row = 0; row < view.rowCount; ++row) {
                const shell = view.itemAtRow(row)

                compare(shell.content.parent, shell,
                        "row " + row + "'s item sits in its shell")
            }

            const first = view.itemAtRow(0)

            verify(first.content.width > 0 && first.content.height > 0,
                   "and has a size: " + Math.round(first.content.width) + "x"
                   + Math.round(first.content.height))
            verify(first.content.visible, "and is visible")

            // and the pool says what it is really aiming for
            const readout = startsWith(page, "ready ")

            verify(readout, "found the pool readout")
            console.log("PROBE", readout.text, "| rows", view.rowCount,
                        "| dressed", dressedRows(view))

            const aimedAt = parseInt(readout.text.split(" of ")[1])

            verify(aimedAt >= view.rowCount,
                   "and the target follows the window: " + aimedAt + " for "
                   + view.rowCount + " rows")
        }
    }
}
