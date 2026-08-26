import QtQuick
import QtTest

import StatusQ.Core
import StatusQ.Components

// A mouse text-selection drag inside a scrollable list (the chat's `StatusListView`) must
// extend the selection without the list scrolling underneath: a `Flickable` starts dragging
// at its own drag threshold and jumps the content before a pointer handler in the delegate
// can take the grab, which used to make selecting multiple lines nearly impossible.
Item {
    id: root
    width: 600
    height: 500

    Component {
        id: componentUnderTest

        StatusListView {
            id: listView

            width: 400
            height: 300

            // Mirrors the chat message list.
            verticalLayoutDirection: ListView.BottomToTop

            property var views: ({})

            model: 20

            delegate: Item {
                width: listView.width
                implicitHeight: textView.implicitHeight + 10

                ChatTextView {
                    id: textView

                    width: parent.width
                    selectable: true
                    font.pixelSize: 15
                    blocks: [
                        { type: "text", html: "Msg " + index + " line one here" },
                        { type: "text", html: "Msg " + index + " line two here" },
                        { type: "text", html: "Msg " + index + " line three here" }
                    ]

                    Component.onCompleted: listView.views[index] = textView
                }
            }
        }
    }

    TestCase {
        name: "ChatTextViewListSelection"
        when: windowShown

        // Drives a drag as a sequence of moves, synchronising on rendering instead of
        // sleeping for a fixed amount of time.
        function dragBy(listView, fromX, fromY, toX, toY, step) {
            mousePress(listView, fromX, fromY)
            const dx = (toX - fromX) / step
            const dy = (toY - fromY) / step
            for (let i = 1; i <= step; ++i) {
                mouseMove(listView, fromX + dx * i, fromY + dy * i)
                waitForRendering(listView)
            }
        }

        function selectedTexts(listView) {
            return Object.keys(listView.views)
                         .map(key => listView.views[key] ? listView.views[key].selectedText : "")
                         .filter(text => !!text)
        }

        function test_selectionDragDoesNotScrollTheList() {
            const listView = createTemporaryObject(componentUnderTest, root)
            verify(listView)
            tryVerify(() => !!listView.views[0] && listView.views[0].implicitHeight > 0)
            // Let the list settle at its initial position before sampling it.
            tryVerify(() => !listView.moving)
            waitForRendering(listView)

            const contentYBefore = listView.contentY

            dragBy(listView, 5, 5, 65, 60, 11)

            compare(listView.contentY, contentYBefore,
                    "the list must not scroll while a selection drag is in progress")

            const selected = selectedTexts(listView)
            compare(selected.length, 1, "exactly one message should hold the selection")
            verify(selected[0].length > 0, "the drag should have selected text")

            mouseRelease(listView, 65, 60)
        }

        // Suspending the list while selecting must not leave it permanently unscrollable.
        function test_listStaysScrollableAfterSelectionDrag() {
            const listView = createTemporaryObject(componentUnderTest, root)
            verify(listView)
            tryVerify(() => !!listView.views[0] && listView.views[0].implicitHeight > 0)
            tryVerify(() => !listView.moving)
            waitForRendering(listView)

            dragBy(listView, 5, 5, 65, 60, 11)
            mouseRelease(listView, 65, 60)

            tryVerify(() => listView.interactive,
                      5000, "the list must be interactive again after the drag")

            const contentYBefore = listView.contentY
            dragBy(listView, listView.width - 10, 20, listView.width - 10, 120, 10)
            mouseRelease(listView, listView.width - 10, 120)

            tryVerify(() => listView.contentY !== contentYBefore,
                      5000, "the list should scroll again")
        }
    }
}
