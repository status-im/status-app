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
            // bgtrace: should be silent while backgrounded (timer is gated on ApplicationActive).
            console.warn("BG_ACTIVITY_QML StatusSharedUpdateTimer state=" + Qt.application.state)
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
