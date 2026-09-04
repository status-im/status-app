import QtQuick
import QtTest

import StatusQ.Controls

/*
 StatusLazyToolTip
 =================
 Stands in for a StatusToolTip on anything created in bulk - every
 StatusBaseButton, StatusListItem or message row - so none of them builds a
 Popup subtree for a hover that may never happen.

 What has to hold:
 - nothing is built, and no text is produced, until the target is first hovered
 - a touch never builds one; a tooltip is a pointer affordance
 - `enabled` is the owner's say, and an owner that is disabled itself has none
 - `visible` reports whether the tooltip is up
 - once built it carries the same text, parent, placement and timing a plain
   StatusToolTip would have had
 - overrides the owner did not set keep StatusToolTip's own defaults
 - it never takes up room in the positioner it was declared in
*/
Item {
    id: root

    width: 400
    height: 400

    property int providerCalls: 0

    // Away from the corner the cursor is parked in between tests.
    Component {
        id: plainComp

        Rectangle {
            x: 150
            y: 150
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
            x: 150
            y: 150
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
            x: 150
            y: 150
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

    // The owner withholding its say, and the owner having none to give.
    Component {
        id: gatedComp

        Rectangle {
            x: 150
            y: 150
            width: 120
            height: 40
            color: "lightgray"

            property alias tooltipEnabled: tooltip.enabled
            readonly property alias tooltip: tooltip

            StatusLazyToolTip {
                id: tooltip
                tooltipObjectName: "lazyTip"
                text: "Lazy tip"
                enabled: false
            }
        }
    }

    Component {
        id: disabledOwnerComp

        Rectangle {
            x: 150
            y: 150
            width: 120
            height: 40
            color: "lightgray"
            enabled: false

            readonly property alias tooltip: tooltip

            StatusLazyToolTip {
                id: tooltip
                tooltipObjectName: "lazyTip"
                text: "Lazy tip"
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
        id: rowComp

        Row {
            x: 150
            y: 150
            spacing: 10

            readonly property alias tooltip: tooltip
            readonly property alias trailing: trailing

            Rectangle { width: 30; height: 20; color: "lightgray" }

            StatusLazyToolTip {
                id: tooltip
                text: "Lazy tip"
                delay: 0
            }

            Rectangle {
                id: trailing
                width: 30
                height: 20
                color: "lightgray"
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
            leave()
        }

        function hover(item) {
            mouseMove(item, item.width / 2, item.height / 2)
        }

        function leave() {
            mouseMove(root, 2, 2)
        }

        function test_notBuiltUntilHovered() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            waitForRendering(target)

            verify(!target.tooltip.active, "the tooltip must start unbuilt")
            compare(target.tooltip.item, null, "no popup before the first hover")
            compare(target.tooltip.visible, false)
            compare(target.tooltip.opened, false)
            compare(findChild(target, "lazyTip"), null)
        }

        function test_hoverBuildsTheTooltip() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            waitForRendering(target)

            hover(target)

            verify(target.tooltip.visible, "hover must be reported by the tooltip")
            verify(!!target.tooltip.item, "hover must build the popup")
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

            hover(target)

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
            waitForRendering(target)
            hover(target)

            const tip = target.tooltip.item
            verify(!!tip)
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
            waitForRendering(target)
            hover(target)

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

            hover(target)
            compare(root.providerCalls, 1, "the text is pulled when the tooltip is shown")
            compare(target.tooltip.item.text, "provided text")

            leave()
            tryCompare(target.tooltip, "visible", false, 2000)
            target.provided = "second text"
            hover(target)

            compare(root.providerCalls, 2, "the text is pulled again on the next show")
            compare(target.tooltip.item.text, "second text")
        }

        // Most controls carry a tooltip they are never given text for, so an
        // empty one must not cost a Popup even once it is hovered.
        function test_emptyTextBuildsNothing() {
            const target = createTemporaryObject(providedComp, root)
            verify(!!target)
            waitForRendering(target)
            target.provided = ""

            hover(target)

            compare(target.tooltip.item, null, "an empty text must not build the popup")
            wait(300) // past StatusToolTip's show delay
            compare(target.tooltip.opened, false, "an empty text must never open the tooltip")
        }

        // Text arriving while the cursor is already resting still shows.
        function test_textArrivingUnderARestingCursorBuildsTheTooltip() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            waitForRendering(target)
            target.tooltip.text = ""

            hover(target)
            compare(target.tooltip.item, null, "nothing to say, nothing built")

            target.tooltip.text = "Late tip"
            verify(!!target.tooltip.item, "text arriving under a hover must build the popup")
            compare(target.tooltip.item.text, "Late tip")
        }

        // The owner's say: withheld, nothing is watched and nothing is built.
        function test_disabledNeverBuilds() {
            const target = createTemporaryObject(gatedComp, root)
            verify(!!target)
            waitForRendering(target)

            hover(target)

            compare(target.tooltip.visible, false, "a disabled tooltip must not report hover")
            compare(target.tooltip.item, null, "a disabled tooltip must not be built")

            target.tooltipEnabled = true
            tryVerify(() => !!target.tooltip.item, 2000,
                      "re-enabling under a resting cursor must build the tooltip")
        }

        // An owner that is itself disabled has no say to give.
        function test_disabledOwnerNeverBuilds() {
            const target = createTemporaryObject(disabledOwnerComp, root)
            verify(!!target)
            waitForRendering(target)

            hover(target)

            compare(target.tooltip.enabled, false,
                    "a disabled owner disables the tooltip with it")
            compare(target.tooltip.item, null, "no popup under a disabled owner")
        }

        // A tooltip is a pointer affordance: a tap must never raise one.
        function test_touchNeverBuilds() {
            const target = createTemporaryObject(plainComp, root)
            verify(!!target)
            waitForRendering(target)

            const touch = touchEvent(target)
            touch.press(0, target, target.width / 2, target.height / 2).commit()
            compare(target.tooltip.visible, false, "a touch must not report hover")
            compare(target.tooltip.item, null, "a touch must not build the tooltip")

            touch.release(0, target, target.width / 2, target.height / 2).commit()
            wait(300) // past StatusToolTip's show delay, with the finger just lifted
            compare(target.tooltip.item, null, "a lifted touch must not build the tooltip")
        }

        function test_takesNoRoomInARow() {
            const target = createTemporaryObject(rowComp, root)
            verify(!!target)
            waitForRendering(target)

            const restingX = target.trailing.x

            hover(target)
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

            hover(button)

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

            leave()
            tryCompare(button.tooltip, "opened", false, 2000,
                       "the tooltip hides when the hover ends")
        }
    }
}
