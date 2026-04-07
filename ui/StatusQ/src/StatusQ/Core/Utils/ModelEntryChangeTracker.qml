pragma ComponentBehavior: Bound

import QtQml

QObject {
    id: root

    property var model
    property string role
    property var key

    readonly property alias revision: d.revision

    signal itemChanged

    onModelChanged: d.initPersistentIndex()
    onRoleChanged: d.initPersistentIndex()
    onKeyChanged: d.initPersistentIndex()

    QtObject {
        id: d

        property var persistentIndex
        property int revision: 0

        function initPersistentIndex() {
            d.persistentIndex = null

            if (!model)
                return

            const idx = ModelUtils.indexOf(root.model, root.role, root.key)

            if (idx === -1)
                return

            d.persistentIndex = ModelUtils.persistentIndex(root.model, idx)
        }

        Component.onCompleted: initPersistentIndex()
    }

    Connections {
        target: root.model ?? null

        function onDataChanged(topLeft: var, bottomRight: var): void {
            if (!d.persistentIndex || !d.persistentIndex.valid)
                return

            const row = d.persistentIndex.row

            if (topLeft.row >= row && bottomRight.row <= row) {
                d.revision++
                root.itemChanged()
            }
        }

        function onRowsInserted() {
            if (d.persistentIndex && d.valid)
                return

            d.initPersistentIndex()
        }

        function onRowsRemoved() {
            if (!!d.persistentIndex && !d.valid)
                d.initPersistentIndex()
        }

        function onLayoutChanged() {
            if (!!d.persistentIndex || !d.valid)
                d.initPersistentIndex()
        }

        function onModelReset() {
            d.initPersistentIndex()
        }
    }
}
