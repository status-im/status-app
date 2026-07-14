// SwapModal-open benchmark scene. Models the real thing the picker sees when the
// swap token selector opens: a panel that animates in (the "open" window) with a
// ListView bound DIRECTLY to the real Nim `groupsForChainModel` (the
// tokenGroupsForChainModel a swap uses, lazy-loaded, NoMarketDetails), plus a
// looping animation and a 16ms stall monitor so a GUI-thread block during the
// open window shows up as a dropped-frame tick delta.
//
// The Nim driver opens the panel and, mid-window, injects the by-chain completion
// exactly as the token service does on the GUI thread (decode + build groups +
// modelsUpdated), then re-runs it in the typed-handoff regime (build off-window,
// only the model reset on-window). This scene measures what the ListView + render
// loop actually experience in each regime.

import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 480
    height: 900
    visible: true // realize the offscreen surface so the ListView creates delegates

    // Continuous activity so the render/event loop is genuinely busy during the
    // open window (a real modal animates while data lands).
    Rectangle {
        id: spinner
        width: 24; height: 24; radius: 12
        color: "#4360df"
        x: 8
        NumberAnimation on rotation {
            from: 0; to: 360; duration: 800
            loops: Animation.Infinite; running: true
        }
    }

    // The "modal" panel: slides up when opened, matching a sheet/modal enter.
    Rectangle {
        id: pane
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.85
        color: "#101014"
        y: root.paneOpen ? parent.height - height : parent.height
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        ListView {
            id: listView
            anchors.fill: parent
            anchors.margins: 8
            model: groupsForChainModel
            cacheBuffer: 0
            delegate: Rectangle {
                width: ListView.view.width
                height: 48
                color: "transparent"
                // Read the roles the swap token row binds.
                property string _k: model.key
                property string _n: model.name
                property string _s: model.symbol
                property string _l: model.logoUri
                Component.onCompleted: bench.onDelegateCreated()
                Component.onDestruction: bench.onDelegateDestroyed()
            }
        }
    }

    property bool paneOpen: false

    // 16ms stall monitor: each tick reports to the driver, which computes the
    // tick-to-tick delta. A synchronous GUI-thread block starves this timer, so
    // the tick right after the block records the stall.
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: bench.onStallTick()
    }

    Connections {
        target: groupsForChainModel
        function onModelReset() { bench.onModelReset() }
        function onRowsInserted() { bench.onRowsInserted() }
        function onRowsRemoved() { bench.onRowsRemoved() }
        function onDataChanged(topLeft, bottomRight, roles) {
            bench.onDataChanged(topLeft.row, bottomRight.row)
        }
    }

    Connections {
        target: bench
        function onRequestOpen() { root.paneOpen = true }
        function onRequestRelayout() { listView.forceLayout() }
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: bench.onSceneReady()
    }
}
