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
    }
}
