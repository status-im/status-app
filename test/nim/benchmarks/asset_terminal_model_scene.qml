// Terminal-model benchmark scene: binds a ListView DIRECTLY to the
// context-injected AssetsAdaptorModel (no proxies above it) and forwards the
// model's granular signals + delegate churn to the native `bench` object.
//
// The Nim harness drives the updates (setSourceItems / sortBy) — AssetItem is a
// Nim value DTO not exposable to QML — while this scene measures exactly what a
// real ListView sees. Compare against asset_proxy_chain_scene.qml: same
// universe sizes and update classes, proxy chain replaced by the terminal model.

import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 420
    height: 900
    visible: true // realize the offscreen surface so the ListView creates delegates

    ListView {
        id: listView
        anchors.fill: parent
        model: assetsModel
        cacheBuffer: 0
        delegate: Rectangle {
            width: ListView.view.width
            height: 44
            // read the same roles AssetsView's TokenDelegate binds
            property string _k: model.key
            property real _mb: model.marketBalance
            property real _c1d: model.change1DayFiat
            property string _n: model.name
            Component.onCompleted: bench.onDelegateCreated()
            Component.onDestruction: bench.onDelegateDestroyed()
        }

    }

    Connections {
        target: assetsModel
        function onDataChanged(topLeft, bottomRight, roles) {
            bench.onDataChanged(topLeft.row, bottomRight.row)
        }
        function onLayoutChanged() { bench.onLayoutChanged() }
        function onModelReset() { bench.onModelReset() }
        function onRowsInserted() { bench.onRowsInserted() }
        function onRowsRemoved() { bench.onRowsRemoved() }
    }

    // Nim driver asks for a synchronous layout pass so delegate realization is
    // measured within the scenario window.
    Connections {
        target: bench
        function onRequestRelayout() { listView.forceLayout() }
    }

    // Signal the driver once the surface exists and the first frame is rendered.
    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: bench.onSceneReady()
    }
}
