pragma ComponentBehavior: Bound

import QtQml

QtObject {
    property var model

    readonly property alias revision: d.revision
    property alias enabled: d.enabled

    function reset() {
        d.revision = 0
    }

    readonly property Connections _d: Connections {
        id: d

        target: model ?? null

        property int revision: 0

        function onRowsInserted() {
            revision++
        }

        function onRowsMoved() {
            revision++
        }

        function onRowsRemoved() {
            revision++
        }

        function onLayoutChanged() {
            revision++
        }

        function onModelReset() {
            revision++
        }

        function onDataChanged() {
            revision++
        }
    }
}
