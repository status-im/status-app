import QtQuick
import QtTest

import StatusQ.Layout

// The portrait chrome slides between panels (SwipeView) and brackets every
// slide with panelSwitchStarted/panelSwitchEnded. Consumers use the pair to
// defer expensive panel swaps (skeleton → real panel) off the animation:
// retargeting a slot mid-slide stutters it.
Item {
    id: root

    width: 390
    height: 700

    Component {
        id: layoutComponent

        StatusSectionLayoutPortrait {
            anchors.fill: parent
            showRightPanel: true
        }
    }

    Component {
        id: panelComponent
        Rectangle {}
    }

    SignalSpy {
        id: startedSpy
        signalName: "panelSwitchStarted"
    }

    SignalSpy {
        id: endedSpy
        signalName: "panelSwitchEnded"
    }

    TestCase {
        name: "StatusSectionLayoutPortrait"
        when: windowShown

        property var layout: null

        function init() {
            layout = createTemporaryObject(layoutComponent, root)
            verify(!!layout)
            layout.leftPanel = createTemporaryObject(panelComponent, root)
            layout.centerPanel = createTemporaryObject(panelComponent, root)
            layout.rightPanel = createTemporaryObject(panelComponent, root)
            waitForRendering(layout)

            startedSpy.target = layout
            endedSpy.target = layout
            startedSpy.clear()
            endedSpy.clear()
        }

        function test_panelSwitchSignalsBracketTheSlide() {
            compare(layout.currentIndex, 0)
            compare(startedSpy.count, 0)

            layout.currentIndex = 2
            compare(startedSpy.count, 1,
                    "the slide to another panel must emit panelSwitchStarted")
            compare(endedSpy.count, 0,
                    "panelSwitchEnded must wait for the slide to settle")

            tryCompare(endedSpy, "count", 1, 5000,
                       "panelSwitchEnded must fire once the slide settles")
            compare(startedSpy.count, 1, "the slide must emit exactly one pair")
        }

        function test_noSignalsWhileIdle() {
            waitForRendering(layout)
            compare(startedSpy.count, 0)
            compare(endedSpy.count, 0)
        }
    }
}
