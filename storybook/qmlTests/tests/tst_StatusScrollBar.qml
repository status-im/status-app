import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Core
import StatusQ.Controls

Item {
    id: root
    width: 400
    height: 400

    // A StatusScrollView whose content does NOT overflow: no scrollbar is needed.
    Component {
        id: nonOverflowingScrollView
        StatusScrollView {
            width: 200
            height: 200
            padding: 0
            contentWidth: 100
            contentHeight: 100

            Rectangle {
                implicitWidth: 100
                implicitHeight: 100
                color: "transparent"
            }
        }
    }

    // A StatusListView whose content overflows vertically: the vertical scrollbar
    // is needed. Its thumb should appear only once the bar becomes active.
    Component {
        id: overflowingListView
        StatusListView {
            width: 200
            height: 200
            model: 50
            delegate: Item {
                width: 200
                height: 40
            }
        }
    }

    TestCase {
        name: "StatusScrollBar"
        when: windowShown

        // --- Cycle 1: laziness seam (b) ---
        // The scrollbar thumb (visual content) must not be materialized while the
        // content fits and nobody has interacted with the scrollbar.
        function test_thumb_absent_when_content_fits_and_idle() {
            const view = createTemporaryObject(nonOverflowingScrollView, root)
            verify(!!view)

            // Let layout settle so scrollbar geometry/policy are resolved.
            tryCompare(view.ScrollBar.vertical, "visible", false,
                       1000, "vertical scrollbar should not be visible for non-overflowing content")
            tryCompare(view.ScrollBar.horizontal, "visible", false,
                       1000, "horizontal scrollbar should not be visible for non-overflowing content")

            verify(!findChild(view.ScrollBar.vertical, "scrollBarThumb"),
                   "vertical thumb should not be materialized at instantiation")
            verify(!findChild(view.ScrollBar.horizontal, "scrollBarThumb"),
                   "horizontal thumb should not be materialized at instantiation")
        }

        // --- Cycle 2: materialize + become opaque once the bar is active ---
        function test_thumb_materializes_and_shows_when_active() {
            const view = createTemporaryObject(overflowingListView, root)
            verify(!!view)

            const bar = view.verticalScrollBar
            tryCompare(bar, "visible", true, 1000,
                       "vertical scrollbar should be visible for overflowing content")

            // Idle: thumb still not materialized.
            verify(!findChild(bar, "scrollBarThumb"),
                   "thumb should stay lazy while the bar is idle")

            // User starts scrolling -> bar becomes active.
            bar.active = true

            tryVerify(() => !!findChild(bar, "scrollBarThumb"), 1000,
                      "thumb should materialize once the bar is active")
            const thumb = findChild(bar, "scrollBarThumb")
            tryCompare(thumb, "opacity", 1.0, 1000,
                       "thumb should be fully opaque while the bar is active")
        }

        // --- Cycle 3: preserve the transient fade-out ---
        // After the bar goes idle again the thumb must stay alive so its opacity
        // can animate back to 0 (fade-out), matching the released UX.
        function test_thumb_fades_out_and_persists_when_bar_goes_idle() {
            const view = createTemporaryObject(overflowingListView, root)
            verify(!!view)

            const bar = view.verticalScrollBar
            tryCompare(bar, "visible", true, 1000)

            bar.active = true
            tryVerify(() => !!findChild(bar, "scrollBarThumb"), 1000)

            bar.active = false

            // Thumb must remain instantiated to play the fade-out animation...
            verify(!!findChild(bar, "scrollBarThumb"),
                   "thumb should persist after the bar goes idle so it can fade out")
            // ...and settle to fully transparent.
            tryCompare(findChild(bar, "scrollBarThumb"), "opacity", 0.0, 1000,
                       "thumb should fade out to transparent when the bar goes idle")
        }
    }
}
