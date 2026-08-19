import QtQuick
import QtTest

import StatusQ.Controls

/*
 StatusDeferredToolTip
 =====================
 Stands in for a StatusToolTip on controls that declare one per instance, so a
 wallet section full of buttons stops building a Popup subtree per button.

 What has to hold:
 - nothing is built until the tooltip is first asked to show
 - once built it carries the same text, parent, placement and timing a plain
   StatusToolTip would have had
 - overrides the owner did not set keep StatusToolTip's own defaults
*/
Item {
    id: root

    width: 400
    height: 400

    Component {
        id: plainComp

        Rectangle {
            width: 120
            height: 40
            color: "lightgray"

            readonly property alias tooltip: tooltip

            StatusDeferredToolTip {
                id: tooltip
                tooltipObjectName: "deferredTip"
                text: "Deferred tip"
            }
        }
    }

    Component {
        id: overriddenComp

        Rectangle {
            width: 120
            height: 40
            color: "lightgray"

            readonly property alias tooltip: tooltip

            StatusDeferredToolTip {
                id: tooltip
                tooltipObjectName: "deferredTip"
                text: "Deferred tip"
                orientation: StatusToolTip.Orientation.Bottom
                maxWidth: 220
                delay: 0
                y: 55
            }
        }
    }

    // What the deferred tooltip has to stay indistinguishable from.
    Component {
        id: referenceComp

        StatusToolTip {
            text: "Deferred tip"
        }
    }

    Component {
        id: buttonComp

        StatusFlatRoundButton {
            // Away from the corner the cursor is parked in between tests.
            x: 150
            y: 150
            width: 44
            height: 44
            icon.name: "info"
            tooltip.text: "Hovered tip"
        }
    }

    TestCase {
        name: "StatusDeferredToolTip"
        when: windowShown

        function cleanup() {
            mouseMove(root, 2, 2) // leave any hovered target
        }

        function test_notBuiltUntilShown() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            waitForRendering(target)

            verify(!target.tooltip.active, "the tooltip must start unbuilt")
            compare(target.tooltip.item, null, "no popup before the first show request")
            compare(target.tooltip.opened, false)
            compare(findChild(target, "deferredTip"), null)
        }

        function test_showRequestBuildsTheTooltip() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            waitForRendering(target)

            target.tooltip.visible = true

            verify(!!target.tooltip.item, "the show request must build the popup")
            compare(target.tooltip.item.text, "Deferred tip")
            compare(target.tooltip.item.parent, target,
                    "the popup is positioned against the declaring parent")
            compare(target.tooltip.item.objectName, "deferredTip")
        }

        // The popup is built at the instant it is asked to show, so the show
        // delay has to survive being applied to a brand new object.
        function test_showDelayIsPreserved() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            waitForRendering(target)

            target.tooltip.visible = true

            const tip = target.tooltip.item
            verify(!!tip)
            compare(tip.delay, 200, "the desktop show delay must be preserved")
            compare(tip.opened, false, "the tooltip must not open before its delay elapses")

            tryCompare(target.tooltip, "opened", true, 2000,
                       "the tooltip must open once the delay elapses")
        }

        // Anything the owner did not override keeps StatusToolTip's own value.
        function test_defaultsSurviveWhenNotOverridden() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            target.tooltip.visible = true

            const tip = target.tooltip.item
            const reference = createTemporaryObject(referenceComp, root, { parent: target })
            verify(!!reference)

            compare(tip.maxWidth, reference.maxWidth, "maxWidth default must be StatusToolTip's")
            compare(tip.delay, reference.delay)
            compare(tip.orientation, reference.orientation)
            compare(tip.y, reference.y, "an unset y must keep StatusToolTip's own placement")
        }

        function test_overridesAreForwarded() {
            const target = createTemporaryObject(overriddenComp, root)
            verify(!!target)
            target.tooltip.visible = true

            const tip = target.tooltip.item
            verify(!!tip)
            compare(tip.maxWidth, 220)
            compare(tip.delay, 0)
            compare(tip.orientation, StatusToolTip.Orientation.Bottom)
            compare(tip.y, 55, "an owner-set y must position the popup")
        }

        // What a StatusFlatRoundButton does: hover builds the tooltip and the
        // arrow keeps pointing at the button's centre.
        function test_hoverOnAButtonBuildsAndCentersTheTooltip() {
            const button = createTemporaryObject(buttonComp, root)
            verify(!!button)
            waitForRendering(button)

            compare(button.tooltip.item, null, "no popup before the first hover")

            mouseMove(button, button.width / 2, button.height / 2)

            tryVerify(() => !!button.tooltip.item, 2000, "hover must build the tooltip")
            const tip = button.tooltip.item
            compare(tip.text, "Hovered tip")
            tryCompare(button.tooltip, "opened", true, 2000)

            // The arrow must land on the button's centre even though the popup
            // itself is clamped to the window.
            const arrow = findChild(tip, "statusToolTipArrow")
            verify(!!arrow)
            fuzzyCompare(tip.x + arrow.x + arrow.width / 2, button.width / 2, 1.0,
                         "the arrow must point at the centre of the button")

            mouseMove(root, 2, 2)
            tryCompare(button.tooltip, "opened", false, 2000,
                       "the tooltip hides when the hover ends")
        }
    }
}
