import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTest

import StatusQ.Layout

/*
   The device capture's dominant cost is not the cold open: it is a *resize
   storm*. An Android rotation walks the window through a sequence of sizes
   spread over hundreds of milliseconds (480 -> 416 -> 371 -> 435 -> 1048 in the
   capture, ~430ms), and the portrait/landscape handoff parks the panel at a
   degenerate size for 148ms on the way.

   Unlike the same-turn intermediates in tst_SectionPanelGeometryRemedies.qml -
   which Qt's polish phase collapses for free - these span many frames, so every
   one is a real relayout of a populated panel.

   These tests measure a storm, and A/B a slot that holds the panel's geometry
   until the storm settles.
*/
Item {
    id: root

    width: 390
    height: 844

    component GeoRecorder: QtObject {
        id: rec
        required property Item watched
        property var settled: []
        property bool _pending: false
        readonly property Connections conn: Connections {
            target: rec.watched
            function onWidthChanged() { rec.record() }
            function onHeightChanged() { rec.record() }
        }
        function record() {
            if (rec._pending)
                return
            rec._pending = true
            Qt.callLater(rec.sample)
        }
        function sample() {
            rec._pending = false
            const s = watched.width + "x" + watched.height
            if (settled.length === 0 || settled[settled.length - 1] !== s)
                settled.push(s)
        }
    }
    Component { id: recorderComponent; GeoRecorder {} }
    Component { id: panelComponent; Rectangle { color: "grey" } }

    // A slot that holds the target's geometry while the host is still moving,
    // and never writes a degenerate box. Applies once, when things go quiet.
    component QuiescentPanelSlot: Item {
        id: slot

        property Item target: null
        property int settleMs: 32

        readonly property bool sane: slot.visible && slot.width > 0 && slot.height > 0

        onWidthChanged: settleTimer.restart()
        onHeightChanged: settleTimer.restart()
        onSaneChanged: settleTimer.restart()
        onTargetChanged: settleTimer.restart()

        Timer {
            id: settleTimer
            interval: slot.settleMs
            onTriggered: slot.apply()
        }

        function apply() {
            const t = slot.target
            if (!t || !slot.sane)
                return
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

        Component.onCompleted: settleTimer.restart()
    }

    // The shape actually proposed: a pass-through slot that only holds the
    // panel while the chrome says a geometry transition is in flight. No lag
    // outside the bracket, so a desktop window drag still tracks live.
    component BracketedPanelSlot: Item {
        id: bslot

        property Item target: null
        property bool frozen: false

        readonly property bool sane: bslot.visible && bslot.width > 0 && bslot.height > 0

        onWidthChanged: bslot.apply()
        onHeightChanged: bslot.apply()
        onSaneChanged: bslot.apply()
        onTargetChanged: bslot.apply()
        onFrozenChanged: bslot.apply()

        function apply() {
            const t = bslot.target
            if (!t || !bslot.sane || bslot.frozen)
                return
            if (t.parent !== bslot) {
                t.parent = bslot
                t.x = 0
                t.y = 0
            }
            if (t.width !== bslot.width)
                t.width = bslot.width
            if (t.height !== bslot.height)
                t.height = bslot.height
        }

        Component.onCompleted: bslot.apply()
    }

    component BracketHost: Item {
        anchors.fill: parent
        property alias panel: bs.target
        property alias frozen: bs.frozen
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            Item { Layout.fillWidth: true; Layout.preferredHeight: 52 }
            BracketedPanelSlot {
                id: bs
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
    Component { id: bracketHostComponent; BracketHost {} }

    component ProxyHost: Item {
        anchors.fill: parent
        property alias panel: proxy.target
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            Item { Layout.fillWidth: true; Layout.preferredHeight: 52 }
            LayoutItemProxy {
                id: proxy
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    component SlotHost: Item {
        anchors.fill: parent
        property alias panel: slot.target
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            Item { Layout.fillWidth: true; Layout.preferredHeight: 52 }
            QuiescentPanelSlot {
                id: slot
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    Component { id: proxyHostComponent; ProxyHost {} }
    Component { id: slotHostComponent; SlotHost {} }

    // A Loader inside a sizing host, to establish which way causality runs.
    component LoaderHolder: Item {
        id: lh
        property var order: []
        readonly property Item host: sizer
        Item {
            id: sizer
            width: 200
            height: 200
            Loader {
                id: ldr
                anchors.fill: parent
                sourceComponent: Rectangle { color: "grey" }
            }
            Connections {
                target: ldr
                function onHeightChanged() { lh.order.push("loader") }
            }
            Connections {
                target: ldr.item
                function onHeightChanged() { lh.order.push("item") }
            }
        }
    }
    Component { id: loaderHolderComponent; LoaderHolder {} }

    // The width sequence an Android rotation actually produced, from
    // .plan/panelgeo-device-capture.txt (episodes 7 and 9, identical both times).
    readonly property var rotationWidths: [480, 416, 371, 435, 1048, 972, 908, 863, 908]

    TestCase {
        name: "SectionPanelResizeStorm"
        when: windowShown

        function cleanup() { root.width = 390; root.height = 844 }

        function storm(host) {
            for (let i = 0; i < root.rotationWidths.length; ++i) {
                root.width = root.rotationWidths[i]
                waitForRendering(host)
                wait(16)                 // a frame apart, as on the device
            }
            wait(120)                    // let everything settle
        }

        // Baseline: every step of the storm reaches the panel.
        function test_stormReachesThePanel_layoutItemProxy() {
            const panel = createTemporaryObject(panelComponent, root)
            const host = createTemporaryObject(proxyHostComponent, root, {panel: panel})
            waitForRendering(host); wait(30)
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})
            storm(host)
            console.info("STORM proxy settled:", JSON.stringify(rec.settled))
            compare(rec.settled.length, root.rotationWidths.length,
                    "every storm step is a separate relayout of the panel")
        }

        // With a settle gate the panel is laid out once.
        function test_stormIsCoalesced_quiescentSlot() {
            const panel = createTemporaryObject(panelComponent, root)
            const host = createTemporaryObject(slotHostComponent, root, {panel: panel})
            waitForRendering(host); wait(60)
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})
            storm(host)
            console.info("STORM slot settled:", JSON.stringify(rec.settled))
            verify(rec.settled.length <= 2,
                   "the storm should cost one relayout, got "
                   + JSON.stringify(rec.settled))
            compare(rec.settled[rec.settled.length - 1],
                    panel.parent.width + "x" + panel.parent.height,
                    "and it must end on the right box")
        }

        // Reading the capture depends on knowing which way causality runs. In
        // the log the Loader's *item* (wallet.rightStack / wallet.leftTab) is
        // always logged before the Loader itself, which looks bottom-up. It is
        // not: QQuickLoader::geometryChange() resizes its item and only then
        // lets the base class emit widthChanged/heightChanged, so a top-down
        // resize always reports the item first.
        function test_loaderResizesItsItemBeforeEmittingItsOwnChange() {
            const holder = createTemporaryObject(loaderHolderComponent, root)
            waitForRendering(holder); wait(20)
            holder.order = []
            holder.host.height = 300
            waitForRendering(holder); wait(20)
            console.info("ORDER", JSON.stringify(holder.order))
            compare(holder.order[0], "item",
                    "the item reports first even though the change came from above")
            compare(holder.order[1], "loader")
        }

        // The proposed shape: hold only while the chrome brackets a transition.
        function test_stormIsCoalesced_bracketedSlot() {
            const panel = createTemporaryObject(panelComponent, root)
            const host = createTemporaryObject(bracketHostComponent, root, {panel: panel})
            waitForRendering(host); wait(30)
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})

            host.frozen = true
            storm(host)
            host.frozen = false
            waitForRendering(host); wait(60)

            console.info("STORM bracketed settled:", JSON.stringify(rec.settled))
            compare(rec.settled.length, 1,
                    "a bracketed storm costs one relayout, got "
                    + JSON.stringify(rec.settled))
        }

        // ...and stays a live pass-through outside the bracket, so a desktop
        // window drag is not laggy.
        function test_unbracketedResizeStillTracksLive_bracketedSlot() {
            const panel = createTemporaryObject(panelComponent, root)
            const host = createTemporaryObject(bracketHostComponent, root, {panel: panel})
            waitForRendering(host); wait(30)
            root.width = 500
            waitForRendering(host); wait(20)
            compare(panel.width, 500, "outside the bracket the panel tracks the host")
        }

        // The device also parks the panel at a degenerate size for 148ms during
        // the portrait/landscape handoff (0x0, then 306x0, then 306x416). Unlike
        // same-turn intermediates, that spans frames.
        function test_degenerateGeometryHeldAcrossFrames_layoutItemProxy() {
            const panel = createTemporaryObject(panelComponent, root)
            const host = createTemporaryObject(proxyHostComponent, root, {panel: panel})
            waitForRendering(host); wait(30)
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})

            root.height = 52             // slot collapses to 0 high
            waitForRendering(host); wait(80)
            const collapsed = panel.height
            root.height = 844
            waitForRendering(host); wait(80)
            console.info("DEGENERATE proxy: panel height while host collapsed =",
                         collapsed, "| settled:", JSON.stringify(rec.settled))
            compare(collapsed, 0, "the proxy passes the degenerate box straight on")
        }

        function test_degenerateGeometryIsNotWritten_quiescentSlot() {
            const panel = createTemporaryObject(panelComponent, root)
            const host = createTemporaryObject(slotHostComponent, root, {panel: panel})
            waitForRendering(host); wait(60)
            const before = panel.height
            const rec = createTemporaryObject(recorderComponent, root, {watched: panel})

            root.height = 52
            waitForRendering(host); wait(80)
            const collapsed = panel.height
            root.height = 844
            waitForRendering(host); wait(80)
            console.info("DEGENERATE slot: panel height while host collapsed =",
                         collapsed, "(was " + before + ") | settled:",
                         JSON.stringify(rec.settled))
            compare(collapsed, before, "the slot keeps the last good box")
        }
    }
}
