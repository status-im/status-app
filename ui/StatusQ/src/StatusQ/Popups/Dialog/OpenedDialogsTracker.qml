import QtQml

QtObject {
    id: root

    property var trackedDialog: parent

    property Connections dialogStateConnections: Connections {
        target: root.trackedDialog
        ignoreUnknownSignals: true

        function onVisibleChanged() {
            DialogCounter.syncDialog(root.trackedDialog)
        }

        function onOpenedChanged() {
            DialogCounter.syncDialog(root.trackedDialog)
        }
    }

    Component.onCompleted: {
        DialogCounter.syncDialog(root.trackedDialog)
    }

    Component.onDestruction: {
        DialogCounter.dialogDestroyed(root.trackedDialog)
    }
}
