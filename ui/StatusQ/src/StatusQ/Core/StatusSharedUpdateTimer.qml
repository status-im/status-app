pragma ComponentBehavior: Bound

pragma Singleton

import QtQml

QtObject {
    id: root

    readonly property alias secondsActive: d.secondsActive

    signal triggered()

    readonly property Timer d: Timer {
        id: d
        property int secondsActive: 0
        interval: 1000
        running: Qt.application.state === Qt.ApplicationActive
        repeat: true
        onTriggered: {
            d.secondsActive++
            root.triggered()
        }
        onRunningChanged: {
            if (running) {
                d.secondsActive++
                root.triggered()
            }
        }
    }
}
