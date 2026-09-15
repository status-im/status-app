import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Layout

/*
   Acceptance tests for the bracketed panel slot (SectionPanelSlot), driven
   through the real StatusSectionLayout rather than a prototype.

   The baseline these are measured against lives in
   tst_SectionPanelResizeStorm.qml: replaying the width sequence a device
   rotation actually produced through a raw LayoutItemProxy costs one full
   relayout of the panel per step (9 for 9 window sizes), plus a multi-frame
   hold at a degenerate box across the portrait/landscape handoff.

   Covered here:
     * the same sequence through the real chrome, coalesced vs not;
     * portrait -> landscape -> portrait round trips, repeated, in both
       directions - state that survives one transition can still be wrong on
       the way back;
     * arbitration: the same panel is bound into BOTH sub-layouts at once, so
       two slots target it and exactly one may own it.
*/
Item {
    id: root

    width: 390
    height: 844

    // Widths measured on device across an Android rotation, both times
    // (.plan/panelgeo-device-capture.txt, episodes 7 and 9). The first four
    // are the platform animating the window in portrait; the crossing at 1048
    // is the orientation swap; the tail is our own left-column animation.
    readonly property var rotationWidths: [480, 416, 371, 435, 1048, 972, 908, 863, 908]

    readonly property int portraitWidth: 390
    readonly property int portraitHeight: 844
    readonly property int landscapeWidth: 1048
    readonly property int landscapeHeight: 416

    component GeoRecorder: QtObject {
        id: rec
        required property Item watched
        property var settled: []
        property bool _pending: false
        property var events: []
        readonly property Connections conn: Connections {
            target: rec.watched
            function onWidthChanged() { rec.record("w") }
            function onHeightChanged() { rec.record("h") }
            function onParentChanged() { rec.record("P") }
        }
        function record(why) {
            rec.events.push(why + ":" + rec.watched.width + "x" + rec.watched.height)
            if (rec._pending)
                return
            rec._pending = true
            Qt.callLater(rec.sample)
        }
        function resizeCount() {
            let n = 0
            for (let i = 0; i < rec.events.length; ++i)
                if (rec.events[i][0] !== "P") ++n
            return n
        }
        function sample() {
            rec._pending = false
            const s = watched.width + "x" + watched.height
            if (settled.length === 0 || settled[settled.length - 1] !== s)
                settled.push(s)
        }
        function reset() { settled = [] }
    }
    Component { id: recorderComponent; GeoRecorder {} }
    Component { id: panelComponent; Rectangle { color: "grey" } }
    Component { id: footerComponent; Rectangle { color: "green"; implicitHeight: 61 } }
    Component {
        id: chromeComponent
        StatusSectionLayout { anchors.fill: parent; currentIndex: 1 }
    }

    // A section built the way the loader-owned ones are: the panel is a
    // property value, so it has no visual parent until the chrome adopts it,
    // and it sizes itself from the chrome's published slot geometry meanwhile.
    component SlotPreSizedSection: Item {
        id: sect
        property StatusSectionLayout sectionLayout: null
        readonly property Item centerPanel: Loader {
            width: sect.sectionLayout?.centerPanelSlotWidth ?? 0
            height: sect.sectionLayout?.centerPanelSlotHeight ?? 0
            sourceComponent: Rectangle { color: "red"; implicitWidth: 1440; implicitHeight: 4000 }
        }
        readonly property Item leftPanel: Loader {
            width: sect.sectionLayout?.leftPanelSlotWidth ?? 0
            height: sect.sectionLayout?.leftPanelSlotHeight ?? 0
            sourceComponent: Rectangle { color: "red"; implicitWidth: 900; implicitHeight: 6000 }
        }
    }
    Component { id: slotPreSizedSectionComponent; SlotPreSizedSection {} }

    TestCase {
        name: "SectionPanelGeometrySlot"
        when: windowShown

        function cleanup() {
            root.width = root.portraitWidth
            root.height = root.portraitHeight
        }

        function isDescendantOf(item, ancestor) {
            let it = item
            while (it) {
                if (it === ancestor) return true
                it = it.parent
            }
            return false
        }

        // A section shaped like the wallet's: a left panel and a centre panel
        // handed to the chrome, plus a footer, so the centre slot is not simply
        // the section's box.
        function makeSection(coalesce) {
            const chrome = createTemporaryObject(chromeComponent, root,
                                                 {coalesceResizes: coalesce})
            verify(!!chrome)
            const left = createTemporaryObject(panelComponent, root)
            const center = createTemporaryObject(panelComponent, root)
            chrome.leftPanel = left
            chrome.centerPanel = center
            chrome.footer = createTemporaryObject(footerComponent, root)
            waitForRendering(chrome)
            settle(chrome)
            return {chrome: chrome, left: left, center: center}
        }

        // Long enough for the settle timer (48ms) plus the landscape
        // left-column NumberAnimation (AnimationDuration.Slow = 400ms).
        function settle(chrome) {
            wait(600)
            waitForRendering(chrome)
            wait(60)
        }

        function storm(chrome) {
            for (let i = 0; i < root.rotationWidths.length; ++i) {
                root.width = root.rotationWidths[i]
                root.height = root.rotationWidths[i] < 752 ? root.portraitHeight
                                                           : root.landscapeHeight
                waitForRendering(chrome)
                wait(16)                 // a frame apart, as on the device
            }
            settle(chrome)
        }

        // ------------------------------------------------------------------
        // F1: the storm
        // ------------------------------------------------------------------

        // Live pass-through: every step of the storm is a relayout of the
        // panel, as the raw LayoutItemProxy baseline is.
        function test_rotationStorm_notCoalesced() {
            const s = makeSection(false)
            const rec = createTemporaryObject(recorderComponent, root, {watched: s.center})
            storm(s.chrome)
            console.info("SLOT storm (coalesceResizes=false) settled:",
                         JSON.stringify(rec.settled))
            verify(rec.settled.length > 2,
                   "without coalescing the storm should still reach the panel, got "
                   + JSON.stringify(rec.settled))
        }

        // Bracketed: the whole storm costs one relayout, and ends on the right
        // box. This is the headline number.
        function test_rotationStorm_coalesced() {
            const s = makeSection(true)
            const rec = createTemporaryObject(recorderComponent, root, {watched: s.center})
            storm(s.chrome)
            console.info("SLOT storm (coalesceResizes=true) settled:",
                         JSON.stringify(rec.settled))
            verify(rec.settled.length <= 2,
                   "a coalesced storm must cost at most two relayouts, got "
                   + JSON.stringify(rec.settled))
            compare(s.center.width, s.center.parent.width,
                    "the panel must end on its slot's width")
            compare(s.center.height, s.center.parent.height,
                    "the panel must end on its slot's height")
        }

        // A resize nobody bracketed still tracks live, or a desktop window drag
        // would lag by the settle interval.
        function test_unbracketedResizeTracksLive() {
            const s = makeSection(false)
            root.width = 500
            waitForRendering(s.chrome); wait(30)
            compare(s.center.width > 0, true)
            compare(s.center.width, s.center.parent.width,
                    "outside a bracket the panel tracks its slot immediately")
        }

        // ------------------------------------------------------------------
        // F1: the degenerate hold (design 1b - 148ms at 0x0 on device)
        // ------------------------------------------------------------------

        function test_degenerateHostBoxIsNotWrittenThrough() {
            const s = makeSection(false)
            const before = s.center.height
            verify(before > 0)

            root.height = 4                // collapses the centre slot
            waitForRendering(s.chrome); wait(80)
            const collapsed = s.center.height
            root.height = root.portraitHeight
            waitForRendering(s.chrome); wait(80)
            console.info("SLOT degenerate: panel height while host collapsed =",
                         collapsed, "(was " + before + ")")
            compare(collapsed, before, "the slot keeps the last good box")
        }

        // ------------------------------------------------------------------
        // Orientation round trips - the user's explicit requirement
        // ------------------------------------------------------------------

        function toPortrait(chrome) {
            root.width = root.portraitWidth
            root.height = root.portraitHeight
            settle(chrome)
        }

        function toLandscape(chrome) {
            root.width = root.landscapeWidth
            root.height = root.landscapeHeight
            settle(chrome)
        }

        function assertPanelFitsItsSlot(panel, tag) {
            verify(!!panel.parent, tag + ": panel must have a parent")
            verify(panel.width > 0 && panel.height > 0,
                   tag + ": panel must have a real box, got "
                   + panel.width + "x" + panel.height)
            compare(panel.width, panel.parent.width, tag + ": width must match the slot")
            compare(panel.height, panel.parent.height, tag + ": height must match the slot")
        }

        function test_orientationRoundTrip_data() {
            return [{tag: "desktop", coalesce: false},
                    {tag: "mobile", coalesce: true}]
        }

        // Three full round trips, checking both panels at every stop. State
        // that survives one transition can still be wrong on the way back, so
        // this asserts at every leg rather than only at the end.
        function test_orientationRoundTrip(data) {
            const s = makeSection(data.coalesce)
            verify(s.chrome.isPortrait, "starts in portrait")
            assertPanelFitsItsSlot(s.center, "start centre")
            assertPanelFitsItsSlot(s.left, "start left")

            for (let i = 0; i < 3; ++i) {
                toLandscape(s.chrome)
                compare(s.chrome.isPortrait, false, "round " + i + ": became landscape")
                assertPanelFitsItsSlot(s.center, "round " + i + " landscape centre")
                assertPanelFitsItsSlot(s.left, "round " + i + " landscape left")
                verify(isDescendantOf(s.center, s.chrome.chosenLayout),
                       "round " + i + ": centre panel must live in the landscape layout")
                verify(isDescendantOf(s.left, s.chrome.chosenLayout),
                       "round " + i + ": left panel must live in the landscape layout")

                toPortrait(s.chrome)
                compare(s.chrome.isPortrait, true, "round " + i + ": back to portrait")
                assertPanelFitsItsSlot(s.center, "round " + i + " portrait centre")
                assertPanelFitsItsSlot(s.left, "round " + i + " portrait left")
                verify(isDescendantOf(s.center, s.chrome.chosenLayout),
                       "round " + i + ": centre panel must live in the portrait layout")
                verify(isDescendantOf(s.left, s.chrome.chosenLayout),
                       "round " + i + ": left panel must live in the portrait layout")
            }
        }

        // The bracket must never wedge: after every transition the panel is
        // tracking its slot again, so an ordinary resize still moves it.
        function test_bracketIsNeverLeftRaised() {
            const s = makeSection(true)
            toLandscape(s.chrome)
            toPortrait(s.chrome)
            toLandscape(s.chrome)

            compare(s.chrome.geometryTransitionOngoing, false,
                    "the bracket must be down once everything has settled")

            const before = s.center.height
            root.height = root.landscapeHeight - 40
            settle(s.chrome)
            verify(s.center.height !== before,
                   "a resize after the transition must still reach the panel")
            assertPanelFitsItsSlot(s.center, "after wedge check")
        }

        // The landscape left column also animates when something expands it
        // through leftPanelWidthOverride - the Activity Center. That is a user
        // action, not a system geometry transition, so it must NOT be
        // bracketed: leftColumnAnimating only holds a bracket that is already
        // up, it never raises one. The panels track the slide instead of
        // snapping at the end of it.
        function test_activityCentreSlideStillTracksLive_data() {
            return [{tag: "desktop", coalesce: false},
                    {tag: "mobile", coalesce: true}]
        }

        function test_activityCentreSlideStillTracksLive(data) {
            const s = makeSection(data.coalesce)
            toLandscape(s.chrome)
            const rec = createTemporaryObject(recorderComponent, root, {watched: s.center})

            s.chrome.leftPanelWidthOverride = 344
            wait(200)                     // mid-slide: the animation is 400ms
            const midway = rec.settled.length
            const bracketed = s.chrome.geometryTransitionOngoing
            settle(s.chrome)
            console.info("AC slide (" + data.tag + ") settled by mid-slide:", midway,
                         "| bracketed:", bracketed,
                         "| full:", JSON.stringify(rec.settled))
            compare(bracketed, false, "the AC slide must not raise the bracket")
            verify(midway > 1,
                   "the centre panel must track the AC slide, got " + midway
                   + " sizes by mid-slide")
        }

        // ------------------------------------------------------------------
        // F2: the published slot geometry
        // ------------------------------------------------------------------

        // The numbers must be the box the slot actually gives its panel, in
        // whichever orientation is chosen - the centre one especially, which is
        // short by the header and the footer and narrow by the left column.
        function test_publishedSlotGeometryIsTheBoxThePanelGets_data() {
            return [{tag: "portrait", landscape: false},
                    {tag: "landscape", landscape: true}]
        }

        function test_publishedSlotGeometryIsTheBoxThePanelGets(data) {
            const s = makeSection(false)
            if (data.landscape)
                toLandscape(s.chrome)
            console.info("SLOTGEO (" + data.tag + ") centre:",
                         s.chrome.centerPanelSlotWidth + "x" + s.chrome.centerPanelSlotHeight,
                         "| left:",
                         s.chrome.leftPanelSlotWidth + "x" + s.chrome.leftPanelSlotHeight,
                         "| section:", s.chrome.width + "x" + s.chrome.height)
            compare(s.chrome.centerPanelSlotWidth, s.center.width)
            compare(s.chrome.centerPanelSlotHeight, s.center.height)
            compare(s.chrome.leftPanelSlotWidth, s.left.width)
            compare(s.chrome.leftPanelSlotHeight, s.left.height)
            verify(s.chrome.centerPanelSlotHeight < s.chrome.height,
                   "the centre slot is shorter than the section - header + footer")
        }

        // A panel pre-sized from those numbers is adopted without one resize;
        // the only thing the handoff does is reparent it.
        function test_slotPreSizedPanelIsAdoptedWithoutAResize_data() {
            return [{tag: "portrait", landscape: false},
                    {tag: "landscape", landscape: true}]
        }

        function test_slotPreSizedPanelIsAdoptedWithoutAResize(data) {
            const s = makeSection(false)
            if (data.landscape)
                toLandscape(s.chrome)

            const section = createTemporaryObject(slotPreSizedSectionComponent, root,
                                                  {sectionLayout: s.chrome})
            waitForRendering(s.chrome); wait(30)
            compare(!!section.centerPanel.parent, false,
                    "a panel declared as a property value has no visual parent")

            const rec = createTemporaryObject(recorderComponent, root,
                                              {watched: section.centerPanel})
            s.chrome.centerPanel = section.centerPanel
            waitForRendering(s.chrome); wait(60)
            console.info("SLOTPRESIZE (" + data.tag + ") handoff events:",
                         JSON.stringify(rec.events))
            compare(rec.resizeCount(), 0,
                    "the handoff must not resize the panel: "
                    + JSON.stringify(rec.events))
        }

        // ...and the binding that pre-sized it does not survive the adoption.
        // Left in place it would track the slot behind the slot's back and the
        // bracket would buy nothing - the exact interaction between F1 and F2.
        function test_slotPreSizingDoesNotSurviveAdoptionAndDefeatTheBracket() {
            const s = makeSection(true)
            const section = createTemporaryObject(slotPreSizedSectionComponent, root,
                                                  {sectionLayout: s.chrome})
            waitForRendering(s.chrome); wait(30)
            s.chrome.centerPanel = section.centerPanel
            settle(s.chrome)

            const rec = createTemporaryObject(recorderComponent, root,
                                              {watched: section.centerPanel})
            storm(s.chrome)
            console.info("SLOTPRESIZE storm settled:", JSON.stringify(rec.settled))
            verify(rec.settled.length <= 2,
                   "a pre-sized panel must still be bracketed, got "
                   + JSON.stringify(rec.settled))
        }

        // ------------------------------------------------------------------
        // Arbitration: one panel, two slots
        // ------------------------------------------------------------------

        // The chrome binds the same panel into both sub-layouts at once. Only
        // the slot in the chosen layout may own it; the other must not steal it
        // back, or the two fight and the panel churns worse than before.
        function test_onlyTheChosenLayoutOwnsThePanel_data() {
            return [{tag: "portrait", landscape: false},
                    {tag: "landscape", landscape: true}]
        }

        function test_onlyTheChosenLayoutOwnsThePanel(data) {
            const s = makeSection(false)
            if (data.landscape)
                toLandscape(s.chrome)

            const rec = createTemporaryObject(recorderComponent, root, {watched: s.center})
            // Nothing changes; if two slots were fighting they would trade the
            // panel back and forth on their own.
            wait(300)
            waitForRendering(s.chrome)
            console.info("SLOT arbitration idle churn (" + data.tag + "):",
                         JSON.stringify(rec.settled))
            compare(rec.settled.length, 0,
                    "an idle chrome must not resize the panel: "
                    + JSON.stringify(rec.settled))
            verify(isDescendantOf(s.center, s.chrome.chosenLayout),
                   "the panel must live in the chosen layout")
            assertPanelFitsItsSlot(s.center, "arbitration " + data.tag)
        }

        // Rotating with the right panel showing exercises the third slot pair,
        // whose portrait page is inserted and removed from the SwipeView.
        function test_rightPanelSurvivesTheRoundTrip() {
            const s = makeSection(false)
            const right = createTemporaryObject(panelComponent, root)
            s.chrome.rightPanel = right
            s.chrome.showRightPanel = true
            settle(s.chrome)
            assertPanelFitsItsSlot(right, "portrait right")

            toLandscape(s.chrome)
            assertPanelFitsItsSlot(right, "landscape right")
            verify(isDescendantOf(right, s.chrome.chosenLayout),
                   "the right panel must live in the landscape layout")

            toPortrait(s.chrome)
            assertPanelFitsItsSlot(right, "portrait right again")
            verify(isDescendantOf(right, s.chrome.chosenLayout),
                   "the right panel must live in the portrait layout")
        }
    }
}
