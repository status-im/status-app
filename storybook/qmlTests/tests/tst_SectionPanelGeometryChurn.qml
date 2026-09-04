import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Components
import StatusQ.Layout

/*
   Characterises every geometry a section panel is put through by
   StatusSectionLayout, and attributes each transition to a mechanism.

   Two metrics are reported per scenario:
     * sizes    - every (w,h) the panel reported, in order. Width and height
                  changes are separate signals, so this over-counts.
     * SETTLED  - one sample per event-loop turn, i.e. per layout pass. This is
                  the count that corresponds to a real relayout of the panel's
                  subtree; intra-turn intermediates never reach a frame.

   Companion files:
     tst_SectionPanelGeometryRemedies.qml  - A/B of the candidate fixes
     tst_SectionPanelIncubationCost.qml    - cost of the unparented phase
     tst_SectionPanelIndexing.qml          - SwipeView index bug (RED)
*/
Item {
    id: root

    width: 390
    height: 844

    component GeoRecorder: QtObject {
        id: rec
        required property Item watched
        property var sizes: []
        property var events: []
        property var settled: []
        property bool _pending: false

        readonly property Connections conn: Connections {
            target: rec.watched
            function onWidthChanged() { rec.record("w") }
            function onHeightChanged() { rec.record("h") }
            function onParentChanged() { rec.record("P") }
        }
        function record(why) {
            const s = watched.width + "x" + watched.height
            events.push(why + ":" + s + (watched.parent ? "" : "/orphan"))
            if (sizes.length === 0 || sizes[sizes.length - 1] !== s)
                sizes.push(s)
            if (!rec._pending) {
                rec._pending = true
                Qt.callLater(rec.sample)
            }
        }
        function sample() {
            rec._pending = false
            const s = watched.width + "x" + watched.height
            if (settled.length === 0 || settled[settled.length - 1] !== s)
                settled.push(s)
        }
        function dump(tag) {
            console.info(tag, "| sizes:", JSON.stringify(sizes),
                         "| SETTLED:", JSON.stringify(settled),
                         "| events:", JSON.stringify(events))
        }
    }
    Component { id: recorderComponent; GeoRecorder {} }

    Component { id: panelComponent; Rectangle { color: "grey" } }
    Component { id: footerComponent; Rectangle { color: "green"; implicitHeight: 61 } }
    Component { id: headerContentComponent; Item { property real want: 20
                                                   implicitHeight: want; implicitWidth: 80 } }
    Component { id: toolBarComponent; StatusToolBar { width: 390 } }
    Component {
        id: chromeComponent
        StatusSectionLayout { anchors.fill: parent; currentIndex: 1 }
    }

    // A section that builds its panels as unparented property Items, as
    // WalletLayout and ChatView do.
    component UnboundSection: Item {
        id: sect
        readonly property Item leftPanel: Loader {
            sourceComponent: Rectangle { color: "red"; implicitWidth: 900; implicitHeight: 6000 }
        }
        readonly property Item centerPanel: Loader {
            sourceComponent: Rectangle { color: "red"; implicitWidth: 1440; implicitHeight: 4000 }
        }
    }
    Component { id: unboundSectionComponent; UnboundSection {} }

    TestCase {
        name: "SectionPanelGeometryChurn"
        when: windowShown

        function cleanup() { root.width = 390; root.height = 844 }

        function makeChrome() {
            const c = createTemporaryObject(chromeComponent, root)
            verify(!!c)
            return c
        }

        // ------------------------------------------------------------------
        // 1. The handoff itself
        // ------------------------------------------------------------------

        // A panel handed over with no visual parent reports its *content's*
        // implicit size until the chrome adopts it, then jumps once.
        function test_handoffIsASingleSettledTransition() {
            const chrome = makeChrome()
            waitForRendering(chrome); wait(20)

            const section = createTemporaryObject(unboundSectionComponent, root)
            console.info("PREHANDOFF center:",
                         section.centerPanel.width + "x" + section.centerPanel.height,
                         "parent:", !!section.centerPanel.parent)
            compare(!!section.centerPanel.parent, false,
                    "a panel declared as a property value has no visual parent")

            const rec = createTemporaryObject(recorderComponent, root,
                                              {watched: section.centerPanel})
            chrome.centerPanel = section.centerPanel
            chrome.leftPanel = section.leftPanel
            waitForRendering(chrome); wait(30)
            rec.dump("HANDOFF center")
            // Two: the implicit-size phase the panel spends unparented, then
            // the box the chrome gives it. The chrome adds nothing beyond that.
            compare(rec.settled.length, 2,
                    "the handoff is the implicit-size phase plus one adoption")
        }

        // ------------------------------------------------------------------
        // 2. Terms that move the panel AFTER it is adopted
        // ------------------------------------------------------------------

        // The host's height reaches the panel 1:1 - no amplification.
        function test_hostHeightReachesThePanelOneForOne() {
            const chrome = makeChrome()
            const panel = createTemporaryObject(panelComponent, root)
            chrome.centerPanel = panel
            waitForRendering(chrome); wait(20)

            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})
            root.height = 800
            waitForRendering(chrome); wait(20)
            root.height = 772
            waitForRendering(chrome); wait(20)
            rec.dump("HOSTHEIGHT")
            compare(rec.settled.length, 2, "one panel size per host height")
        }

        // The toolbar's implicit height is not constant: the back button adds
        // 20px, its label another 10.
        function test_toolBarImplicitHeightTerms() {
            const tb = createTemporaryObject(toolBarComponent, root,
                                             {backButtonVisible: false})
            waitForRendering(tb); wait(20)
            const hidden = tb.implicitHeight
            tb.backButtonVisible = true
            waitForRendering(tb); wait(20)
            const iconOnly = tb.implicitHeight
            tb.backButtonName = "Some account"
            waitForRendering(tb); wait(20)
            const withLabel = tb.implicitHeight
            console.info("TOOLBAR hidden=" + hidden + " iconOnly=" + iconOnly
                         + " withLabel=" + withLabel)
            verify(hidden !== iconOnly && iconOnly !== withLabel,
                   "toolbar height depends on the back button and its label")
        }

        // ...and the portrait chrome subtracts it from the centre panel, so a
        // panel *arriving* in another slot resizes the centre panel: the left
        // panel's page makes index 1 reachable, which shows the back button.
        function test_leftPanelArrivalResizesTheCentrePanel() {
            const chrome = makeChrome()
            const center = createTemporaryObject(panelComponent, root)
            chrome.centerPanel = center
            waitForRendering(chrome); wait(20)
            const before = center.height

            const rec = createTemporaryObject(recorderComponent, root, {watched: center})
            chrome.leftPanel = createTemporaryObject(panelComponent, root)
            waitForRendering(chrome); wait(20)
            console.info("LEFTARRIVES centre height " + before + " -> " + center.height)
            rec.dump("LEFTARRIVES")
            verify(center.height !== before,
                   "the centre panel is resized by a panel arriving elsewhere")
        }

        // headerContent's implicit height passes straight through to the panel.
        function test_headerContentHeightMovesTheCentrePanel() {
            const chrome = makeChrome()
            const left = createTemporaryObject(panelComponent, root)
            const center = createTemporaryObject(panelComponent, root)
            chrome.leftPanel = left
            chrome.centerPanel = center
            const hc = createTemporaryObject(headerContentComponent, root, {want: 20})
            chrome.headerContent = hc
            waitForRendering(chrome); wait(30)
            const a = center.height
            hc.want = 49
            waitForRendering(chrome); wait(30)
            console.info("HEADERCONTENT centre height " + a + " -> " + center.height
                         + " (headerContent 20 -> 49)")
            compare(a - center.height, 29,
                    "headerContent's height is subtracted from the centre panel 1:1")
        }

        // The footer slot: its implicit height moves the centre panel, but the
        // *target's* visibility does not release the space.
        function test_footerTerms() {
            const chrome = makeChrome()
            const left = createTemporaryObject(panelComponent, root)
            const center = createTemporaryObject(panelComponent, root)
            const footer = createTemporaryObject(footerComponent, root)
            chrome.leftPanel = left
            chrome.centerPanel = center
            chrome.footer = footer
            waitForRendering(chrome); wait(30)
            const withFooter = center.height

            footer.visible = false
            waitForRendering(chrome); wait(30)
            const targetHidden = center.height

            footer.visible = true
            chrome.showFooter = false
            waitForRendering(chrome); wait(30)
            const slotOff = center.height

            chrome.showFooter = true
            footer.implicitHeight = 90
            waitForRendering(chrome); wait(30)
            const taller = center.height

            console.info("FOOTER centre height: withFooter=" + withFooter
                         + " targetHidden=" + targetHidden
                         + " showFooter=false -> " + slotOff
                         + " implicitHeight 61->90 -> " + taller)
            compare(targetHidden, withFooter,
                    "hiding the footer *target* does not release the slot")
            verify(slotOff !== withFooter, "showFooter releases the slot")
            verify(taller !== withFooter, "the footer's implicit height moves the panel")
        }

        // ------------------------------------------------------------------
        // 3. Reparenting churn
        // ------------------------------------------------------------------

        // Rotation hands the panel from the portrait chrome to the landscape
        // one and back. Each swap also starts the landscape left-panel width
        // animation (StatusSectionLayoutLandscape.qml, `Behavior on
        // d.effectiveLeftPanelWidth`), which used to walk the centre panel
        // through a width per animation frame - a full relayout each.
        //
        // StatusSectionLayout brackets both, so a rotation costs one relayout
        // per orientation. (Was: > 2 per rotation, hence this file's name.)
        //
        // coalesceResizes is what a phone runs with: there, every window resize
        // is the system rotating/splitting the screen, never a user drag.
        function test_rotationCostsOneRelayoutPerOrientation() {
            const chrome = createTemporaryObject(chromeComponent, root,
                                                 {coalesceResizes: true})
            verify(!!chrome)
            const center = createTemporaryObject(panelComponent, root)
            const left = createTemporaryObject(panelComponent, root)
            chrome.centerPanel = center
            chrome.leftPanel = left
            waitForRendering(chrome); wait(600)

            const rec = createTemporaryObject(recorderComponent, root, {watched: center})
            root.width = 1200
            waitForRendering(chrome); wait(600)
            root.width = 390
            waitForRendering(chrome); wait(600)
            rec.dump("ROTATION isPortrait=" + chrome.isPortrait)
            // At most three: one per settled orientation, plus one the outgoing
            // layout gets in before the bracket engages - QQuickItem cascades a
            // geometry change to its children's anchors before emitting its own
            // widthChanged, so the first size of a burst is always live. Every
            // further size in the burst, and every frame of the left-column
            // animation, is coalesced away.
            verify(rec.settled.length <= 3,
                   "a rotation must not walk the panel through the left-column "
                   + "animation, got " + JSON.stringify(rec.settled))
            compare(center.width, center.parent.width,
                    "and the panel must end on its slot's box")
            compare(center.height, center.parent.height)
        }

        // Showing/hiding the right panel inserts and takes its SwipeView page;
        // the panel is orphaned on the way out.
        function test_rightPanelToggleOrphansIt() {
            const chrome = makeChrome()
            const left = createTemporaryObject(panelComponent, root)
            const center = createTemporaryObject(panelComponent, root)
            const right = createTemporaryObject(panelComponent, root)
            chrome.leftPanel = left
            chrome.centerPanel = center
            chrome.rightPanel = right
            waitForRendering(chrome); wait(20)

            const recC = createTemporaryObject(recorderComponent, root, {watched: center})
            const recR = createTemporaryObject(recorderComponent, root, {watched: right})
            chrome.showRightPanel = true
            waitForRendering(chrome); wait(20)
            chrome.showRightPanel = false
            waitForRendering(chrome); wait(20)
            recC.dump("RIGHTTOGGLE centre")
            recR.dump("RIGHTTOGGLE right")
            compare(recC.settled.length, 0,
                    "toggling the right panel must not resize the centre panel")
        }
    }
}
