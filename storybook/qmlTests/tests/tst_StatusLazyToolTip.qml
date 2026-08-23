import QtQuick
import QtQuick.Layouts
import QtTest

import StatusQ.Controls

/*
 StatusLazyToolTip
 =================
 Stands in for a StatusToolTip on anything created in bulk - every
 StatusBaseButton, StatusListItem or message row - so none of them builds a
 Popup subtree for a hover that may never happen.

 What has to hold:
 - nothing is built, and no text is produced, until the tooltip is first shown
 - once built it carries the same text, parent, placement and timing a plain
   StatusToolTip would have had
 - overrides the owner did not set keep StatusToolTip's own defaults
 - it never takes up room in the positioner or layout it was declared in
*/
Item {
    id: root

    width: 400
    height: 400

    property int providerCalls: 0

    Component {
        id: plainComp

        Rectangle {
            width: 120
            height: 40
            color: "lightgray"

            readonly property alias tooltip: tooltip

            StatusLazyToolTip {
                id: tooltip
                tooltipObjectName: "lazyTip"
                text: "Lazy tip"
            }
        }
    }

    Component {
        id: providedComp

        Rectangle {
            width: 120
            height: 40
            color: "lightgray"

            property string provided: "provided text"
            readonly property alias tooltip: tooltip

            StatusLazyToolTip {
                id: tooltip
                tooltipObjectName: "lazyTip"
                textProvider: () => {
                    root.providerCalls++
                    return parent.provided
                }
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

            StatusLazyToolTip {
                id: tooltip
                tooltipObjectName: "lazyTip"
                text: "Lazy tip"
                orientation: StatusToolTip.Orientation.Bottom
                maxWidth: 220
                delay: 0
                y: 55
            }
        }
    }

    // What the lazy tooltip has to stay indistinguishable from.
    Component {
        id: referenceComp

        StatusToolTip {
            text: "Lazy tip"
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

    // A StatusToolTip is a Popup and draws nothing here, so the placeholder
    // must not shift its siblings - not even while the tooltip is up.
    Component {
        id: layoutComp

        RowLayout {
            spacing: 10

            readonly property alias tooltip: tooltip
            readonly property alias trailing: trailing

            Rectangle { Layout.preferredWidth: 30; Layout.preferredHeight: 20 }

            StatusLazyToolTip {
                id: tooltip
                text: "Lazy tip"
                delay: 0
            }

            Rectangle {
                id: trailing
                Layout.preferredWidth: 30
                Layout.preferredHeight: 20
            }
        }
    }

    TestCase {
        name: "StatusLazyToolTip"
        when: windowShown

        function init() {
            root.providerCalls = 0
        }

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
            compare(findChild(target, "lazyTip"), null)
        }

        function test_showRequestBuildsTheTooltip() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            waitForRendering(target)

            target.tooltip.shown = true

            verify(!!target.tooltip.item, "the show request must build the popup")
            compare(target.tooltip.item.text, "Lazy tip")
            compare(target.tooltip.item.parent, target,
                    "the popup is positioned against the declaring parent")
            compare(target.tooltip.item.objectName, "lazyTip")
        }

        // The popup is built at the instant it is asked to show, so the show
        // delay has to survive being applied to a brand new object.
        function test_showDelayIsPreserved() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            waitForRendering(target)

            target.tooltip.shown = true

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
            target.tooltip.shown = true

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
            target.tooltip.shown = true

            const tip = target.tooltip.item
            verify(!!tip)
            compare(tip.maxWidth, 220)
            compare(tip.delay, 0)
            compare(tip.orientation, StatusToolTip.Orientation.Bottom)
            compare(tip.y, 55, "an owner-set y must position the popup")
        }

        // What a message row does: the text costs nothing until it is needed,
        // and is produced afresh every time, so it can't go stale.
        function test_textProviderRunsOnEveryShowAndNotBefore() {
            const target = createTemporaryObject(providedComp, root)
            verify(!!target)
            waitForRendering(target)

            compare(root.providerCalls, 0, "textProvider must not run at creation")

            target.tooltip.shown = true
            compare(root.providerCalls, 1, "the text is pulled when the tooltip is shown")
            compare(target.tooltip.item.text, "provided text")

            target.tooltip.shown = false
            target.provided = "second text"
            target.tooltip.shown = true

            compare(root.providerCalls, 2, "the text is pulled again on the next show")
            compare(target.tooltip.item.text, "second text")
        }

        function test_emptyTextKeepsThePopupHidden() {
            const target = createTemporaryObject(providedComp, root)
            verify(!!target)
            target.provided = ""

            target.tooltip.shown = true

            verify(!!target.tooltip.item, "the popup is still built")
            compare(target.tooltip.opened, false)
            wait(300) // past StatusToolTip's show delay
            compare(target.tooltip.opened, false, "an empty text must never open the tooltip")
        }

        function test_takesNoRoomInALayout() {
            const target = createTemporaryObject(layoutComp, root)
            verify(!!target)
            waitForRendering(target)

            const restingX = target.trailing.x

            target.tooltip.shown = true
            tryCompare(target.tooltip, "opened", true, 2000)
            waitForRendering(target)

            compare(target.trailing.x, restingX,
                    "showing the tooltip must not shift its siblings")
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
