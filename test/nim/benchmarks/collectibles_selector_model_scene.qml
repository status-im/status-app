// GREEN scene: two ListViews bound DIRECTLY to the context-injected
// CollectiblesSelectorModel (no proxies above it) + its filteredFlatModel
// companion, the exact delegates the RED scene (collectibles_selector_scene.qml)
// drives against the real adaptor. The Nim harness owns the update classes
// (setSource / setAccountKey / setEnabledChainIds) because CollectibleItem is a
// Nim value DTO not exposable to QML; this scene measures what a real ListView
// sees.

import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 480
    height: 900
    visible: true // realize the offscreen surface so the ListViews create delegates

    ListView {
        id: groupedView
        width: parent.width / 2
        height: parent.height
        model: collectiblesModel
        cacheBuffer: 0
        delegate: Item {
            width: ListView.view.width
            height: 40
            property string _g: model.groupName
            property string _t: model.type
            property url _i: model.icon
            property int _sc: model.subitems ? model.subitems.count : 0
            Component.onCompleted: bench.onDelegateCreated(0)
            Component.onDestruction: bench.onDelegateDestroyed(0)
        }
    }

    ListView {
        id: flatView
        anchors.left: groupedView.right
        width: parent.width / 2
        height: parent.height
        model: collectiblesModel.filteredFlatModel
        cacheBuffer: 0
        delegate: Item {
            width: ListView.view.width
            height: 40
            property string _k: model.key
            property int _c: model.chainId
            property string _n: model.name
            property int _b: model.balance
            property url _ic: model.iconUrl ?? ""
            Component.onCompleted: bench.onDelegateCreated(1)
            Component.onDestruction: bench.onDelegateDestroyed(1)
        }
    }

    Connections {
        target: collectiblesModel
        function onDataChanged(tl, br, roles) { bench.onDataChanged(0, tl.row, br.row) }
        function onModelReset() { bench.onModelReset(0) }
        function onRowsInserted() { bench.onRowsInserted(0) }
        function onRowsRemoved() { bench.onRowsRemoved(0) }
    }

    Connections {
        target: collectiblesModel.filteredFlatModel
        function onDataChanged(tl, br, roles) { bench.onDataChanged(1, tl.row, br.row) }
        function onModelReset() { bench.onModelReset(1) }
        function onRowsInserted() { bench.onRowsInserted(1) }
        function onRowsRemoved() { bench.onRowsRemoved(1) }
    }

    Connections {
        target: bench
        function onRequestRelayout() {
            groupedView.forceLayout()
            flatView.forceLayout()
            bench.reportCounts(collectiblesModel.filteredFlatModel.rowCount(),
                               collectiblesModel.rowCount())
        }
    }

    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: bench.onStallTick()
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: bench.onSceneReady()
    }
}
