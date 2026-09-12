import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTest

import StatusQ.Layout

/*
   A/B of the candidate remedies against what the chrome does today.

   REJECTED here (kept as evidence): replacing LayoutItemProxy with a guarded,
   coalescing "panel slot" that refuses to write degenerate geometry and
   collapses same-frame writes. It cleans up the signal trace but changes
   nothing in the SETTLED trace, because Qt's layout pass already collapses
   those intermediates - they never reach a frame.

   ACCEPTED here: pre-sizing the incoming panel to the exact geometry the slot
   already imposes (test_slotExactPreSizingIsResizeFree) makes the handoff cost
   zero resizes.

   REFUTED here: any feedback from the panel's own implicit size back into the
   box the chrome gives it.
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
        function resizeCount() {
            let n = 0
            for (let i = 0; i < events.length; ++i)
                if (events[i][0] !== "P") ++n
            return n
        }
        function dump(tag) {
            console.info(tag, "| sizes:", JSON.stringify(sizes),
                         "| SETTLED:", JSON.stringify(settled),
                         "| resizes:", resizeCount(),
                         "| events:", JSON.stringify(events))
        }
    }
    Component { id: recorderComponent; GeoRecorder {} }
    Component { id: panelComponent; Rectangle { color: "grey" } }
    Component { id: footerComponent; Rectangle { color: "green"; implicitHeight: 61 } }
    Component {
        id: bigPanelComponent
        Rectangle { color: "red"; implicitWidth: 1440; implicitHeight: 4000 }
    }
    Component {
        id: elasticPanelComponent
        Rectangle {
            color: "grey"
            property real want: 100
            implicitHeight: want
            implicitWidth: want
        }
    }
    Component {
        id: chromeComponent
        StatusSectionLayout { anchors.fill: parent; currentIndex: 1 }
    }

    // A section that pre-sizes its still-unparented panel to the slot geometry.
    component SlotBoundSection: Item {
        id: sbs
        property Item slotRef: null
        readonly property Item centerPanel: Loader {
            width: sbs.slotRef ? sbs.slotRef.width : 0
            height: sbs.slotRef ? sbs.slotRef.height : 0
            sourceComponent: Rectangle { color: "red"; implicitWidth: 1440; implicitHeight: 4000 }
        }
    }
    Component { id: slotBoundSectionComponent; SlotBoundSection {} }

    // ---------------- the rejected alternative ----------------
    component PanelSlot: Item {
        id: slot

        property Item target: null

        // The slot owns the target only while it can describe a real box for it.
        readonly property bool live: slot.visible && slot.width > 0 && slot.height > 0

        onLiveChanged: slot.schedule()
        onWidthChanged: slot.schedule()
        onHeightChanged: slot.schedule()
        onTargetChanged: {
            if (d.owned && d.owned !== slot.target)
                d.release(d.owned)
            slot.schedule()
        }

        QtObject {
            id: d
            property Item owned: null
            property bool pending: false
            function release(item) {
                if (item && item.parent === slot)
                    item.parent = null
                if (d.owned === item)
                    d.owned = null
            }
        }

        function schedule() {
            if (d.pending)
                return
            d.pending = true
            Qt.callLater(slot.apply)
        }

        function apply() {
            d.pending = false
            const t = slot.target
            if (!t || !slot.live)
                return
            d.owned = t
            if (t.parent !== slot) {
                t.parent = slot
                t.x = 0
                t.y = 0
            }
            if (t.width !== slot.width)
                t.width = slot.width
            if (t.height !== slot.height)
                t.height = slot.height
        }

        Component.onCompleted: slot.schedule()
    }

    // Two "chromes" that swap visibility, as LayoutChooser does.
    component ProxyPair: Item {
        id: pp
        anchors.fill: parent
        property Item panel: null
        property bool portrait: true
        property real headerHeight: 52

        Item {
            anchors.fill: parent
            visible: pp.portrait
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Item { Layout.fillWidth: true; Layout.preferredHeight: pp.headerHeight }
                LayoutItemProxy {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    target: pp.panel
                }
            }
        }
        Item {
            anchors.fill: parent
            visible: !pp.portrait
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Item { Layout.preferredWidth: 306; Layout.fillHeight: true }
                LayoutItemProxy {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    target: pp.panel
                }
            }
        }
    }

    component SlotPair: Item {
        id: sp
        anchors.fill: parent
        property Item panel: null
        property bool portrait: true
        property real headerHeight: 52

        Item {
            anchors.fill: parent
            visible: sp.portrait
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Item { Layout.fillWidth: true; Layout.preferredHeight: sp.headerHeight }
                PanelSlot {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    target: sp.panel
                }
            }
        }
        Item {
            anchors.fill: parent
            visible: !sp.portrait
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Item { Layout.preferredWidth: 306; Layout.fillHeight: true }
                PanelSlot {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    target: sp.panel
                }
            }
        }
    }

    Component { id: proxyPairComponent; ProxyPair {} }
    Component { id: slotPairComponent; SlotPair {} }

    TestCase {
        name: "SectionPanelGeometryRemedies"
        when: windowShown

        function cleanup() { root.width = 390; root.height = 844 }

        function rotate(host) {
            root.width = 1200; host.portrait = false
            waitForRendering(host); wait(30)
            root.width = 390; host.portrait = true
            waitForRendering(host); wait(30)
        }

        // ---------------- accepted ----------------

        // Pre-size the incoming panel to the geometry the slot already imposes
        // (read here off the skeleton occupying it): the handoff resizes
        // nothing at all.
        function test_slotExactPreSizingIsResizeFree() {
            const chrome = createTemporaryObject(chromeComponent, root)
            const leftSkel = createTemporaryObject(panelComponent, root)
            const centerSkel = createTemporaryObject(panelComponent, root)
            chrome.leftPanel = leftSkel
            chrome.centerPanel = centerSkel
            chrome.footer = createTemporaryObject(footerComponent, root)
            waitForRendering(chrome); wait(20)

            const section = createTemporaryObject(slotBoundSectionComponent, root,
                                                  {slotRef: centerSkel})
            waitForRendering(chrome); wait(20)
            console.info("SLOTEXACT pre-handoff panel:",
                         section.centerPanel.width + "x" + section.centerPanel.height,
                         "| slot:", centerSkel.width + "x" + centerSkel.height)

            const rec = createTemporaryObject(recorderComponent, root,
                                              {watched: section.centerPanel})
            chrome.centerPanel = section.centerPanel
            waitForRendering(chrome); wait(20)
            rec.dump("SLOTEXACT handoff")
            compare(rec.resizeCount(), 0,
                    "handoff must not resize the panel: " + JSON.stringify(rec.events))
        }

        // ---------------- refuted ----------------

        // The centre slot mirrors the panel's implicit size
        // (StatusSectionLayoutPortrait.qml, centerPanelProxy), which looks like
        // a feedback loop. It is not: the box the panel gets is unaffected.
        function test_noFeedbackFromThePanelsOwnImplicitSize() {
            const chrome = createTemporaryObject(chromeComponent, root)
            const left = createTemporaryObject(panelComponent, root)
            const center = createTemporaryObject(elasticPanelComponent, root, {want: 100})
            chrome.leftPanel = left
            chrome.centerPanel = center
            chrome.footer = createTemporaryObject(footerComponent, root)
            waitForRendering(chrome); wait(30)

            const wants = [100, 1000, 4000, 20000, 400, 100]
            const heights = []
            for (let i = 0; i < wants.length; ++i) {
                center.want = wants[i]
                waitForRendering(chrome); wait(30)
                heights.push(center.height)
            }
            console.info("FEEDBACK want:", JSON.stringify(wants),
                         "-> given height:", JSON.stringify(heights))
            for (let j = 1; j < heights.length; ++j)
                compare(heights[j], heights[0],
                        "the panel's implicit size must not change its own box")
        }

        // ---------------- rejected: the guarded slot ----------------

        function test_rotation_layoutItemProxy() {
            const panel = createTemporaryObject(panelComponent, root)
            const host = createTemporaryObject(proxyPairComponent, root, {panel: panel})
            waitForRendering(host); wait(30)
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})
            rotate(host)
            rec.dump("PROXY rotation")
            verify(true)
        }

        function test_rotation_panelSlot() {
            const panel = createTemporaryObject(panelComponent, root)
            const host = createTemporaryObject(slotPairComponent, root, {panel: panel})
            waitForRendering(host); wait(30)
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})
            rotate(host)
            rec.dump("SLOT rotation")
            verify(true)
        }

        function test_handoff_layoutItemProxy() {
            const host = createTemporaryObject(proxyPairComponent, root, {panel: null})
            waitForRendering(host); wait(30)
            const panel = createTemporaryObject(bigPanelComponent, root)
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})
            host.panel = panel
            waitForRendering(host); wait(30)
            rec.dump("PROXY handoff")
            verify(true)
        }

        function test_handoff_panelSlot() {
            const host = createTemporaryObject(slotPairComponent, root, {panel: null})
            waitForRendering(host); wait(30)
            const panel = createTemporaryObject(bigPanelComponent, root)
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})
            host.panel = panel
            waitForRendering(host); wait(30)
            rec.dump("SLOT handoff")
            verify(true)
        }

        // Same-frame writes cost nothing extra either way: Qt's layout pass
        // already collapses them.
        function test_sameFrameWritesCollapse_layoutItemProxy() {
            const panel = createTemporaryObject(panelComponent, root)
            const host = createTemporaryObject(proxyPairComponent, root, {panel: panel})
            waitForRendering(host); wait(30)
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})
            host.headerHeight = 32
            host.headerHeight = 52
            waitForRendering(host); wait(30)
            rec.dump("PROXY sameFrameWrites")
            compare(rec.settled.length, 0)
        }
    }
}
