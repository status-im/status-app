import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Core
import StatusQ.Controls

Item {
    id: root
    width: 400
    height: 400

    // A bare StatusToolTip, parented to an anchor rectangle so it can be shown.
    Component {
        id: toolTipComponent
        StatusToolTip {
            text: "Hello tooltip"
        }
    }

    Rectangle {
        id: anchorItem
        width: 80
        height: 30
    }

    // A control (StatusButton) that declares a tooltip through StatusBaseButton:
    // creating the button must NOT build the tooltip's visual subtree.
    Component {
        id: buttonComponent
        StatusButton {
            text: "Btn"
            tooltip.text: "Btn tip"
        }
    }

    TestCase {
        name: "StatusToolTip"
        when: windowShown

        // --- Cycle 1: laziness seam ---
        // A freshly created tooltip that has never been shown must not materialize
        // its expensive positioning/content subtree (arrow x/y bindings + text).
        function test_content_absent_until_shown() {
            const tip = createTemporaryObject(toolTipComponent, root,
                                              { parent: anchorItem })
            verify(!!tip)
            verify(!tip.visible, "tooltip should start hidden")

            verify(!findChild(tip, "statusToolTipText"),
                   "text content must not be materialized before the tooltip is shown")
            verify(!findChild(tip, "statusToolTipArrow"),
                   "arrow must not be materialized before the tooltip is shown")
        }

        // A control that merely declares a tooltip (StatusButton) must not pay for
        // the tooltip subtree at creation time either.
        function test_control_with_tooltip_has_no_eager_tooltip_subtree() {
            const button = createTemporaryObject(buttonComponent, root)
            verify(!!button)

            verify(!findChild(button, "statusToolTipText"),
                   "declaring a tooltip on a button must not build its text at creation")
            verify(!findChild(button, "statusToolTipArrow"),
                   "declaring a tooltip on a button must not build its arrow at creation")
        }

        // --- Cycle 2: materialize with correct text + position once shown ---
        function test_content_materializes_on_show() {
            const tip = createTemporaryObject(toolTipComponent, root,
                                              { parent: anchorItem })
            verify(!!tip)

            tip.visible = true

            tryVerify(() => !!findChild(tip, "statusToolTipText"), 1000,
                      "text content must materialize once the tooltip is shown")
            const label = findChild(tip, "statusToolTipText")
            compare(label.text, "Hello tooltip", "shown tooltip must carry the correct text")

            const arrow = findChild(tip, "statusToolTipArrow")
            verify(!!arrow, "arrow must materialize once the tooltip is shown")

            // Top orientation (default): the arrow is horizontally centered on the
            // background (offset defaults to 0). Proves the deferred x binding is live.
            const bg = tip.background
            fuzzyCompare(arrow.x, bg.width / 2 - arrow.width / 2, 1.0,
                         "arrow must be centered for the default Top orientation")
        }

        // --- Cycle 3: hide on unshow, timing config preserved ---
        function test_hides_and_preserves_timing() {
            const tip = createTemporaryObject(toolTipComponent, root,
                                              { parent: anchorItem })
            verify(!!tip)

            // Deferral must not alter the show/hide timing contract.
            compare(tip.delay, 200, "desktop show delay must be preserved")
            compare(tip.timeout, -1, "desktop timeout must be preserved")

            tip.visible = true
            tryVerify(() => !!findChild(tip, "statusToolTipText"), 1000)

            tip.visible = false
            tryCompare(tip, "visible", false, 1000,
                       "tooltip must hide when unshown")
        }
    }
}
