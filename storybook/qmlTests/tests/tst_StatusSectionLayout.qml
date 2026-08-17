import QtQuick
import QtTest

import StatusQ.Layout

// StatusSectionLayout brackets every panel switch with
// panelSwitchStarted/panelSwitchEnded. Landscape shows all panels at once —
// there is no slide — so a currentIndex change must emit the pair
// back-to-back, and the invisible portrait view's own slide must not leak
// extra signals. (The window is 1000px wide: landscape mode.)
Item {
    id: root

    width: 1000
    height: 700

    Component {
        id: layoutComponent

        StatusSectionLayout {
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
        name: "StatusSectionLayout"
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

        // The internal portrait view; its `visible` is what the orientation
        // selector flips on rotation, so setting it simulates a rotation.
        function portraitView() {
            const list = layout.children
            for (let i = 0; i < list.length; ++i) {
                if (list[i].toString().indexOf("StatusSectionLayoutPortrait") === 0)
                    return list[i]
            }
            return null
        }

        // Rotating to landscape mid-slide must close the bracket right away:
        // the slide is no longer visible, so there is nothing left to defer
        // panel swaps for.
        function test_rotateToLandscapeMidSlideClosesBracket() {
            const pv = portraitView()
            verify(!!pv)
            pv.contentItem.highlightMoveDuration = 60000 // hold the slide
            pv.visible = true // start in portrait

            layout.currentIndex = StatusSectionLayout.RightPanel
            compare(startedSpy.count, 1)
            compare(endedSpy.count, 0)

            pv.visible = false // rotate away mid-slide
            compare(endedSpy.count, 1,
                    "rotating away mid-slide must close the bracket at once")

            // the invisible slide settling later must not emit anything more
            pv.contentItem.highlightMoveDuration = 50
            tryVerify(() => Math.abs(pv.contentItem.contentX - pv.currentItem.x) < 0.5,
                      5000)
            compare(startedSpy.count, 1)
            compare(endedSpy.count, 1)
        }

        // Rotating to portrait while the (invisible) slide from a landscape
        // switch is still running must open a bracket for it — the animation
        // is suddenly visible and panel swaps must defer to its end.
        function test_rotateToPortraitMidSlideOpensBracket() {
            const pv = portraitView()
            verify(!!pv)
            verify(!pv.visible, "the 1000px window must start in landscape")
            pv.contentItem.highlightMoveDuration = 60000 // hold the slide

            layout.currentIndex = StatusSectionLayout.RightPanel
            compare(startedSpy.count, 1, "landscape pair")
            compare(endedSpy.count, 1, "landscape pair")

            pv.visible = true // rotate into the running slide
            compare(startedSpy.count, 2,
                    "rotating into a running slide must open a bracket")
            compare(endedSpy.count, 1)

            pv.contentItem.highlightMoveDuration = 50
            tryCompare(endedSpy, "count", 2, 5000,
                       "the bracket must close when the slide settles")
            compare(startedSpy.count, 2)
        }

        function test_landscapeSwitchEmitsPairBackToBack() {
            layout.currentIndex = StatusSectionLayout.RightPanel

            compare(startedSpy.count, 1,
                    "a landscape switch must emit panelSwitchStarted")
            compare(endedSpy.count, 1,
                    "a landscape switch must emit panelSwitchEnded right after")

            // the invisible portrait view still slides underneath; its own
            // start/end must not leak through as extra emissions
            wait(500)
            compare(startedSpy.count, 1)
            compare(endedSpy.count, 1)
        }
    }
}
