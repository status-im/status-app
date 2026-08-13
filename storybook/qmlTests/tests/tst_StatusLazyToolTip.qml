import QtQuick
import QtTest

import StatusQ.Components

/*
 StatusLazyToolTip
 =================
 Wraps StatusToolTip so that bulk-created components (message rows) don't pay
 for a tooltip nobody may ever see: neither the tooltip nor its text is built
 until the first hover of `hoverTarget`.

 Configurations:
 - never hovered                       → test_notCreatedUntilHover
 - hovered                             → test_hoverCreatesAndFillsTooltip
 - hover disabled (e.g. full timestamp)→ test_hoverEnabledGate
*/
Item {
    id: root

    width: 300
    height: 200

    property int providerCalls: 0

    Component {
        id: targetComp

        Rectangle {
            anchors.centerIn: parent
            width: 120
            height: 40
            color: "lightgray"

            readonly property alias tooltip: tooltip

            StatusLazyToolTip {
                id: tooltip
                hoverTarget: parent
                maxWidth: 350
                tooltipObjectName: "lazyTooltip"
                textProvider: () => {
                    root.providerCalls++
                    return "provided text"
                }
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

        function test_notCreatedUntilHover() {
            const target = createTemporaryObject(targetComp, root)
            verify(!!target)
            waitForRendering(target)

            verify(!target.tooltip.active, "the loader must start inactive")
            compare(target.tooltip.item, null, "no tooltip instance before the first hover")
            compare(root.providerCalls, 0, "textProvider must not run at creation")
            compare(findChild(target, "lazyTooltip"), null)
        }

        function test_hoverCreatesAndFillsTooltip() {
            const target = createTemporaryObject(targetComp, root)
            verify(!!target)
            waitForRendering(target)

            mouseMove(target, target.width / 2, target.height / 2)

            tryVerify(() => !!target.tooltip.item, 2000, "hover must create the tooltip")
            compare(root.providerCalls, 1, "the text is pulled when the tooltip is created")
            compare(target.tooltip.item.text, "provided text")
            compare(target.tooltip.item.parent, target, "the tooltip is parented to the hover target")
            compare(target.tooltip.item.maxWidth, 350)
            compare(target.tooltip.item.objectName, "lazyTooltip")

            tryVerify(() => target.tooltip.item.visible, 3000, "the tooltip shows while hovered")

            mouseMove(root, 2, 2)
            tryVerify(() => !target.tooltip.item.visible, 3000, "the tooltip hides when the hover ends")
        }

        function test_hoverEnabledGate() {
            const target = createTemporaryObject(targetComp, root)
            verify(!!target)
            target.tooltip.hoverEnabled = false
            waitForRendering(target)

            mouseMove(target, target.width / 2, target.height / 2)
            waitForRendering(target)

            verify(!target.tooltip.active, "hover must not activate the loader while disabled")
            compare(root.providerCalls, 0)
        }
    }
}
